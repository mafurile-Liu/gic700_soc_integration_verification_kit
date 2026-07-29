/******************************************************************************
 * File:      gic_common.S
 * Purpose:   Mature GIC-700 common API. Bring-up, per-interrupt config,
 *            ack/EOI, default IRQ/FIQ handler, pass/fail.
 *            New testcases call these and stay ~20 lines.
 * Framework: EL3 boot (bootcode.s). Entry=test_start.
 *            IRQ vector=curr_el_spx_irq_vector, FIQ vector=curr_el_spx_fiq_vector.
 *            Result=end_test (writes pass/fail message to tube 0x13000000).
 *            Handlers call core_synchronisation (bootcode provides).
 * Build:     aarch64-none-elf-gcc -c gic_common.S -Icommon
 ******************************************************************************/
#include "gic_common.h"

        .section .text
        .align 4

/******************************************************************************
 * Bring-up
 ******************************************************************************/

/* gic_init_grp1ns(): GICD EnableGrp1NS(+RWP), GICR wake, CPU IF for Group1 */
/*----------------------------------------------------------
 * gic_init_grp1ns(void)
 *   Full bring-up for Non-secure Group 1 (IRQ). Three steps:
 *   1) GICD_CTLR bit[1]=EnableGrp1NS, poll bit[31]=RWP until 0.
 *   2) GICR_WAKER bit[1]=ProcessorSleep->0 (wake), poll bit[2]=ChildrenAsleep=0.
 *   3) CPU IF: ICC_SRE_EL1 bit[0]=1, ICC_PMR_EL1=0xFF (allow all), ICC_IGRPEN1_EL1 bit[0]=1.
 *   (ARE fixed=1 in GIC-700.)
 *----------------------------------------------------------*/
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
/*----------------------------------------------------------
 * gic_init_grp0(void)
 *   Full bring-up for Group 0 (FIQ). Same as grp1ns but:
 *   GICD_CTLR bit[0]=EnableGrp0; CPU IF ICC_IGRPEN0_EL1 bit[0]=1 (Group 0 signaling).
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_set_group_ns(x0=intid)
 *   Assign PPI/SGI (intid 0..31) to Non-secure Group 1.
 *   bit = 1<<intid. GICR_IGROUPR0: set bit (=Group1); GICR_IGRPMODR0: clear bit (=NS Grp1).
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_set_group0(x0=intid)
 *   Assign to Group 0 (->FIQ). GICR_IGROUPR0: clear bit; GICR_IGRPMODR0: clear bit.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_set_prio(x0=intid, x1=prio)
 *   Set 8-bit priority byte. GICR_IPRIORITYRn + intid byte = prio (0x00 highest, 0xFF lowest).
 *----------------------------------------------------------*/
        .global ppi_set_prio
ppi_set_prio:
        ldr     x5,=GICR_SGI_BASE
        add     x5,x5,#GICR_IPRIORITYRn
        strb    w1,[x5,x0]
        ret

/*----------------------------------------------------------
 * ppi_set_level(x0=intid)
 *   Level-sensitive trigger. shift=2*(intid-16). GICR_ICFGR1: clear 2-bit field (0b00=level).
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_set_edge(x0=intid)
 *   Edge-triggered. shift=2*(intid-16). GICR_ICFGR1: set 2-bit field to 0b10 (edge).
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_enable(x0=intid)
 *   Enable. bit=1<<intid. GICR_ISENABLER0: set bit.
 *----------------------------------------------------------*/
        .global ppi_enable
