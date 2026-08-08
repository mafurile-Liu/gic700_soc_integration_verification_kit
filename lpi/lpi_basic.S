/******************************************************************************
 * File:      lpi_basic.S
 * Purpose:   LPI delivery via ITS. Full flow:
 *              1) GIC init (NS Group 1 + Group 0 for IAR0)
 *              2) LPI tables (GICR_PROPBASER / GICR_PENDBASER) + EnableLPIs
 *              3) ITS init (CBASER, BASER0, BASER1, CTLR enable)
 *              4) ITS commands: MAPD -> MAPC -> MAPTI -> SYNC
 *              5) Configure LPI 8192 (enable + priority in config table)
 *              6) INV (flush ITS cache so new config is visible)
 *              7) Trigger LPI via its_int (command-queue software trigger)
 *              8) WFI -> FIQ handler reads IAR0 (1020/1021) -> IAR1 (8192)
 *
 *            Reference: Arm AArch64_GIC_v3_v4_example main_lpi.c.
 *            Spec: IHI0069 ch5 (ITS commands), TRM ch4 (GIC-700).
 *
 * Note:      LPIs are always Non-secure Group 1. At EL3 (Secure), they
 *            are signaled as FIQ. The handler reads IAR0 which returns
 *            1020 (special INTID meaning "Group 1 pending"), then reads
 *            IAR1 for the actual LPI INTID.
 *
 * Memory:    LPI/ITS tables are in DRAM at 0x80010000-0x80070000.
 *            Override with -D if your SoC maps RAM elsewhere.
 ******************************************************************************/
#include "gic_common.h"

.equ LPI_INTID,  8192          /* first LPI INTID */
.equ DEV_ID,     0             /* DeviceID for this test */
.equ EVT_ID,     0             /* EventID the peripheral would write */
.equ COL_ID,     0             /* Collection ID */
.equ ID_BITS,    2             /* EventID width: 2 bits = 4 events */

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_fiq_vector

test_start:
        /* ---- 1) GIC bring-up: NS Group 1 (LPI) + Group 0 (for IAR0) ---- */
        bl      gic_init_grp1ns                /* GICD EnableGrp1NS, GICR wake, CPU IF IGRPEN1 */
        /* Also enable Group 0 on CPU IF so IAR0 returns 1020 (not 1023) */
        mov     x0,#1
        msr     ICC_IGRPEN0_EL1,x0
        /* Also enable GICD EnableGrp0 */
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp0
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b                      /* poll RWP */
        isb

        /* ---- 2) LPI tables: GICR_PROPBASER + GICR_PENDBASER + EnableLPIs ---- */
        ldr     x0,=LPI_PROP_TABLE_ADDR       /* config table (1 byte/LPI) */
        ldr     x1,=LPI_PEND_TABLE_ADDR        /* pending table (1 bit/LPI) */
        mov     x2,#15                          /* id_bits = 15 (supports up to 32768 LPIs) */
        bl      lpi_set_tables
        bl      lpi_enable                      /* GICR_CTLR bit[0]=EnableLPIs, poll RWP */

        /* ---- 3) ITS init: command queue + device/collection tables ---- */
        bl      its_init

        /* ---- 4) ITS commands: MAPD -> MAPC -> MAPTI -> SYNC ---- */
        bl      gicr_get_procnum               /* x0 = Processor_Number (PTA=0) */
        mov     x4,x0                           /* save procnum for MAPC/SYNC */
        /* MAPD: map DeviceID 0 to ITT table, 2-bit EventID width */
        mov     x0,#DEV_ID
        ldr     x1,=ITS_ITT_ADDR
        mov     x2,#ID_BITS
        bl      its_mapd
        /* MAPC: map Collection 0 to this PE's Redistributor */
        mov     x0,x4                           /* target = procnum */
        mov     x1,#COL_ID
        bl      its_mapc
        /* MAPTI: map DeviceID 0 / EventID 0 -> INTID 8192 / Collection 0 */
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        mov     x2,#LPI_INTID
        mov     x3,#COL_ID
        bl      its_mapti
        /* SYNC: ensure mapping is visible on this RD */
        mov     x0,x4
        bl      its_sync

        /* ---- 5) Configure LPI 8192: enable, priority 0 (highest) ---- */
        /* Config table byte = (priority & 0xFC) | enable = 0x00 | 0x01 = 0x01 */
        mov     x0,#LPI_INTID
        mov     x1,#1                           /* enable */
        mov     x2,#0                           /* priority 0 (highest) */
        bl      lpi_config

        /* ---- 6) INV: invalidate ITS cache so new config is visible ---- */
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        bl      its_inv

        /* ---- 7) Set expected INTID and prepare for WFI ---- */
        ldr     x1,=gic_expected_intid
        mov     x2,#LPI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#3                      /* unmask IRQ + FIQ */
        mov     x0,#1   /* edge-triggered */
        bl      tb_notify_ready                /* signal testbench: PE is ready */

        /* ---- 8) Trigger LPI via ITS INT command (software trigger) ---- */
        /* Alternative: bl lpi_trigger with x0=EVT_ID (writes GITS_TRANSLATER) */
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        bl      its_int

        /* ---- 9) Wait for FIQ (LPI arrives as FIQ at EL3) ---- */
wait_loop:
        wfi
        b       wait_loop

/*----------------------------------------------------------
 * FIQ vector: LPIs (NS Group 1) arrive as FIQ at EL3.
 * Handler reads IAR0 -> 1020/1021 -> IAR1 for actual INTID.
 *----------------------------------------------------------*/
curr_el_spx_fiq_vector:
        b       gic_fiq_handler_lpi
