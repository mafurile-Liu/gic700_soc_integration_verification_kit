// SGI basic delivery - Non-secure Group 1 (IRQ).
// SGIs are edge-triggered (GICR_ICFGR0 is RAO/WI). Configures the SGI in this PE
// Redistributor and injects it via GICR_ISPENDR0 (a legal GIC verification
// mechanism that avoids the ICC_SGI1R_EL1 bit layout). Handler acks ICC_IAR1_EL1/ICC_EOIR1_EL1.
// For true software-generated SGIs, write ICC_SGI1R_EL1 from the originator PE.
// INTID: 0 default; override -DSGI_INTID=<n> (0..15). TRM: 4.9 SGIs, 4.9.1, 5.5.
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
    LOAD_GICR(x0); add x5, x0, #0x10000
    ldr  w1,[x5,#GICR_IGROUPR0]; orr w1,w1,#SGI_BIT; str w1,[x5,#GICR_IGROUPR0]
    ldr  w1,[x5,#GICR_IGRPMODR0]; bic w1,w1,#SGI_BIT; str w1,[x5,#GICR_IGRPMODR0]
    mov  w1,#PRIO_DEFAULT; strb w1,[x5,#(GICR_IPRIORITYRn+SGI_INTID)]
    mov  w1,#SGI_BIT; str w1,[x5,#GICR_ISENABLER0]
    mov  w1,#SGI_BIT; str w1,[x5,#GICR_ISPENDR0]   // inject: set SGI pending
    bl   wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr  x0,=core_sync1; bl core_synchronisation
    mrs  x3, ICC_IAR1_EL1; msr ICC_EOIR1_EL1, x3
    mov  w2,#SGI_INTID; cmp w3,w2; b.ne sgi_fail
1:  mrs  x21,isr_el1; tbnz x21,#7,1b
    bl   report_pass
sgi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
