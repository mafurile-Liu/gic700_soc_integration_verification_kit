// SGI affinity-targeted (Non-secure Group 1) - generate a REAL SGI to THIS PE
// via ICC_SGI1R_EL1 (IRM=0, TargetList = this PE), per IHI0069 p225.
// Layout: Aff3[55:48] Aff2[39:32] INTID[27:24] Aff1[23:16] TargetList[15:0].
// INTID: 0 default; override -DSGI_INTID=<n> (0..15). TRM: 4.9 SGIs, 5.5.
#include "gic_common.h"
#ifndef SGI_INTID
#define SGI_INTID 0
#endif
#define SGI_BIT (1 << SGI_INTID)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl   gic_dist_enable_grp1ns
    bl   gicr_wake
    bl   cpu_if_init_grp1
    LOAD_GICR(x0)
    add  x5, x0, #0x10000
    ldr  w1, [x5, #GICR_IGROUPR0]
    orr  w1, w1, #SGI_BIT
    str  w1, [x5, #GICR_IGROUPR0]
    ldr  w1, [x5, #GICR_IGRPMODR0]
    bic  w1, w1, #SGI_BIT
    str  w1, [x5, #GICR_IGRPMODR0]
    mov  w1, #PRIO_DEFAULT
    strb w1, [x5, #(GICR_IPRIORITYRn + SGI_INTID)]
    mov  w1, #SGI_BIT
    str  w1, [x5, #GICR_ISENABLER0]
    // Build ICC_SGI1R_EL1 (IRM=0, target this PE):
    //   Aff3[55:48] Aff2[39:32] INTID[27:24] Aff1[23:16] TargetList[15:0]
    mrs  x2, mpidr_el1
    ubfx x3, x2, #8, #8            // Aff1
    ubfx x4, x2, #16, #8           // Aff2
    ubfx x5, x2, #32, #8           // Aff3 (x5 reused)
    and  x6, x2, #0xFF             // Aff0
    mov  x7, #1
    lsl  x6, x7, x6               // TargetList = 1 << Aff0
    mov  x1, #SGI_INTID
    lsl  x0, x1, #24              // INTID[27:24]
    bfi  x0, x3, #16, #8          // Aff1 -> [23:16]
    bfi  x0, x4, #32, #8          // Aff2 -> [39:32]
    bfi  x0, x5, #48, #8          // Aff3 -> [55:48]
    orr  x0, x0, x6               // TargetList[15:0]
    msr  ICC_SGI1R_EL1, x0
    bl   wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr  x0, =core_sync1
    bl   core_synchronisation
    mrs  x3, ICC_IAR1_EL1
    msr  ICC_EOIR1_EL1, x3
    mov  w2, #SGI_INTID
    cmp  w3, w2
    b.ne sgi_fail
1:  mrs  x21, isr_el1
    tbnz x21, #7, 1b
    bl   report_pass
sgi_fail:
    bl   report_fail
1:  b    1b
    .balign 8
core_sync1: .word 0
    .end
