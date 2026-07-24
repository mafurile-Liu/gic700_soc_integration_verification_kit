// SGI basic delivery - Group 0 (FIQ).
// SGIs are edge-triggered (GICR_ICFGR0 is RAO/WI). Configures the SGI in this PE
// Redistributor and injects it via GICR_ISPENDR0 (a legal GIC verification
// mechanism that avoids the ICC_SGI1R_EL1 bit layout). Handler acks ICC_IAR0_EL1/ICC_EOIR0_EL1.
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
    bl gic_dist_enable_grp0
    bl gicr_wake
    bl cpu_if_init_grp0
    LOAD_GICR(x0)
    add x5, x0, #0x10000
    ldr w1, [x5, #GICR_IGROUPR0]  //  SGI/PPI Group: bit n=1 -> Group1 (IRQ); =0 -> Group0 (FIQ)
    bic w1, w1, #SGI_BIT
    str w1, [x5, #GICR_IGROUPR0]  //  SGI/PPI Group: bit n=1 -> Group1 (IRQ); =0 -> Group0 (FIQ)
    ldr w1, [x5, #GICR_IGRPMODR0]  //  Group modifier (with IGROUPR0): 1,0=NSGrp1 1,1=SecGrp1 0,0=Grp0; RAZ/WI if DS=1
    bic w1, w1, #SGI_BIT
    str w1, [x5, #GICR_IGRPMODR0]  //  Group modifier (with IGROUPR0): 1,0=NSGrp1 1,1=SecGrp1 0,0=Grp0; RAZ/WI if DS=1
    mov w1, #PRIO_DEFAULT
    strb w1, [x5, #(GICR_IPRIORITYRn+SGI_INTID)]  //  Priority bytes: byte n = priority of INTID n (0x00 highest, 0xFF lowest)
    mov w1, #SGI_BIT
    str w1, [x5, #GICR_ISENABLER0]  //  Set-Enable: bit n=1 enables INTID n (0-31)
    mov w1, #SGI_BIT
    str w1, [x5, #GICR_ISPENDR0]  // inject: set SGI pending
    bl wfi_wait_fiq
    .global curr_el_spx_fiq_vector
curr_el_spx_fiq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
    mrs x3, ICC_IAR0_EL1  //  Ack Group 0 (FIQ): read returns INTID
    msr ICC_EOIR0_EL1, x3  //  EOI Group 0: priority drop + deactivate
    mov w2, #SGI_INTID
    cmp w3, w2
    b.ne sgi_fail
1:  mrs  x21,isr_el1
tbnz x21,#6,1b
    bl report_pass
sgi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
