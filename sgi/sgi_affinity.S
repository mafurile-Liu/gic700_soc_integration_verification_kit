// SGI affinity-targeted - route to a specific PE (concept).
// True targeting: ICC_SGI1R_EL1 IRM=0 with Aff3.Aff2.Aff1.<TargetList> (IHI0069).
// This file validates local SGI delivery via GICR_ISPENDR0; to target a remote PE
// the originator writes ICC_SGI1R_EL1 with that affinity in the target list.
#include "gic_common.h"
#ifndef SGI_INTID
#define SGI_INTID 0
#endif
#define SGI_BIT (1 << SGI_INTID)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl   gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1
    LOAD_GICR(x0)
    add x5, x0, #0x10000
    ldr  w1,[x5,#GICR_IGROUPR0]
    orr w1,w1,#SGI_BIT
    str w1,[x5,#GICR_IGROUPR0]
    ldr  w1,[x5,#GICR_IGRPMODR0]
    bic w1,w1,#SGI_BIT
    str w1,[x5,#GICR_IGRPMODR0]
    mov  w1,#PRIO_DEFAULT
    strb w1,[x5,#(GICR_IPRIORITYRn+SGI_INTID)]
    mov  w1,#SGI_BIT
    str w1,[x5,#GICR_ISENABLER0]
    // TODO(multi-PE): originator ICC_SGI1R_EL1 (IRM=0, target list).
    mov  w1,#SGI_BIT
    str w1,[x5,#GICR_ISPENDR0]
    bl   wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr  x0,=core_sync1
    bl core_synchronisation
    mrs  x3, ICC_IAR1_EL1
    msr ICC_EOIR1_EL1, x3
    mov  w2,#SGI_INTID
    cmp w3,w2
    b.ne sgi_fail
    bl   report_pass
sgi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
