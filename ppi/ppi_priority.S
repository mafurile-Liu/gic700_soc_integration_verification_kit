// PPI priority + priority-mask check (Non-secure Group 1).
// Sets PPI priority and ICC_PMR; checks delivery. Testbench forces PPI per case.
#include "gic_common.h"
#ifndef PPI_INTID
#define PPI_INTID PPI_CNTV
#endif
#define PPI_BIT (1 << PPI_INTID)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1
    LOAD_GICR(x0)
    add x5, x0, #0x10000
    ldr w1, [x5, #GICR_IGROUPR0]  //  SGI/PPI Group: bit n=1 -> Group1 (IRQ); =0 -> Group0 (FIQ)
    orr w1, w1, #PPI_BIT
    str w1, [x5, #GICR_IGROUPR0]  //  SGI/PPI Group: bit n=1 -> Group1 (IRQ); =0 -> Group0 (FIQ)
    ldr w1, [x5, #GICR_IGRPMODR0]  //  Group modifier (with IGROUPR0): 1,0=NSGrp1 1,1=SecGrp1 0,0=Grp0; RAZ/WI if DS=1
    bic w1, w1, #PPI_BIT
    str w1, [x5, #GICR_IGRPMODR0]  //  Group modifier (with IGROUPR0): 1,0=NSGrp1 1,1=SecGrp1 0,0=Grp0; RAZ/WI if DS=1
    ldr w1, [x5, #GICR_ICFGR1]  //  PPI trigger: 2 bits/INTID, 0b00=level 0b10=edge; INTID n at bits[2*(n-16)+1:2*(n-16)]
    bic w1, w1, #(3<<ICFGR_PPI_SHIFT(PPI_INTID))
    str w1, [x5, #GICR_ICFGR1]  //  PPI trigger: 2 bits/INTID, 0b00=level 0b10=edge; INTID n at bits[2*(n-16)+1:2*(n-16)]
    // priority 0x80, PMR 0xFF -> delivered
    mov w1, #0x80
    strb w1, [x5, #(GICR_IPRIORITYRn+PPI_INTID)]  //  Priority bytes: byte n = priority of INTID n (0x00 highest, 0xFF lowest)
    mov w1, #PPI_BIT
    str w1, [x5, #GICR_ISENABLER0]  //  Set-Enable: bit n=1 enables INTID n (0-31)
    mov x0, #0xFF
    msr ICC_PMR_EL1, x0  //  Priority Mask: only interrupts with prio < PMR are signaled; 0xFF = allow all
    isb  //  Instruction Synchronization Barrier
    // ===== TESTBENCH INJECTION POINT =====
    // The PE is about to enter WFI (next line). Your testbench must now FORCE
    // the PPI input signal (ppi<INTID>) to its ACTIVE level, so the GIC pends
    // the interrupt and wakes this PE.
    //   level-sensitive : hold active, then de-assert AFTER the handler reads
    //                      IAR and BEFORE it writes EOIR (else it re-pends).
    //   edge-triggered  : a single active pulse is enough.
    bl wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
    mrs x3, ICC_IAR1_EL1  //  Ack Group 1: read returns INTID, advances state (pending->active)
    msr ICC_EOIR1_EL1, x3  //  EOI Group 1: priority drop + deactivate (EOImode=0)
    mov w2, #PPI_INTID
    cmp w3, w2
    b.ne ppi_fail
    bl report_pass
ppi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
