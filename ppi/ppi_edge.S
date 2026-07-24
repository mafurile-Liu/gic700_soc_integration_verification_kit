// PPI edge-triggered (Non-secure Group 1). ICFGR=edge (0b10). Testbench pulses
// one active edge; pending cleared on activation.
#include "gic_common.h"
#ifndef PPI_INTID
#define PPI_INTID PPI_CNTV
#endif
#define PPI_BIT (1 << PPI_INTID)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl   gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1
    LOAD_GICR(x0)
    add x5, x0, #0x10000
    ldr  w1,[x5,#GICR_IGROUPR0]
    orr w1,w1,#PPI_BIT
    str w1,[x5,#GICR_IGROUPR0]
    ldr  w1,[x5,#GICR_IGRPMODR0]
    bic w1,w1,#PPI_BIT
    str w1,[x5,#GICR_IGRPMODR0]
    ldr  w1,[x5,#GICR_ICFGR1]
    bic  w1,w1,#(3<<ICFGR_PPI_SHIFT(PPI_INTID))
    orr  w1,w1,#(ICFGR_EDGE<<ICFGR_PPI_SHIFT(PPI_INTID))
    str  w1,[x5,#GICR_ICFGR1]
    mov  w1,#PRIO_DEFAULT
    strb w1,[x5,#(GICR_IPRIORITYRn+PPI_INTID)]
    mov  w1,#PPI_BIT
    str w1,[x5,#GICR_ISENABLER0]
    bl   wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr  x0,=core_sync1
    bl core_synchronisation
    mrs  x3, ICC_IAR1_EL1
    msr ICC_EOIR1_EL1, x3
    mov  w2,#PPI_INTID
    cmp w3,w2
    b.ne ppi_fail
1:  mrs  x21,isr_el1
tbnz x21,#7,1b
    bl   report_pass
ppi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