ppi_enable:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        str     w4,[x5,#GICR_ISENABLER0]
        ret

/*----------------------------------------------------------
 * ppi_set_pend(x0=intid)
 *   Force pending (verification injection, no peripheral needed). GICR_ISPENDR0: set bit.
 *----------------------------------------------------------*/
        .global ppi_set_pend
ppi_set_pend:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        str     w4,[x5,#GICR_ISPENDR0]
        ret

/*----------------------------------------------------------
 * ppi_clr_pend(x0=intid)
 *   Clear pending. GICR_ICPENDR0: set bit.
 *----------------------------------------------------------*/
        .global ppi_clr_pend
ppi_clr_pend:
        mov     w4,#1
        lsl     w4,w4,w0
        ldr     x5,=GICR_SGI_BASE
        str     w4,[x5,#GICR_ICPENDR0]
        ret

/*----------------------------------------------------------
 * ppi_config_ns(x0=intid)
 *   One-call config: ppi_set_group_ns + prio 0x80 + level + enable. Saves x19/x30.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_config_grp0(x0=intid)
 *   One-call: ppi_set_group0 + prio 0x80 + level + enable.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_set_group_ns(x0=intid >=32)
 *   Assign SPI to NS Group 1. bank=intid/32 (udiv), bit=1<<(intid%32) (msub).
 *   GICD_IGROUPRn+bank*4: set bit; GICD_IGRPMODRn+bank*4: clear bit.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_set_group0(x0=intid)
 *   Group 0. GICD_IGROUPRn: clear bit; GICD_IGRPMODRn: clear bit.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_set_prio(x0=intid, x1=prio)
 *   GICD_IPRIORITYRn + intid byte = prio.
 *----------------------------------------------------------*/
        .global spi_set_prio
spi_set_prio:
        ldr     x5,=GICD_BASE
        add     x5,x5,#GICD_IPRIORITYRn
        strb    w1,[x5,x0]
        ret

/*----------------------------------------------------------
 * spi_set_level(x0=intid)
 *   Level. idx=intid/16, shift=2*(intid%16). GICD_ICFGRn+idx*4: clear 2-bit field.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_set_edge(x0=intid)
 *   Edge. GICD_ICFGRn: set 2-bit field to 0b10.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_enable(x0=intid)
 *   GICD_ISENABLERn+bank*4: set bit.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_route_self(x0=intid)
 *   Route SPI to THIS PE. GICD_IROUTERn+intid*8 = MPIDR affinity (Aff0/1/2[23:0] +
 *   Aff3[39:32] via bfi), IRM[31]=0 (specific PE).
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_set_pend(x0=intid)
 *   Force pending (inject). GICD_ISPENDRn+bank*4: set bit.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_config_ns(x0=intid)
 *   One-call: group NS + prio 0x80 + level + route_self + enable.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_config_grp0(x0=intid)
 *   One-call: group0 + prio 0x80 + level + route_self + enable.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * gic_ack_grp1(void) -> x0=INTID
 *   Read ICC_IAR1_EL1: returns taken INTID, advances state pending->active.
 *----------------------------------------------------------*/
        .global gic_ack_grp1
gic_ack_grp1:
        mrs     x0,ICC_IAR1_EL1
        ret

/*----------------------------------------------------------
 * gic_ack_grp0(void) -> x0=INTID
 *   Read ICC_IAR0_EL1 (Group 0 / FIQ).
 *----------------------------------------------------------*/
        .global gic_ack_grp0
gic_ack_grp0:
        mrs     x0,ICC_IAR0_EL1
        ret

/*----------------------------------------------------------
 * gic_eoi_grp1(x0=intid)
 *   Write ICC_EOIR1_EL1: priority drop + deactivate (EOImode=0).
 *----------------------------------------------------------*/
        .global gic_eoi_grp1
gic_eoi_grp1:
        msr     ICC_EOIR1_EL1,x0
        ret

/*----------------------------------------------------------
 * gic_eoi_grp0(x0=intid)
 *   Write ICC_EOIR0_EL1 (Group 0).
 *----------------------------------------------------------*/
        .global gic_eoi_grp0
gic_eoi_grp0:
        msr     ICC_EOIR0_EL1,x0
        ret

/*----------------------------------------------------------
 * gic_wait_irq_clear(void)
 *   Poll ISR_EL1 bit[7] (IRQ) until 0 (IRQ de-asserted). For level interrupts.
 *----------------------------------------------------------*/
        .global gic_wait_irq_clear
gic_wait_irq_clear:
1:      mrs     x0,isr_el1
        tbnz    x0,#7,1b
        ret

/*----------------------------------------------------------
 * gic_wait_fiq_clear(void)
 *   Poll ISR_EL1 bit[6] (FIQ) until 0.
 *----------------------------------------------------------*/
        .global gic_wait_fiq_clear
gic_wait_fiq_clear:
1:      mrs     x0,isr_el1
        tbnz    x0,#6,1b
        ret

/******************************************************************************
 * Default IRQ/FIQ handler: ack + eoi + check gic_expected_intid + pass/fail
 * Test sets gic_expected_intid before WFI, then: irq_handler: b gic_irq_handler_grp1
 ******************************************************************************/

/*----------------------------------------------------------
 * gic_irq_handler_grp1(void)
 *   Default IRQ handler: ack(IAR1) -> eoi(EOIR1) -> compare to gic_expected_intid
 *   -> if mismatch test_fail; else wait_irq_clear -> test_pass. Test uses:
 *     irq_handler: b gic_irq_handler_grp1
 *----------------------------------------------------------*/
        .global gic_irq_handler_grp1
gic_irq_handler_grp1:
        ldr     x0,=core_sync1
        bl      core_synchronisation
        mrs     x0,ICC_IAR1_EL1
        msr     ICC_EOIR1_EL1,x0
        ldr     x1,=gic_expected_intid
        ldr     x2,[x1]
        cmp     x0,x2
        b.ne    test_fail
        bl      gic_wait_irq_clear
        b       test_pass

/*----------------------------------------------------------
 * gic_irq_handler_grp0(void)
 *   Default FIQ handler: IAR0/EOIR0, compare expected, wait_fiq_clear, pass/fail.
 *----------------------------------------------------------*/
        .global gic_irq_handler_grp0
gic_irq_handler_grp0:
        ldr     x0,=core_sync1
        bl      core_synchronisation
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

/*----------------------------------------------------------
 * test_pass(void)
 *   Write pass message to tube (0x13000000) via end_test, then WFI spin.
 *----------------------------------------------------------*/

/*----------------------------------------------------------
 * tb_notify_ready(void)
 *   Write 1 to TB_READY_ADDR to signal the testbench that the PE is about
 *   to enter WFI and is ready for interrupt injection.
 *----------------------------------------------------------*/
        .global tb_notify_ready
tb_notify_ready:
        ldr     x0,=TB_READY_ADDR
        mov     w1,#1
        str     w1,[x0]
        ret

        .global test_pass
test_pass:
        ldr     x1,=gic_pass_msg
        bl      end_test
1:      b       1b

/*----------------------------------------------------------
 * test_fail(void)
 *   Write fail message to tube (0x13000000) via end_test, then WFI spin.
 *----------------------------------------------------------*/
        .global test_fail
test_fail:
        ldr     x1,=gic_fail_msg
        bl      end_test
1:      b       1b

/******************************************************************************
 * Data
 ******************************************************************************/

        .section .data
        .align 3
        .global gic_expected_intid
core_sync1:
        .quad 0

gic_expected_intid:
        .quad 0

/******************************************************************************
 * Group 1 (Secure) variants
 ******************************************************************************/

/*----------------------------------------------------------
 * gic_init_grp1s(void)
 *   Full bring-up for Secure Group 1. GICD_CTLR bit[2]=EnableGrp1S; CPU IF
 *   ICC_IGRPEN1_EL1. Must run at a Secure EL.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_set_group_1s(x0=intid)
 *   Assign to Secure Group 1. GICR_IGROUPR0: set bit; GICR_IGRPMODR0: set bit (=Sec Grp1).
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_set_group_1s(x0=intid)
 *   Secure Group 1. GICD_IGROUPRn: set bit; GICD_IGRPMODRn: set bit.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * ppi_config_1s(x0=intid)
 *   One-call: ppi_set_group_1s + prio 0x80 + level + enable.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * spi_config_1s(x0=intid)
 *   One-call: group 1s + prio 0x80 + level + route_self + enable.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * gic_dist_enable_grp1ns(void) [low-level]
 *   GICD_CTLR bit[1]=EnableGrp1NS + poll RWP. (gic_init_grp1ns includes this.)
 *----------------------------------------------------------*/
        .global gic_dist_enable_grp1ns
gic_dist_enable_grp1ns:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp1NS
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ret

/*----------------------------------------------------------
 * gic_dist_enable_grp1s(void) [low-level]
 *   GICD_CTLR bit[2]=EnableGrp1S + poll RWP.
 *----------------------------------------------------------*/
        .global gic_dist_enable_grp1s
gic_dist_enable_grp1s:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp1S
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ret

/*----------------------------------------------------------
 * gic_dist_enable_grp0(void) [low-level]
 *   GICD_CTLR bit[0]=EnableGrp0 + poll RWP.
 *----------------------------------------------------------*/
        .global gic_dist_enable_grp0
gic_dist_enable_grp0:
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp0
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        ret

/*----------------------------------------------------------
 * gicr_wake(void) [low-level]
 *   GICR_WAKER ProcessorSleep=0, poll ChildrenAsleep=0.
 *----------------------------------------------------------*/
        .global gicr_wake
gicr_wake:
        ldr     x0,=GICR_RD_BASE
        ldr     w1,[x0,#GICR_WAKER]
        bic     w1,w1,#GICR_WAKER_ProcessorSleep
        str     w1,[x0,#GICR_WAKER]
1:      ldr     w1,[x0,#GICR_WAKER]
        tbnz    w1,#2,1b
        ret

/*----------------------------------------------------------
 * gic_wait_rwp_gicr(void) [low-level]
 *   Poll GICR_CTLR bit[3]=RWP until 0 (Redistributor write complete).
 *----------------------------------------------------------*/
        .global gic_wait_rwp_gicr
gic_wait_rwp_gicr:
        ldr     x0,=GICR_RD_BASE
1:      ldr     w1,[x0,#GICR_CTLR]
        tbnz    w1,#3,1b
        ret

/*----------------------------------------------------------
 * cpu_if_init_grp1(void) [low-level]
 *   ICC_SRE=1, ICC_PMR=0xFF, ICC_IGRPEN1=1.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * cpu_if_init_grp0(void) [low-level]
 *   ICC_SRE=1, ICC_PMR=0xFF, ICC_IGRPEN0=1.
 *----------------------------------------------------------*/
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

/*----------------------------------------------------------
 * wfi_wait_irq(void) [low-level]
 *   dsb sy; daifclr #2 (unmask IRQ); wfi loop.
 *----------------------------------------------------------*/
        .global wfi_wait_irq
wfi_wait_irq:
        dsb     sy
        msr     daifclr,#2
1:      wfi
        b       1b

/*----------------------------------------------------------
 * wfi_wait_fiq(void) [low-level]
 *   dsb sy; daifclr #1 (unmask FIQ); wfi loop.
 *----------------------------------------------------------*/
        .global wfi_wait_fiq
wfi_wait_fiq:
        dsb     sy
        msr     daifclr,#1
1:      wfi
        b       1b

/*----------------------------------------------------------
 * report_pass(void) [compat]
 *   Legacy: ldr gic_pass_msg; bl end_test. (Prefer test_pass for 样板 framework.)
 *----------------------------------------------------------*/
        .global report_pass
report_pass:
        ldr     x1,=gic_pass_msg
        bl      end_test
1:      b       1b

/*----------------------------------------------------------
 * report_fail(void) [compat]
 *   Legacy: ldr gic_fail_msg; bl end_test.
 *----------------------------------------------------------*/
        .global report_fail
report_fail:
        ldr     x1,=gic_fail_msg
        bl      end_test
1:      b       1b


/******************************************************************************
 * ITS (Interrupt Translation Service) API
 *   Based on Arm AArch64_GIC_v3_v4_example gicv3_lpis.c.
 *   Each ITS command is 32 bytes (4 doublewords). The its_cmd_buf buffer
 *   in .data is filled by each its_xxx function, then its_add_command
 *   copies it to the command queue and polls for completion.
 *   IHI0069 ch5 (command encoding), TRM ch4 (GIC-700 specifics).
 ******************************************************************************/

/*----------------------------------------------------------
 * its_init(void)
 *   Initialize the ITS for LPI delivery. Steps:
 *   1) GITS_CBASER = command queue base | size(4 pages-1=3) | Valid(bit63)
 *      - The command queue is a circular buffer of 32-byte entries.
 *      - GITS_CBASER.PA[47:12] = queue physical address (4K-aligned).
 *      - GITS_CBASER.Size[7:0] = num_pages - 1.
 *   2) GITS_CWRITER = 0 (write pointer at start of queue).
 *   3) GITS_BASER0 = Device Table base | 16 pages | Valid.
 *      - BASER encoding: PA[47:12] | PageSize[9:8]=0(4K) | Size[7:0]=pages-1
 *        | Valid(bit63) | Cache(0=Device-nGnRnE) | Share(0) | Direct(bit62=0)
 *   4) GITS_BASER1 = Collection Table base | 16 pages | Valid (same encoding).
 *   5) GITS_CTLR bit[0] = 1 (Enable). Poll bit[31]=Quiescent until 0.
 *----------------------------------------------------------*/
        .global its_init
its_init:
        ldr     x9,=GITS_BASE
        /* GITS_CBASER: ITS_CMDQ_ADDR | (4-1)=3 pages | Valid(bit63) */
        ldr     x0,=ITS_CMDQ_ADDR
        and     x0,x0,#0x0000FFFFFFFFF000     /* PA bits [47:12], 4K-aligned */
        mov     x1,#3                          /* Size = num_pages - 1 = 3 (4 pages) */
        orr     x0,x0,x1
        mov     x1,#1
        lsl     x1,x1,#63                      /* Valid bit (bit 63) */
        orr     x0,x0,x1
        str     x0,[x9,#GITS_CBASER]
        /* GITS_CWRITER = 0 (start of queue) */
        str     xzr,[x9,#GITS_CWRITER]
        /* GITS_BASER0: Device Table (16 pages) */
        ldr     x0,=ITS_DEV_TABLE_ADDR
        and     x0,x0,#0x0000FFFFFFFFF000
        mov     x1,#15                          /* 16 pages - 1 */
        orr     x0,x0,x1
        mov     x1,#1
        lsl     x1,x1,#63                       /* Valid */
        orr     x0,x0,x1
        str     x0,[x9,#GITS_BASER0]
        /* GITS_BASER1: Collection Table (16 pages) */
        ldr     x0,=ITS_COL_TABLE_ADDR
        and     x0,x0,#0x0000FFFFFFFFF000
        mov     x1,#15
        orr     x0,x0,x1
        mov     x1,#1
        lsl     x1,x1,#63
        orr     x0,x0,x1
        str     x0,[x9,#GITS_BASER1]
        /* Enable ITS: GITS_CTLR bit[0] = 1 */
        mov     w0,#GITS_CTLR_Enabled
        str     w0,[x9,#GITS_CTLR]
        /* Poll GITS_CTLR bit[31]=Quiescent until 0 (ITS enabled and running) */
1:      ldr     w0,[x9,#GITS_CTLR]
        tbnz    w0,#31,1b
        ret

/*----------------------------------------------------------
 * its_add_command(void) [internal]
 *   Copy 32 bytes from its_cmd_buf to the command queue entry at
 *   (queue_base + GITS_CWRITER), advance CWRITER by 32 (with wraparound),
 *   then poll GITS_CREADR == GITS_CWRITER until the ITS consumes the command.
 *
 *   Register usage (x9 = its_cmd_buf ptr, set by caller):
 *     x10 = GITS_BASE, x11 = CBASER, x12 = queue_base, x13 = queue_size
 *     x14 = write offset, x15 = entry addr, x16/x17 = copy temporaries
 *----------------------------------------------------------*/
        .global its_add_command
its_add_command:
        ldr     x10,=GITS_BASE
        ldr     x11,[x10,#GITS_CBASER]          /* CBASER: PA + Size + attrs */
        and     x12,x11,#0x0000FFFFFFFFF000     /* queue_base = PA[47:12] */
        and     x13,x11,#0xFF                   /* num_pages - 1 */
        add     x13,x13,#1
        lsl     x13,x13,#12                     /* queue_size = num_pages * 4096 */
        ldr     x14,[x10,#GITS_CWRITER]         /* current write offset */
        /* entry address = queue_base + write_offset */
        add     x15,x12,x14
        /* copy 32 bytes (4 doublewords) from its_cmd_buf to queue entry */
        ldp     x16,x17,[x9]
        stp     x16,x17,[x15]
        ldp     x16,x17,[x9,#16]
        stp     x16,x17,[x15,#16]
        dsb     sy
        /* advance write offset by 32, wrap if end of queue */
        add     x14,x14,#32
        cmp     x14,x13
        b.ne    1f
        mov     x14,#0                          /* wraparound to start */
1:
        str     x14,[x10,#GITS_CWRITER]
        /* poll until CREADR == CWRITER (command consumed by ITS) */
2:
        ldr     x15,[x10,#GITS_CREADR]
        cmp     x15,x14
        b.ne    2b
        ret

/*----------------------------------------------------------
 * its_mapd(x0=device_id, x1=itt_addr, x2=id_bits)
 *   MAPD command (opcode 0x08): map a DeviceID to an ITT (Interrupt
 *   Translation Table). id_bits is the EventID width; the command
 *   encodes (id_bits - 1) in byte[16].
 *
 *   DW0 = opcode(0x08) | (device_id << 32)   [byte 0=opcode, bytes 4-7=DeviceID]
 *   DW1 = itt_addr (64-bit)                   [bytes 8-15=ITT address]
 *   DW2 = (id_bits-1) | Valid(bit63)           [byte 16=size, byte 23=Valid]
 *   DW3 = 0
 *----------------------------------------------------------*/
        .global its_mapd
its_mapd:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]                    /* zero DW0-DW1 */
        stp     xzr,xzr,[x9,#16]                /* zero DW2-DW3 */
        /* DW0: opcode + device_id */
        mov     w3,#ITS_CMD_MAPD
        str     w3,[x9]                         /* byte 0 = opcode */
        str     w0,[x9,#4]                      /* bytes 4-7 = device_id */
        /* DW1: ITT address (bytes 8-15) */
        str     x1,[x9,#8]
        /* DW2: size (id_bits-1) in byte 16, Valid in byte 23 (bit 63 of DW2) */
        sub     w2,w2,#1
        strb    w2,[x9,#16]
        mov     w3,#0x80
        strb    w3,[x9,#23]
        b       its_add_command

/*----------------------------------------------------------
 * its_mapc(x0=target_rd_procnum, x1=collection_id)
 *   MAPC command (opcode 0x09): map a Collection ID to a target
 *   Redistributor. When PTA=0 (our GIC-700), target is the RD's
 *   Processor_Number (from GICR_TYPER[23:8]).
 *
 *   DW0 = 0x09
 *   DW1 = 0
 *   DW2 = collection_id[15:0] | (target << 16) | Valid(bit63)
 *         bytes 16-17 = ICID, bytes 18-21 = RDBase(Processor_Number)
 *   DW3 = 0
 *----------------------------------------------------------*/
        .global its_mapc
its_mapc:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w3,#ITS_CMD_MAPC
        str     w3,[x9]                         /* byte 0 = opcode */
        strh    w1,[x9,#16]                     /* bytes 16-17 = collection_id */
        str     w0,[x9,#18]                     /* bytes 18-21 = target (ProcNum) */
        mov     w3,#0x80
        strb    w3,[x9,#23]                     /* byte 23 = Valid */
        b       its_add_command

/*----------------------------------------------------------
 * its_mapti(x0=device_id, x1=event_id, x2=intid, x3=collection_id)
 *   MAPTI command (opcode 0x0A): map a DeviceID/EventID pair to a
 *   specific physical INTID (pINTID) and a Collection.
 *
 *   DW0 = 0x0A | (device_id << 32)
 *   DW1 = event_id[31:0] | (intid << 32)    bytes 8-11=EventID, 12-15=pINTID
 *   DW2 = collection_id[15:0]                bytes 16-17=ICID
 *   DW3 = 0
 *----------------------------------------------------------*/
        .global its_mapti
its_mapti:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w4,#ITS_CMD_MAPTI
        str     w4,[x9]                         /* byte 0 = opcode */
        str     w0,[x9,#4]                      /* bytes 4-7 = device_id */
        str     w1,[x9,#8]                      /* bytes 8-11 = event_id */
        str     w2,[x9,#12]                     /* bytes 12-15 = intid */
        strh    w3,[x9,#16]                     /* bytes 16-17 = collection_id */
        b       its_add_command

/*----------------------------------------------------------
 * its_mapi(x0=device_id, x1=event_id, x2=collection_id)
 *   MAPI command (opcode 0x0B): map a DeviceID/EventID pair to a
 *   Collection. The pINTID is implicitly set to the EventID value
 *   (no separate ITT entry with custom INTID needed).
 *
 *   DW0 = 0x0B | (device_id << 32)
 *   DW1 = event_id[31:0]
 *   DW2 = collection_id[15:0]
 *   DW3 = 0
 *----------------------------------------------------------*/
        .global its_mapi
its_mapi:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w3,#ITS_CMD_MAPI
        str     w3,[x9]
        str     w0,[x9,#4]                      /* device_id */
        str     w1,[x9,#8]                      /* event_id */
        strh    w2,[x9,#16]                     /* collection_id */
        b       its_add_command

/*----------------------------------------------------------
 * its_int(x0=device_id, x1=event_id)
 *   INT command (opcode 0x03): software-trigger an LPI by writing an
 *   INT command to the ITS queue. This is the command-queue alternative
 *   to writing EventID to GITS_TRANSLATER.
 *
 *   DW0 = 0x03 | (device_id << 32)
 *   DW1 = event_id[31:0]
 *   DW2 = 0
 *   DW3 = 0
 *----------------------------------------------------------*/
        .global its_int
its_int:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w2,#ITS_CMD_INT
        str     w2,[x9]
        str     w0,[x9,#4]                      /* device_id */
        str     w1,[x9,#8]                      /* event_id */
        b       its_add_command

/*----------------------------------------------------------
 * its_inv(x0=device_id, x1=event_id)
 *   INV command (opcode 0x0C): invalidate the cached LPI configuration
 *   for the specified DeviceID/EventID. Must be issued after changing
 *   the LPI Configuration Table entry, so the ITS picks up the new
 *   enable/priority value.
 *----------------------------------------------------------*/
        .global its_inv
its_inv:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w2,#ITS_CMD_INV
        str     w2,[x9]
        str     w0,[x9,#4]                      /* device_id */
        str     w1,[x9,#8]                      /* event_id */
        b       its_add_command

/*----------------------------------------------------------
 * its_invall(x0=collection_id)
 *   INVALL command (opcode 0x0D): invalidate all cached LPI
 *   configurations for every INTID mapped to the specified Collection.
 *----------------------------------------------------------*/
        .global its_invall
its_invall:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w1,#ITS_CMD_INVALL
        str     w1,[x9]
        strh    w0,[x9,#16]                     /* collection_id */
        b       its_add_command

/*----------------------------------------------------------
 * its_sync(x0=target_rd_procnum)
 *   SYNC command (opcode 0x05): ensure all outstanding ITS operations
 *   targeting the specified Redistributor have completed. When PTA=0,
 *   the target is the Processor_Number, placed in DW2[47:16].
 *
 *   DW2 = target << 16   (Processor_Number in bits [31:16] of DW2)
 *----------------------------------------------------------*/
        .global its_sync
its_sync:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w1,#ITS_CMD_SYNC
        str     w1,[x9]
        lsl     w0,w0,#16                       /* shift ProcNum to DW2[31:16] */
        str     w0,[x9,#16]                     /* bytes 16-19 = target<<16 */
        b       its_add_command

/******************************************************************************
 * LPI (Locality-specific Peripheral Interrupt) setup API
 ******************************************************************************/

/*----------------------------------------------------------
 * lpi_set_tables(x0=prop_addr, x1=pend_addr, x2=id_bits)
 *   Write GICR_PROPBASER and GICR_PENDBASER for the current PE's
 *   Redistributor (RD0). id_bits must be >= 14 (LPI starts at INTID 8192).
 *
 *   GICR_PROPBASER encoding:
 *     PA[47:12] = config table base (4K-aligned)
 *     IDbits[4:0] = id_bits - 1 (number of ID bits, minus 1)
 *     Cache attrs = 0 (Device-nGnRnE), Shareability = 0 (Non-shared)
 *   GICR_PENDBASER encoding:
 *     PA[47:16] = pending table base (64K-aligned)
 *     Cache attrs = 0, Shareability = 0
 *----------------------------------------------------------*/
        .global lpi_set_tables
lpi_set_tables:
        ldr     x3,=GICR_RD_BASE
        /* GICR_PROPBASER: addr[47:12] | (id_bits-1)[4:0] */
        and     x0,x0,#0x0000FFFFFFFFF000       /* mask PA to [47:12] */
        sub     w2,w2,#1                        /* id_bits - 1 */
        and     w2,w2,#0x1F                     /* 5-bit field */
        orr     x0,x0,x2
        str     x0,[x3,#GICR_PROPBASER]
        /* GICR_PENDBASER: addr[47:16] */
        and     x1,x1,#0x0000FFFFFFFF0000       /* mask PA to [47:16] */
        str     x1,[x3,#GICR_PENDBASER]
        ret

/*----------------------------------------------------------
 * lpi_enable(void)
 *   Set GICR_CTLR bit[0]=EnableLPIs, then poll GICR_CTLR bit[3]=RWP
 *   until 0 (Redistributor has processed the enable).
 *----------------------------------------------------------*/
        .global lpi_enable
lpi_enable:
        ldr     x0,=GICR_RD_BASE
        ldr     w1,[x0,#GICR_CTLR]
        orr     w1,w1,#GICR_CTLR_EnableLPIs     /* bit[0] = 1 */
        str     w1,[x0,#GICR_CTLR]
1:      ldr     w1,[x0,#GICR_CTLR]
        tbnz    w1,#3,1b                        /* poll RWP (bit 3) until 0 */
        ret

/*----------------------------------------------------------
 * lpi_config(x0=intid, x1=enable, x2=priority)
 *   Write a 1-byte entry in the LPI Configuration Table (in memory).
 *   The table starts at INTID 8192; entry offset = intid - 8192.
 *   Byte format: bit[0] = Enable, bits[7:2] = Priority.
 *     priority must be a multiple of 4 (0x00 highest, 0xFC lowest).
 *     byte = (priority & 0xFC) | (enable & 1)
 *----------------------------------------------------------*/
        .global lpi_config
lpi_config:
        and     w2,w2,#0xFC                     /* priority bits [7:2] */
        and     w1,w1,#1                        /* enable bit [0] */
        orr     w1,w1,w2                        /* combine */
        ldr     x3,=LPI_PROP_TABLE_ADDR         /* table base in memory */
        sub     x0,x0,#8192                     /* offset = intid - 8192 */
        strb    w1,[x3,x0]                      /* write config byte */
        dsb     sy
        ret

/*----------------------------------------------------------
 * lpi_trigger(x0=event_id)
 *   Write EventID to GITS_TRANSLATER to trigger an LPI (hardware-style
 *   injection, as if a peripheral wrote the register). The ITS looks up
 *   the DeviceID/EventID mapping and delivers the corresponding LPI.
 *   GITS_TRANSLATER is at ITS_BASE + 0x10000 + 0x0040 = ITS_BASE + 0x10040.
 *----------------------------------------------------------*/
        .global lpi_trigger
lpi_trigger:
        ldr     x1,=GITS_BASE
        movz    x2,#0x40
        movk    x2,#0x1,lsl #16                /* x2 = 0x10040 (GITS_TRANSLATER) */
        str     w0,[x1,x2]
        dsb     sy
        ret

/******************************************************************************
 * Redistributor affinity matching (for multi-PE tests)
 ******************************************************************************/

/*----------------------------------------------------------
 * gicr_find_rd(void) -> x0 = RD_base address for current PE
 *   Scan GICR_TYPER across Redistributor frames to find the one whose
 *   Affinity field ([63:32]) matches this PE's MPIDR.
 *
 *   MPIDR layout: [7:0]=Aff0, [15:8]=Aff1, [23:16]=Aff2, [39:32]=Aff3.
 *   GICR_TYPER[63:32] = Affinity = Aff3.Aff2.Aff1.Aff0 (same packing).
 *
 *   RD frames start at GICR_RD_BASE, stride = 0x40000 (256KB for GICv4.1:
 *   4 frames x 64KB = LPI + SGI + vLPI + Reserved).
 *   GICR_TYPER bit[4] = Last (1 = last RD in this redistributor tuple).
 *
 *   Returns 0xFFFFFFFF if no match found (error).
 *----------------------------------------------------------*/
        .global gicr_find_rd
gicr_find_rd:
        /* Build affinity value from MPIDR: Aff3<<24 | Aff2<<16 | Aff1<<8 | Aff0 */
        mrs     x0,mpidr_el1
        and     x1,x0,#0xFFFFFF                 /* Aff0 + Aff1 + Aff2 (24 bits) */
        ubfx    x2,x0,#32,#8                    /* Aff3 (bits [39:32]) */
        bfi     x1,x2,#24,#8                    /* insert Aff3 at [31:24] */
        /* x1 = 32-bit affinity value to match */
        ldr     x3,=GICR_RD_BASE                /* start scanning from RD0 */
1:
        ldr     x5,[x3,#GICR_TYPER]             /* read 64-bit GICR_TYPER */
        lsr     x6,x5,#32                       /* extract Affinity [63:32] */
        cmp     x6,x1                           /* compare with this PE */
        b.eq    2f                              /* match found */
        tbnz    x5,#4,3f                        /* Last bit set? stop scanning */
        add     x3,x3,#GICR_STRIDE              /* next RD frame (0x40000) */
        b       1b
2:
        mov     x0,x3                           /* return RD_base address */
        ret
3:
        mov     x0,#0xFFFFFFFF                  /* not found */
        ret

/*----------------------------------------------------------
 * gicr_get_procnum(void) -> x0 = Processor_Number
 *   Read GICR_TYPER[23:8] of the current PE's Redistributor (RD0).
 *   The Processor_Number is used as the target in ITS MAPC/SYNC commands
 *   when GITS_TYPER.PTA = 0 (Physical Target Address mode disabled,
 *   which is the case for our GIC-700).
 *----------------------------------------------------------*/
        .global gicr_get_procnum
gicr_get_procnum:
        ldr     x0,=GICR_RD_BASE
        ldr     x1,[x0,#GICR_TYPER]             /* 64-bit GICR_TYPER */
        ubfx    x0,x1,#8,#16                    /* Processor_Number = [23:8] */
        ret

/******************************************************************************
 * LPI-specific FIQ handler
 *   LPIs are always Non-secure Group 1. At EL3 (Secure), NS Group 1
 *   interrupts are signaled as FIQ. Reading ICC_IAR0_EL1 returns 1020
 *   (or 1021 on some implementations) to indicate "Group 1 interrupt
 *   pending." The handler then reads ICC_IAR1_EL1 for the actual LPI
 *   INTID and writes ICC_EOIR1_EL1 to complete it.
 *   Reference: Arm AArch64_GIC_v3_v4_example main_lpi.c fiqHandler().
 ******************************************************************************/

/*----------------------------------------------------------
 * gic_fiq_handler_lpi(void)
 *   1) Read IAR0. If 1020 or 1021 -> Group 1 pending: read IAR1 for
 *      actual LPI INTID, EOI1.
 *      If 1023 -> spurious: test_fail.
 *      Otherwise -> direct Group 0: EOI0.
 *   2) Compare actual INTID to gic_expected_intid.
 *   3) Match -> wait_fiq_clear -> test_pass. Mismatch -> test_fail.
 *----------------------------------------------------------*/
        .global gic_fiq_handler_lpi
gic_fiq_handler_lpi:
        ldr     x0,=core_sync1
        bl      core_synchronisation
        mrs     x0,ICC_IAR0_EL1                 /* read Group 0 IAR */
        cmp     x0,#INTID_GRP1_SIGNAL           /* 1020: Group 1 pending */
        b.eq    1f
        cmp     x0,#INTID_GRP0_SIGNAL           /* 1021: also Group 1 pending (some impls) */
        b.eq    1f
        cmp     x0,#INTID_SPURIOUS              /* 1023: spurious */
        b.eq    test_fail
        /* Direct Group 0 interrupt (rare for LPI, but handle it) */
        msr     ICC_EOIR0_EL1,x0
        b       2f
1:
        /* Group 1 pending: read actual LPI INTID from IAR1 */
        mrs     x0,ICC_IAR1_EL1
        msr     ICC_EOIR1_EL1,x0
2:
        ldr     x1,=gic_expected_intid
        ldr     x2,[x1]
        cmp     x0,x2
        b.ne    test_fail
        bl      gic_wait_fiq_clear
        b       test_pass

/******************************************************************************
 * vLPI / vSGI API (GICv4.1)
 *   Based on Arm AArch64_GIC_v3_v4_example gicv4_virt.c.
 *   These functions use the same ITS command queue mechanism (its_add_command)
 *   and the vLPI Redistributor frame (RD_base + 0x20000).
 ******************************************************************************/

/*----------------------------------------------------------
 * vlpi_set_vpe_table(x0=vpe_conf_addr, x1=num_pages)
 *   Write GICR_VPROPBASER (in the vLPI frame at RD_base + 0x20000).
 *   This register points to the vPE Configuration Table, which holds
 *   the vLPI enable/priority entries (same 1-byte format as physical LPIs).
 *
 *   Encoding: PA[47:12] | (num_pages-1)[6:0] | Valid(bit63) | alloc(bit52)
 *----------------------------------------------------------*/
        .global vlpi_set_vpe_table
vlpi_set_vpe_table:
        ldr     x2,=GICR_VLPI_BASE
        and     x0,x0,#0x0000FFFFFFFFF000       /* PA[47:12] */
        sub     w1,w1,#1                        /* num_pages - 1 */
        and     w1,w1,#0x7F                     /* 7-bit field */
        orr     x0,x0,x1
        mov     x1,#1
        lsl     x1,x1,#63                       /* Valid bit (bit 63) */
        orr     x0,x0,x1
        str     x0,[x2,#GICR_VPROPBASER]
        ret

/*----------------------------------------------------------
 * vlpi_make_resident(x0=vpeid)
 *   Write GICR_VPENDBASER to make the specified vPE resident on this
 *   Redistributor. The vPE must be resident before vLPIs or vSGIs
 *   can be delivered.
 *
 *   Encoding: Valid(bit63) | vPEID[15:0]
 *----------------------------------------------------------*/
        .global vlpi_make_resident
vlpi_make_resident:
        ldr     x1,=GICR_VLPI_BASE
        and     x0,x0,#0xFFFF                   /* vPEID (16-bit) */
        mov     x2,#1
        lsl     x2,x2,#63                       /* Valid bit (bit 63) */
        orr     x0,x0,x2
        str     x0,[x1,#GICR_VPENDBASER]
        dsb     sy
        ret

/*----------------------------------------------------------
 * vlpi_config(x0=intid, x1=enable, x2=priority)
 *   Write a 1-byte vLPI Configuration Table entry (same format as
 *   physical LPI): byte = (priority & 0xFC) | (enable & 1).
 *   Table base = VLPE_CONF_TABLE_ADDR.
 *----------------------------------------------------------*/
        .global vlpi_config
vlpi_config:
        and     w2,w2,#0xFC
        and     w1,w1,#1
        orr     w1,w1,w2
        ldr     x3,=VLPE_CONF_TABLE_ADDR
        sub     x0,x0,#8192
        strb    w1,[x3,x0]
        dsb     sy
        ret

/*----------------------------------------------------------
 * its_vmapp(x0=vpeid, x1=target_rd_procnum, x2=conf_addr, x3=pend_addr)
 *   VMAPP command (opcode 0x41): map a vPEID to a target Redistributor
 *   and specify the vPE Configuration and Pending table addresses.
 *
 *   DW0 = 0x41
 *   DW1 = doorbell[31:0] (bytes 8-11) | vpeid[15:0] (bytes 12-13)
 *         doorbell=0 (no doorbell), vpeid from x0
 *   DW2 = target<<16 (bytes 18-21) | V bit (byte 23 bit 7)
 *   DW3 = size (byte 24) | pend_addr>>16 (bytes 26-30)
 *         conf_addr goes into DW1 via the ITT... actually conf_addr and
 *         pend_addr are placed in the command per the VMAPP encoding.
 *----------------------------------------------------------*/
        .global its_vmapp
its_vmapp:
        /* x0=vpeid, x1=target_rd_procnum, x2=conf_addr (NOT in command:
           set via GICR_VPROPBASER separately), x3=pend_addr */
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]                    /* zero DW0-DW1 (doorbell=0) */
        stp     xzr,xzr,[x9,#16]                /* zero DW2-DW3 */
        mov     w4,#ITS_CMD_VMAPP
        str     w4,[x9]                         /* byte 0 = opcode (0x41) */
        /* bytes 8-11 = doorbell INTID = 0 (no default doorbell) -- already zeroed */
        strh    w0,[x9,#12]                     /* bytes 12-13 = vpeid */
        str     w1,[x9,#18]                     /* bytes 18-21 = target (ProcNum, PTA=0) */
        mov     w4,#0x80
        strb    w4,[x9,#23]                     /* byte 23 bit 7 = V (valid) */
        mov     w4,#14
        strb    w4,[x9,#24]                     /* byte 24 = VPE_size (ID bits - 1) */
        /* bytes 26-30 = pend_addr >> 16 (vPE Pending Table PA) */
        lsr     x4,x3,#16                       /* pend_addr >> 16 */
        str     w4,[x9,#26]                     /* bytes 26-29 (covers PA[47:16]) */
        strb    wzr,[x9,#30]                    /* byte 30 = PA[55:48] = 0 for our addrs */
        b       its_add_command

/*----------------------------------------------------------
 * its_vmapti(x0=device_id, x1=event_id, x2=vpeid, x3=vintid)
 *   VMAPTI command (opcode 0x2A): map a DeviceID/EventID pair to a
 *   vPEID and vINTID (virtual interrupt). Doorbell is set to 1023
 *   (no individual doorbell; use default doorbell from VMAPP).
 *
 *   DW0 = 0x2A | (device_id << 32)
 *   DW1 = event_id (bytes 8-11) | vpeid (bytes 12-13)
 *   DW2 = vintid (bytes 16-19) | doorbell (bytes 20-23)
 *   DW3 = 0
 *----------------------------------------------------------*/
        .global its_vmapti
its_vmapti:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w4,#ITS_CMD_VMAPTI
        str     w4,[x9]
        str     w0,[x9,#4]                      /* device_id (bytes 4-7) */
        str     w1,[x9,#8]                      /* event_id (bytes 8-11) */
        strh    w2,[x9,#12]                     /* vpeid (bytes 12-13) */
        str     w3,[x9,#16]                     /* vintid (bytes 16-19) */
        mov     w4,#1023
        str     w4,[x9,#20]                     /* doorbell=1023 (bytes 20-23) */
        b       its_add_command

/*----------------------------------------------------------
 * its_vsync(x0=vpeid)
 *   VSYNC command (opcode 0x25): synchronize virtual interrupt
 *   operations for the specified vPEID.
 *----------------------------------------------------------*/
        .global its_vsync
its_vsync:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w1,#ITS_CMD_VSYNC
        str     w1,[x9]
        strh    w0,[x9,#12]                     /* vpeid (bytes 12-13) */
        b       its_add_command

/*----------------------------------------------------------
 * its_invdb(x0=vpeid)
 *   INVDB command (opcode 0x2E): invalidate the vPE configuration
 *   cache for the specified vPEID. Must be issued after VMAPP before
 *   the vPE mapping takes effect.
 *----------------------------------------------------------*/
        .global its_invdb
its_invdb:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w1,#ITS_CMD_INVDB
        str     w1,[x9]
        strh    w0,[x9,#12]                     /* vpeid (bytes 12-13) */
        b       its_add_command

/*----------------------------------------------------------
 * its_vsgi(x0=vpeid, x1=vintid, x2=enable, x3=priority, x4=group)
 *   VSGI command (opcode 0x23): configure a virtual SGI's enable,
 *   priority, and group, then inject it.
 *
 *   DW0 = 0x23
 *   byte 1 = enable | (group << 2)   (or 0x02 if clearing pending)
 *   byte 2 = priority & 0xF0         (priority in bits [7:4])
 *   byte 4 = vintid
 *   bytes 12-13 = vpeid
 *----------------------------------------------------------*/
        .global its_vsgi
its_vsgi:
        ldr     x9,=its_cmd_buf
        stp     xzr,xzr,[x9]
        stp     xzr,xzr,[x9,#16]
        mov     w5,#ITS_CMD_VSGI
        str     w5,[x9]                         /* byte 0 = opcode */
        /* byte 1: enable | (group << 2) */
        and     w5,w2,#1                        /* enable bit */
        and     w6,w4,#1                        /* group bit */
        lsl     w6,w6,#2
        orr     w5,w5,w6
        strb    w5,[x9,#1]
        /* byte 2: priority & 0xF0 */
        and     w5,w3,#0xF0
        strb    w5,[x9,#2]
        /* byte 4: vintid */
        strb    w1,[x9,#4]
        /* bytes 12-13: vpeid */
        strh    w0,[x9,#12]
        b       its_add_command

/*----------------------------------------------------------
 * vsgi_send(x0=vintid, x1=vpeid)
 *   Write to GITS_SGIR to inject a virtual SGI. The register is at
 *   ITS_BASE + 0x20000 + 0x0020 = ITS_BASE + 0x20020 (vSGI frame).
 *   Format: bits[31:0] = vINTID, bits[47:32] = vPEID.
 *----------------------------------------------------------*/
        .global vsgi_send
vsgi_send:
        ldr     x2,=GITS_BASE
        /* Combine: (vpeid << 32) | vintid */
        lsl     x1,x1,#32
        orr     x0,x0,x1
        movz    x3,#0x20
        movk    x3,#0x2,lsl #16                /* x3 = 0x20020 (GITS_SGIR) */
        str     x0,[x2,x3]
        dsb     sy
        ret

/******************************************************************************
 * ITS command buffer (32 bytes, filled by each its_xxx function)
 ******************************************************************************/
        .section .data
        .align 4
        .global its_cmd_buf
its_cmd_buf:
        .space 32, 0

        .section .rodata
gic_pass_msg: .asciz "** GIC TEST PASSED OK **\n"
gic_fail_msg: .asciz "** GIC TEST FAILED **\n"
