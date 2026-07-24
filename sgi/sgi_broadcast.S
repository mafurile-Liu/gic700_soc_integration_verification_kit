// SGI broadcast (Non-secure Group 1) - ICC_SGI1R_EL1 with IRM=1 (all participating
// PEs EXCEPT the originator), per IHI0069 p225. Layout: INTID[27:24], IRM[40].
//
// NOTE: broadcast excludes the issuing PE, so on a single-PE run this PE does NOT
// receive the SGI. Reception must be verified on a peer PE (multi-PE): run this
// file on the originator (issues the broadcast) and sgi_basic_group1ns on the
// peers (they receive + ack). For single-PE smoke this reports broadcast issued.
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
    // Issue broadcast: IRM=1 (all except self). INTID[27:24].
    ldr  x0, =((SGI_INTID << SGI1R_INTID_SHIFT) | (1 << SGI1R_IRM_SHIFT))
    msr  ICC_SGI1R_EL1, x0
    dsb  sy
    bl   report_pass
1:  b    1b
    .end
