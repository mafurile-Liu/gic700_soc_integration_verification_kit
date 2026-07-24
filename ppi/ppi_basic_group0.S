// PPI basic delivery - Group 0 (FIQ).
// Flow: configure PPI in this PE Redistributor (SGI_base frame) -> enable CPU
// interface -> WFI. TESTBENCH forces the PPI input signal; GIC pends + wakes PE.
// Handler acks ICC_IAR0_EL1 / ICC_EOIR0_EL1.
// TESTBENCH CONTRACT: after WFI, force ppi<INTID> active. For level: de-assert
// AFTER IAR and BEFORE EOIR (else re-pends). For edge: one active pulse.
// INTID: PPI_CNTV (27) default; override -DPPI_INTID=<n>.
// TRM: 4.10 PPIs, 4.10.2 PPI programming, 5.5 (p207), 3.2.4 GCI PPI signals.
#include "gic_common.h"
#ifndef PPI_INTID
#define PPI_INTID PPI_CNTV
#endif
#define PPI_BIT (1 << PPI_INTID)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl gic_dist_enable_grp0
    bl gicr_wake
    bl cpu_if_init_grp0
    LOAD_GICR(x0)
    add x5, x0, #0x10000  // SGI_base
    ldr w1, [x5, #GICR_IGROUPR0]  //  SGI/PPI Group: bit n=1 -> Group1 (IRQ); =0 -> Group0 (FIQ)
    bic w1, w1, #PPI_BIT
    str w1, [x5, #GICR_IGROUPR0]  //  SGI/PPI Group: bit n=1 -> Group1 (IRQ); =0 -> Group0 (FIQ)
    ldr w1, [x5, #GICR_IGRPMODR0]  //  Group modifier (with IGROUPR0): 1,0=NSGrp1 1,1=SecGrp1 0,0=Grp0; RAZ/WI if DS=1
    bic w1, w1, #PPI_BIT
    str w1, [x5, #GICR_IGRPMODR0]  //  Group modifier (with IGROUPR0): 1,0=NSGrp1 1,1=SecGrp1 0,0=Grp0; RAZ/WI if DS=1
    mov w1, #PRIO_DEFAULT
    strb w1, [x5, #(GICR_IPRIORITYRn + PPI_INTID)]  //  Priority bytes: byte n = priority of INTID n (0x00 highest, 0xFF lowest)
    ldr w1, [x5, #GICR_ICFGR1]  // level (clear bit-pair)
    bic w1, w1, #(3 << ICFGR_PPI_SHIFT(PPI_INTID))
    str w1, [x5, #GICR_ICFGR1]  //  PPI trigger: 2 bits/INTID, 0b00=level 0b10=edge; INTID n at bits[2*(n-16)+1:2*(n-16)]
    mov w1, #PPI_BIT
    str w1, [x5, #GICR_ISENABLER0]  //  Set-Enable: bit n=1 enables INTID n (0-31)
    bl wfi_wait_fiq
    .global curr_el_spx_fiq_vector
curr_el_spx_fiq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
    mrs x3, ICC_IAR0_EL1  // ack
    msr ICC_EOIR0_EL1, x3  // deactivate
    mov w2, #PPI_INTID
    cmp w3, w2
    b.ne ppi_fail
1:  mrs  x21, isr_el1
    tbnz x21, #6, 1b
    mrs x0, mpidr_el1  //  MPIDR: Aff0[7:0] Aff1[15:8] Aff2[23:16] Aff3[39:32]
    ubfx x0, x0, #0, #16
    adr x1, exec_pe_var
    ldr w2, [x1]
    cmp x0, x2
    bne end_wfi
    bl report_pass
ppi_fail:
    bl report_fail
end_wfi:
    b end_wfi
    .balign 8
core_sync1: .word 0
    .end
