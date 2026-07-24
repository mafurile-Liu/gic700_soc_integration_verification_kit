// SGI broadcast (Non-secure Group 1) - ICC_SGI1R_EL1 with IRM=1 (all PEs except
// originator), per IHI0069 p225. NOTE: broadcast excludes issuing PE; verify
// reception on a peer PE (multi-PE). Single-PE: reports broadcast issued.
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
    // Build ICC_SGI1R_EL1: IRM[40]=1, INTID[27:24]
    mov  x1, #SGI_INTID
    lsl  x1, x1, #24              // INTID << 24
    movz x0, #0x100, lsl #32      // 1 << 40 (IRM)
    orr  x0, x0, x1
    msr  ICC_SGI1R_EL1, x0
    dsb  sy
    bl   report_pass
1:  b    1b
    .end
