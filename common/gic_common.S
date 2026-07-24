/******************************************************************************
 * File:      gic_common.S
 * Purpose:   Mature GIC-700 common API. Bring-up, per-interrupt config,
 *            ack/EOI, default IRQ/FIQ handler, pass/fail.
 *            New testcases call these and stay ~20 lines.
 * Framework: entry=test_start, IRQ vector=irq_handler, result=x0(0/1)+WFE spin.
 *            Matches the 样板.s convention.
 * Build:     aarch64-none-elf-gcc -c gic_common.S -Icommon
 ******************************************************************************/
#include "gic_common.h"

        .section .text
        .align 4

/******************************************************************************
 * Bring-up
 ******************************************************************************/

/* gic_init_grp1ns(): GICD EnableGrp1NS(+RWP), GICR wake, CPU IF for Group1 */
        .global gic_init_grp1ns
gic_init_grp1ns:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp1NS
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ldr     x0,=GICR_RD_BASE
        ldr     w1,[x0,#GICR_WAKER]
        bic     w1,w1,#GICR_WAKER_ProcessorSleep
        str     w1,[x0,#GICR_WAKER]
2:      ldr     w1,[x0,#GICR_WAKER]
        tbnz    w1,#2,2b
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#1
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN1_EL1,x0
        isb
        ret

/* gic_init_grp0(): GICD EnableGrp0(+RWP), GICR wake, CPU IF for Group0 (FIQ) */
        .global gic_init_grp0
gic_init_grp0:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp0
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ldr     x0,=GICR_RD_BASE
        ldr     w1,[x0,#GICR_WAKER]
        bic     w1,w1,#GICR_WAKER_ProcessorSleep
        str     w1,[x0,#GICR_WAKER]
2:      ldr     w1,[x0,#GICR_WAKER]
        tbnz    w1,#2,2b
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#1
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN0_EL1,x0
        isb
        ret

/******************************************************************************
 * PPI / SGI config  (x0=intid 0..31, GICR SGI_base frame)
 *   bit = 1 << intid
 ******************************************************************************/

        .global ppi_set_group_ns
ppi_set_group_ns:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        ldr     w1,[x5,#GICR_IGROUPR0]
        orr     w1,w1,w4
        str     w1,[x5,#GICR_IGROUPR0]
        ldr     w1,[x5,#GICR_IGRPMODR0]
        bic     w1,w1,w4
        str     w1,[x5,#GICR_IGRPMODR0]
        ret

        .global ppi_set_group0
ppi_set_group0:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        ldr     w1,[x5,#GICR_IGROUPR0]
        bic     w1,w1,w4
        str     w1,[x5,#GICR_IGROUPR0]
        ldr     w1,[x5,#GICR_IGRPMODR0]
        bic     w1,w1,w4
        str     w1,[x5,#GICR_IGRPMODR0]
        ret

        .global ppi_set_prio
ppi_set_prio:
        ldr     x5,=GICR_SGI_BASE
        add     x5,x5,#GICR_IPRIORITYRn
        strb    w1,[x5,x0]
        ret

        .global ppi_set_level
ppi_set_level:
        lsl     w6,w0,#1
        sub     w6,w6,#32
        mov     w7,#3
        lsl     w7,w7,w6
        ldr     x5,=GICR_SGI_BASE
        ldr     w1,[x5,#GICR_ICFGR1]
        bic     w1,w1,w7
        str     w1,[x5,#GICR_ICFGR1]
        ret

        .global ppi_set_edge
ppi_set_edge:
        lsl     w6,w0,#1
        sub     w6,w6,#32
        mov     w7,#3
        lsl     w7,w7,w6
        ldr     x5,=GICR_SGI_BASE
        ldr     w1,[x5,#GICR_ICFGR1]
        bic     w1,w1,w7
        mov     w7,#2
        lsl     w7,w7,w6
        orr     w1,w1,w7
        str     w1,[x5,#GICR_ICFGR1]
        ret

        .global ppi_enable
ppi_enable:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        str     w4,[x5,#GICR_ISENABLER0]
        ret

        .global ppi_set_pend
ppi_set_pend:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        str     w4,[x5,#GICR_ISPENDR0]
        ret

        .global ppi_clr_pend
ppi_clr_pend:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        str     w4,[x5,#GICR_ICPENDR0]
        ret

        .global ppi_config_ns
ppi_config_ns:
        stp     x19,x30,[sp,#-16]!
        mov     x19,x0
        bl      ppi_set_group_ns
        mov     x0,x19
        mov     x1,#0x80
        bl      ppi_set_prio
        mov     x0,x19
        bl      ppi_set_level
        mov     x0,x19
        bl      ppi_enable
        ldp     x19,x30,[sp],#16
        ret

        .global ppi_config_grp0
ppi_config_grp0:
        stp     x19,x30,[sp,#-16]!
        mov     x19,x0
        bl      ppi_set_group0
        mov     x0,x19
        mov     x1,#0x80
        bl      ppi_set_prio
        mov     x0,x19
        bl      ppi_set_level
        mov     x0,x19
        bl      ppi_enable
        ldp     x19,x30,[sp],#16
        ret

/******************************************************************************
 * SPI config  (x0=intid >=32, GICD). bank=intid/32, bit=1<<(intid%32)
 ******************************************************************************/

        .global spi_set_group_ns
spi_set_group_ns:
        mov     w1,#32
        udiv    w2,w0,w1
        msub    w3,w2,w1,w0
        mov     w4,#1
        lsl     w4,w4,w3
        ldr     x5,=GICD_BASE
        mov     x6,#GICD_IGROUPRn
        add     x6,x6,x2,lsl #2
        ldr     w1,[x5,x6]
        orr     w1,w1,w4
        str     w1,[x5,x6]
        mov     x6,#GICD_IGRPMODRn
        add     x6,x6,x2,lsl #2
        ldr     w1,[x5,x6]
        bic     w1,w1,w4
        str     w1,[x5,x6]
        ret

        .global spi_set_group0
spi_set_group0:
        mov     w1,#32
        udiv    w2,w0,w1
        msub    w3,w2,w1,w0
        mov     w4,#1
        lsl     w4,w4,w3
        ldr     x5,=GICD_BASE
        mov     x6,#GICD_IGROUPRn
        add     x6,x6,x2,lsl #2
        ldr     w1,[x5,x6]
        bic     w1,w1,w4
        str     w1,[x5,x6]
        mov     x6,#GICD_IGRPMODRn
        add     x6,x6,x2,lsl #2
        ldr     w1,[x5,x6]
        bic     w1,w1,w4
        str     w1,[x5,x6]
        ret

        .global spi_set_prio
spi_set_prio:
        ldr     x5,=GICD_BASE
        add     x5,x5,#GICD_IPRIORITYRn
        strb    w1,[x5,x0]
        ret

        .global spi_set_level
spi_set_level:
        mov     w1,#16
        udiv    w2,w0,w1
        msub    w3,w2,w1,w0
        lsl     w6,w3,#1
        mov     w7,#3
        lsl     w7,w7,w6
        ldr     x5,=GICD_BASE
        mov     x8,#GICD_ICFGRn
        add     x8,x8,x2,lsl #2
        ldr     w1,[x5,x8]
        bic     w1,w1,w7
        str     w1,[x5,x8]
        ret

        .global spi_set_edge
spi_set_edge:
        mov     w1,#16
        udiv    w2,w0,w1
        msub    w3,w2,w1,w0
        lsl     w6,w3,#1
        mov     w7,#3
        lsl     w7,w7,w6
        ldr     x5,=GICD_BASE
        mov     x8,#GICD_ICFGRn
        add     x8,x8,x2,lsl #2
        ldr     w1,[x5,x8]
        bic     w1,w1,w7
        mov     w7,#2
        lsl     w7,w7,w6
        orr     w1,w1,w7
        str     w1,[x5,x8]
        ret

        .global spi_enable
spi_enable:
        mov     w1,#32
        udiv    w2,w0,w1
        msub    w3,w2,w1,w0
        mov     w4,#1
        lsl     w4,w4,w3
        ldr     x5,=GICD_BASE
        mov     x6,#GICD_ISENABLERn
        add     x6,x6,x2,lsl #2
        str     w4,[x5,x6]
        ret

        .global spi_route_self
spi_route_self:
        mrs     x2,mpidr_el1
        and     x3,x2,#0xffffff
        ubfx    x4,x2,#32,#8
        bfi     x3,x4,#32,#8
        ldr     x5,=GICD_BASE
        mov     x6,#GICD_IROUTERn
        add     x6,x6,x0,lsl #3
        str     x3,[x5,x6]
        ret

        .global spi_set_pend
spi_set_pend:
        mov     w1,#32
        udiv    w2,w0,w1
        msub    w3,w2,w1,w0
        mov     w4,#1
        lsl     w4,w4,w3
        ldr     x5,=GICD_BASE
        mov     x6,#GICD_ISPENDRn
        add     x6,x6,x2,lsl #2
        str     w4,[x5,x6]
        ret

        .global spi_config_ns
spi_config_ns:
        stp     x19,x30,[sp,#-16]!
        mov     x19,x0
        bl      spi_set_group_ns
        mov     x0,x19
        mov     x1,#0x80
        bl      spi_set_prio
        mov     x0,x19
        bl      spi_set_level
        mov     x0,x19
        bl      spi_route_self
        mov     x0,x19
        bl      spi_enable
        ldp     x19,x30,[sp],#16
        ret

        .global spi_config_grp0
spi_config_grp0:
        stp     x19,x30,[sp,#-16]!
        mov     x19,x0
        bl      spi_set_group0
        mov     x0,x19
        mov     x1,#0x80
        bl      spi_set_prio
        mov     x0,x19
        bl      spi_set_level
        mov     x0,x19
        bl      spi_route_self
        mov     x0,x19
        bl      spi_enable
        ldp     x19,x30,[sp],#16
        ret

/******************************************************************************
 * Ack / EOI / Wait
 ******************************************************************************/

        .global gic_ack_grp1
gic_ack_grp1:
        mrs     x0,ICC_IAR1_EL1
        ret

        .global gic_ack_grp0
gic_ack_grp0:
        mrs     x0,ICC_IAR0_EL1
        ret

        .global gic_eoi_grp1
gic_eoi_grp1:
        msr     ICC_EOIR1_EL1,x0
        ret

        .global gic_eoi_grp0
gic_eoi_grp0:
        msr     ICC_EOIR0_EL1,x0
        ret

        .global gic_wait_irq_clear
gic_wait_irq_clear:
1:      mrs     x0,isr_el1
        tbnz    x0,#7,1b
        ret

        .global gic_wait_fiq_clear
gic_wait_fiq_clear:
1:      mrs     x0,isr_el1
        tbnz    x0,#6,1b
        ret

/******************************************************************************
 * Default IRQ/FIQ handler: ack + eoi + check gic_expected_intid + pass/fail
 * Test sets gic_expected_intid before WFI, then: irq_handler: b gic_irq_handler_grp1
 ******************************************************************************/

        .global gic_irq_handler_grp1
gic_irq_handler_grp1:
        mrs     x0,ICC_IAR1_EL1
        msr     ICC_EOIR1_EL1,x0
        ldr     x1,=gic_expected_intid
        ldr     x2,[x1]
        cmp     x0,x2
        b.ne    test_fail
        bl      gic_wait_irq_clear
        b       test_pass

        .global gic_irq_handler_grp0
gic_irq_handler_grp0:
        mrs     x0,ICC_IAR0_EL1
        msr     ICC_EOIR0_EL1,x0
        ldr     x1,=gic_expected_intid
        ldr     x2,[x1]
        cmp     x0,x2
        b.ne    test_fail
        bl      gic_wait_fiq_clear
        b       test_pass

/******************************************************************************
 * Result: x0=0 pass / x0=1 fail, then WFE spin (simulator reads x0)
 ******************************************************************************/

        .global test_pass
test_pass:
        mov     x0,#0
1:      wfe
        b       1b

        .global test_fail
test_fail:
        mov     x0,#1
1:      wfe
        b       1b

/******************************************************************************
 * Data
 ******************************************************************************/

        .section .data
        .align 3
        .global gic_expected_intid
gic_expected_intid:
        .quad 0

/******************************************************************************
 * Group 1 (Secure) variants
 ******************************************************************************/

        .global gic_init_grp1s
gic_init_grp1s:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp1S
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ldr     x0,=GICR_RD_BASE
        ldr     w1,[x0,#GICR_WAKER]
        bic     w1,w1,#GICR_WAKER_ProcessorSleep
        str     w1,[x0,#GICR_WAKER]
2:      ldr     w1,[x0,#GICR_WAKER]
        tbnz    w1,#2,2b
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#1
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN1_EL1,x0
        isb
        ret

        .global ppi_set_group_1s
ppi_set_group_1s:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        ldr     w1,[x5,#GICR_IGROUPR0]
        orr     w1,w1,w4
        str     w1,[x5,#GICR_IGROUPR0]
        ldr     w1,[x5,#GICR_IGRPMODR0]
        orr     w1,w1,w4
        str     w1,[x5,#GICR_IGRPMODR0]
        ret

        .global spi_set_group_1s
spi_set_group_1s:
        mov     w1,#32
        udiv    w2,w0,w1
        msub    w3,w2,w1,w0
        mov     w4,#1
        lsl     w4,w4,w3
        ldr     x5,=GICD_BASE
        mov     x6,#GICD_IGROUPRn
        add     x6,x6,x2,lsl #2
        ldr     w1,[x5,x6]
        orr     w1,w1,w4
        str     w1,[x5,x6]
        mov     x6,#GICD_IGRPMODRn
        add     x6,x6,x2,lsl #2
        ldr     w1,[x5,x6]
        orr     w1,w1,w4
        str     w1,[x5,x6]
        ret

        .global ppi_config_1s
ppi_config_1s:
        stp     x19,x30,[sp,#-16]!
        mov     x19,x0
        bl      ppi_set_group_1s
        mov     x0,x19
        mov     x1,#0x80
        bl      ppi_set_prio
        mov     x0,x19
        bl      ppi_set_level
        mov     x0,x19
        bl      ppi_enable
        ldp     x19,x30,[sp],#16
        ret

        .global spi_config_1s
spi_config_1s:
        stp     x19,x30,[sp,#-16]!
        mov     x19,x0
        bl      spi_set_group_1s
        mov     x0,x19
        mov     x1,#0x80
        bl      spi_set_prio
        mov     x0,x19
        bl      spi_set_level
        mov     x0,x19
        bl      spi_route_self
        mov     x0,x19
        bl      spi_enable
        ldp     x19,x30,[sp],#16
        ret

/******************************************************************************
 * Low-level building blocks (compatibility / custom tests)
 ******************************************************************************/

        .global gic_dist_enable_grp1ns
gic_dist_enable_grp1ns:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp1NS
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ret

        .global gic_dist_enable_grp1s
gic_dist_enable_grp1s:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp1S
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ret

        .global gic_dist_enable_grp0
gic_dist_enable_grp0:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp0
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ret

        .global gicr_wake
gicr_wake:
        ldr     x0,=GICR_RD_BASE
        ldr     w1,[x0,#GICR_WAKER]
        bic     w1,w1,#GICR_WAKER_ProcessorSleep
        str     w1,[x0,#GICR_WAKER]
1:      ldr     w1,[x0,#GICR_WAKER]
        tbnz    w1,#2,1b
        ret

        .global gic_wait_rwp_gicr
gic_wait_rwp_gicr:
        ldr     x0,=GICR_RD_BASE
1:      ldr     w1,[x0,#GICR_CTLR]
        tbnz    w1,#3,1b
        ret

        .global cpu_if_init_grp1
cpu_if_init_grp1:
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#1
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN1_EL1,x0
        isb
        ret

        .global cpu_if_init_grp0
cpu_if_init_grp0:
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#1
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN0_EL1,x0
        isb
        ret

        .global wfi_wait_irq
wfi_wait_irq:
        dsb     sy
        msr     daifclr,#2
1:      wfi
        b       1b

        .global wfi_wait_fiq
wfi_wait_fiq:
        dsb     sy
        msr     daifclr,#1
1:      wfi
        b       1b

        .global report_pass
report_pass:
        ldr     x1,=gic_pass_msg
        bl      end_test
1:      b       1b

        .global report_fail
report_fail:
        ldr     x1,=gic_fail_msg
        bl      end_test
1:      b       1b

        .section .rodata
gic_pass_msg: .asciz "** GIC TEST PASSED OK **\n"
gic_fail_msg: .asciz "** GIC TEST FAILED **\n"
