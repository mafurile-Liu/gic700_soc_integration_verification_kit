// SPI basic delivery - Secure Group 1.
// Flow: configure SPI in Distributor (group/priority/trigger/route/enable) -> CPU
// interface -> WFI. TESTBENCH forces the SPI input (SPI Collator); GIC pends +
// wakes PE. Routes to THIS PE (GICD_IROUTER = this PE affinity from MPIDR).
// TESTBENCH CONTRACT: after WFI assert SPI input; level: de-assert after IAR/before EOIR.
// INTID: 32 default; override -DSPI_INTID=<n>. TRM: 4.11 SPIs, 4.11.2, 4.11.3, 5.2.
#include "gic_common.h"
#ifndef SPI_INTID
#define SPI_INTID 32
#endif
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl gic_dist_enable_grp1s
    bl gicr_wake
    bl cpu_if_init_grp1
    LOAD_GICD(x0)
    ldr w1, [x0, #SPI_IGROUPR_OFF(SPI_INTID)]
    orr w1, w1, #SPI_BIT(SPI_INTID)
    str w1, [x0, #SPI_IGROUPR_OFF(SPI_INTID)]
    ldr w1, [x0, #(GICD_IGRPMODRn + SPI_BANK(SPI_INTID)*4)]  //  SPI Group modifier
    orr w1, w1, #SPI_BIT(SPI_INTID)
    str w1, [x0, #(GICD_IGRPMODRn + SPI_BANK(SPI_INTID)*4)]  //  SPI Group modifier
    mov w1, #PRIO_DEFAULT
    strb w1, [x0, #SPI_IPRIORITYR_OFF(SPI_INTID)]
    ldr w1, [x0, #SPI_ICFGR_OFF(SPI_INTID)]
    bic w1, w1, #(3 << SPI_ICFGR_SHIFT(SPI_INTID))  // level
    str w1, [x0, #SPI_ICFGR_OFF(SPI_INTID)]
    // route to this PE: Aff0/Aff1/Aff2 = MPIDR[23:0]; Aff3 = MPIDR[39:32] -> IROUTER[39:32] (bfi); IRM[31]=0 (specific PE)
    mrs x2, mpidr_el1  //  MPIDR: Aff0[7:0] Aff1[15:8] Aff2[23:16] Aff3[39:32]
    and x3, x2, #0xFFFFFF
    ubfx x4, x2, #32, #8
    bfi x3, x4, #32, #8  // Aff3->[39:32]; IRM[31]=0 (specific PE, IHI0069 p580)
    str x3, [x0, #SPI_IROUTER_OFF(SPI_INTID)]
    mov w1, #SPI_BIT(SPI_INTID)
    str w1, [x0, #SPI_ISENABLER_OFF(SPI_INTID)]
    // ===== TESTBENCH INJECTION POINT =====
    // The PE is about to enter WFI (next line). Your testbench must now FORCE
    // the SPI input signal (into the SPI Collator) to its ACTIVE level, so the
    // GIC pends the interrupt and wakes this PE.
    //   level-sensitive : hold active, then de-assert AFTER IAR and BEFORE EOIR.
    //   edge-triggered  : a single active pulse is enough.
    // (No testbench? Alternative: write GICD_SETSPI_NSR with the INTID, or
    //  write GICD_ISPENDRn to set pending directly.)
    bl wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
    mrs x3, ICC_IAR1_EL1  //  Ack Group 1: read returns INTID, advances state (pending->active)
    msr ICC_EOIR1_EL1, x3  //  EOI Group 1: priority drop + deactivate (EOImode=0)
    mov w2, #SPI_INTID
    cmp w3, w2
    b.ne spi_fail
1:  mrs  x21, isr_el1
    tbnz x21, #7, 1b
    mrs x0, mpidr_el1  //  MPIDR: Aff0[7:0] Aff1[15:8] Aff2[23:16] Aff3[39:32]
    ubfx x0, x0, #0, #16
    adr x1, exec_pe_var
    ldr w2, [x1]
    cmp x0, x2
    bne end_wfi
    bl report_pass
spi_fail:
    bl report_fail
end_wfi:
    b end_wfi
    .balign 8
core_sync1: .word 0
    .end
