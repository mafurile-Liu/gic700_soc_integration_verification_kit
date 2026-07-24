// LPI basic delivery (Non-secure Group 1) via ITS.
//
// Full flow per GIC-700_LPI_寄存器配置流程.md + TRM 4.12/4.13:
//   GICD enable -> GICR wake + LPI tables + EnableLPIs ->
//   ITS init (BASER0=Device, BASER1=Collection, CBASER=cmdq, CTLR enable) ->
//   ITS commands MAPD/MAPC/MAPI/INV/SYNC -> write GITS_TRANSLATER -> LPI ->
//   handler ack ICC_IAR1 / ICC_EOIR1.
//
// LPIs: message interrupts (INTID >= 8192), always NS Group 1, no active state,
// config in memory tables (Property=1 byte/LPI; Pending=1 bit/LPI).
//
// MEMORY (TODO): assign real, zeroed DDR regions for: LPI Property table, LPI
// Pending table, ITS Device table, Collection table, ITT, command queue (>=4KB).
//
// ITS COMMAND ENCODING (32 bytes/entry): field layout is in GIC Architecture Spec
// IHI0069 ch5. Opcodes below are standard GICv3 values - VERIFY the byte packing
// against IHI0069 before running. Command order/semantics per the LPI flow doc.
#include "gic_common.h"

#define ITS_CMD_MAPD  0x08
#define ITS_CMD_MAPC  0x09
#define ITS_CMD_MAPI  0x0b
#define ITS_CMD_INV   0x0e
#define ITS_CMD_SYNC  0x05

// TODO: real memory addresses (must be zeroed before use)
#define LPI_PROP_BASE  0x00000000
#define LPI_PEND_BASE  0x00000000
#define ITS_DEV_BASE   0x00000000
#define ITS_COL_BASE   0x00000000
#define ITS_ITT_BASE   0x00000000
#define ITS_CMDQ_BASE  0x00000000
#define LPI_IDBITS     0          // TODO: e.g. 15
#define LPI_INTID      (INTID_FIRST_LPI + 0)
#define DEV_ID         0
#define EVT_ID         0
#define COL_ID         0
#define RD_PROCNUM     0          // TODO: this PE ProcessorNumber (GICR_TYPER)

    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl   gic_dist_enable_grp1ns
    bl   gicr_wake
    bl   cpu_if_init_grp1

    // ---- GICR: LPI Property/Pending tables + EnableLPIs (TRM 4.13.1) ----
    LOAD_GICR(x0)
    // GICR_PROPBASER = (IDbits<<56) | (PROP_BASE & ~0xFFF) | Shareability+Cache
    ldr  x1, =LPI_PROP_BASE
    ldr  x2, =(LPI_IDBITS)
    bfi  x1, x2, #56, #8           // IDbits[63:56]
    // (attributes left 0 = Non-shareable/Device; tune to WB per TRM 4.14)
    str  x1, [x0, #GICR_PROPBASER]
    // GICR_PENDBASER = (PEND_BASE & ~0xFFFF) | Valid=1
    ldr  x1, =LPI_PEND_BASE
    orr  x1, x1, #1                // Valid
    str  x1, [x0, #GICR_PENDBASER]
    // EnableLPIs
    ldr  w1, [x0, #GICR_CTLR]
    orr  w1, w1, #GICR_CTLR_EnableLPIs
    str  w1, [x0, #GICR_CTLR]
    bl   gic_wait_rwp_gicr

    // ---- ITS init (TRM 4.12) ----
    LOAD_GITS(x9)                  // x9 = ITS base for the whole test
    // GITS_BASER0 (Device): Type=1, EntrySize, PA, PageSize. (simplified)
    ldr  x1, =ITS_DEV_BASE
    // TODO: set Type[58:56]=1, EntrySize[52:48], PA[47:12], PageSize per TRM
    str  x1, [x9, #GITS_BASER0]
    // GITS_BASER1 (Collection): Type=4
    ldr  x1, =ITS_COL_BASE
    str  x1, [x9, #GITS_BASER1]
    // GITS_CBASER: cmdq base + size
    ldr  x1, =ITS_CMDQ_BASE
    str  x1, [x9, #GITS_CBASER]
    // CWRITER = 0
    str  xzr, [x9, #GITS_CWRITER]
    // GITS_CTLR.Enabled = 1; poll Quiescent==0
    mov  w1, #GITS_CTLR_Enabled
    str  w1, [x9, #GITS_CTLR]
1:  ldr  w1, [x9, #GITS_CTLR]
    tbnz w1, #31, 1b

    // ---- ITS commands: MAPD, MAPC, MAPI, INV, SYNC ----
    // Each command is 32 bytes written to CMDQ[CWRITER*32]. After writing, advance
    // CWRITER and poll CREADR until it catches up. Command field layout: VERIFY
    // vs IHI0069 ch5 (opcode in DW0; fields DeviceID/EventID/ITT_base/INTID/ICID/
    // RDbase). The helper below writes 4x64-bit and kicks the queue.
    // ITS command = 32 bytes = 4 x 64-bit DWs, written to CMDQ[CWRITER*32], then
    // advance CWRITER and poll CREADR. Per-command args (IHI0069 ch5 pseudocode):
    //   MAPD  (DeviceID, ITT_addr, Size, V)        opcode 0x08
    //   MAPC  (ICID, RDbase, V)                    opcode 0x09
    //   MAPI  (DeviceID, EventID, ICID, INTID)     opcode 0x0b
    //   INV   (DeviceID, EventID)                  opcode 0x0c  (INVALL: ICID)
    //   SYNC  (RDbase)                             opcode 0x05
    // Opcodes are GICv3 standard (per Linux its driver); the per-DW field packing
    // (which DW holds DeviceID/EventID/ITT_addr/INTID/ICID/RDbase/Size/V) is in the
    // IHI0069 ch5 command-format figures - VERIFY byte positions against those
    // figures before running. Command ORDER: MAPD -> MAPC -> MAPI -> INV -> SYNC.
    bl   its_issue_commands       // TODO: encode the 5 commands per IHI0069 ch5

    // ---- Trigger LPI: write EventID to GITS_TRANSLATER ----
    mov  x0, #EVT_ID
    mov  x10, #GITS_TRANSLATER   // 0xC040 too large for imm offset
    str  x0, [x9, x10]             // GITS_TRANSLATER (EventID -> LPI)

    bl   wfi_wait_irq

    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr  x0, =core_sync1
    bl   core_synchronisation
    mrs  x3, ICC_IAR1_EL1         // ack; x3 = LPI INTID
    msr  ICC_EOIR1_EL1, x3        // LPI has no active state -> priority drop only
    mov  x2, #LPI_INTID
    cmp  x3, x2
    b.ne lpi_fail
    bl   report_pass
lpi_fail:
    bl   report_fail
1:  b    1b

// TODO: encode MAPD/MAPC/MAPI/INV/SYNC into CMDQ and advance CWRITER, poll CREADR.
its_issue_commands:
    ret

    .balign 8
core_sync1: .word 0
    .end
