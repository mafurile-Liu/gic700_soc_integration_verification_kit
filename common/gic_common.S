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

/*----------------------------------------------------------
 * Global symbol declarations (core GIC API)
 *----------------------------------------------------------*/
        .global gic_init_grp1ns
        .global gic_init_grp0
        .global ppi_set_group_ns
        .global ppi_set_group0
        .global ppi_set_prio
        .global ppi_set_level
        .global ppi_set_edge
        .global ppi_enable
        .global ppi_set_pend
        .global ppi_clr_pend
        .global ppi_config_ns
        .global ppi_config_grp0
        .global spi_set_group_ns
        .global spi_set_group0
        .global spi_set_prio
        .global spi_set_level
        .global spi_set_edge
        .global spi_enable
        .global spi_route_self
        .global spi_set_pend
        .global spi_config_ns
        .global spi_config_grp0
        .global gic_ack_grp1
        .global gic_ack_grp0
        .global gic_eoi_grp1
        .global gic_eoi_grp0
        .global gic_wait_irq_clear
        .global gic_wait_fiq_clear
        .global gic_irq_handler_grp1
        .global gic_fiq_handler_grp0
        .global gic_fiq_handler_grp1ns
        .global tb_notify_ready
        .global test_pass
        .global test_fail
        .global gic_expected_intid
        .global gic_init_grp1s
        .global ppi_set_group_1s
        .global spi_set_group_1s
        .global ppi_config_1s
        .global spi_config_1s
        .global gic_dist_enable_grp1ns
        .global gic_dist_enable_grp1s
        .global gic_dist_enable_grp0
        .global gicr_wake
        .global gic_wait_rwp_gicr
        .global cpu_if_init_grp1
        .global cpu_if_init_grp0
        .global wfi_wait_irq
        .global wfi_wait_fiq


/*----------------------------------------------------------
 * Global symbol declarations (all exported functions)
 *----------------------------------------------------------*/

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
        /* ICC_SRE_EL3: enable system register access + disable legacy bypass.
           Bit0=SRE, Bit1=DFB (Disable FIQ Bypass), Bit2=DIB (Disable IRQ Bypass).
           GIC-700 may have these RAO, but set explicitly for portability (ref: TF-A). */
        mrs     x0,ICC_SRE_EL3
        orr     x0,x0,#0x7              /* SRE | DFB | DIB */
        msr     ICC_SRE_EL3,x0
        isb
        /* ICC_SRE_EL1: same bits, enable system register access at EL1 */
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#0x7
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN1_EL1,x0
        dsb     sy
        isb
        ret

/* gic_init_grp0(): GICD EnableGrp0(+RWP), GICR wake, CPU IF for Group0 (FIQ) */
/*----------------------------------------------------------
 * gic_init_grp0(void)
 *   Full bring-up for Group 0 (FIQ). Same as grp1ns but:
 *   GICD_CTLR bit[0]=EnableGrp0; CPU IF ICC_IGRPEN0_EL1 bit[0]=1 (Group 0 signaling).
 *----------------------------------------------------------*/
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
        /* ICC_SRE_EL3: enable system register access + disable legacy bypass.
           Bit0=SRE, Bit1=DFB, Bit2=DIB. Set explicitly (ref: TF-A gicv3_cpuif_enable). */
        mrs     x0,ICC_SRE_EL3
        orr     x0,x0,#0x7              /* SRE | DFB | DIB */
        msr     ICC_SRE_EL3,x0
        isb
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#0x7
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN0_EL1,x0
        dsb     sy
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
ppi_set_prio:
        ldr     x5,=GICR_SGI_BASE
        add     x5,x5,#GICR_IPRIORITYRn
        strb    w1,[x5,x0]
        ret

/*----------------------------------------------------------
 * ppi_set_level(x0=intid)
 *   Level-sensitive trigger. shift=2*(intid-16). GICR_ICFGR1: clear 2-bit field (0b00=level).
 *----------------------------------------------------------*/
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
spi_set_prio:
        ldr     x5,=GICD_BASE
        add     x5,x5,#GICD_IPRIORITYRn
        strb    w1,[x5,x0]
        ret

/*----------------------------------------------------------
 * spi_set_level(x0=intid)
 *   Level. idx=intid/16, shift=2*(intid%16). GICD_ICFGRn+idx*4: clear 2-bit field.
 *----------------------------------------------------------*/
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
gic_ack_grp1:
        mrs     x0,ICC_IAR1_EL1
        ret

/*----------------------------------------------------------
 * gic_ack_grp0(void) -> x0=INTID
 *   Read ICC_IAR0_EL1 (Group 0 / FIQ).
 *----------------------------------------------------------*/
gic_ack_grp0:
        mrs     x0,ICC_IAR0_EL1
        ret

/*----------------------------------------------------------
 * gic_eoi_grp1(x0=intid)
 *   Write ICC_EOIR1_EL1: priority drop + deactivate (EOImode=0).
 *----------------------------------------------------------*/
gic_eoi_grp1:
        msr     ICC_EOIR1_EL1,x0
        ret

/*----------------------------------------------------------
 * gic_eoi_grp0(x0=intid)
 *   Write ICC_EOIR0_EL1 (Group 0).
 *----------------------------------------------------------*/
gic_eoi_grp0:
        msr     ICC_EOIR0_EL1,x0
        ret

/*----------------------------------------------------------
 * gic_wait_irq_clear(void)
 *   Poll ISR_EL1 bit[7] (IRQ) until 0 (IRQ de-asserted). For level interrupts.
 *----------------------------------------------------------*/
gic_wait_irq_clear:
1:      mrs     x0,isr_el1
        tbnz    x0,#7,1b
        ret

/*----------------------------------------------------------
 * gic_wait_fiq_clear(void)
 *   Poll ISR_EL1 bit[6] (FIQ) until 0.
 *----------------------------------------------------------*/
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
 * gic_fiq_handler_grp0(void)
 *   Default FIQ handler for Group 0: ack(IAR0) -> eoi(EOIR0) ->
 *   compare gic_expected_intid -> wait_fiq_clear -> pass/fail.
 *   Group 0 interrupts always signal as FIQ. Test writes:
 *     curr_el_spx_fiq_vector: b gic_fiq_handler_grp0
 *----------------------------------------------------------*/
gic_fiq_handler_grp0:
        ldr     x0,=core_sync1
        bl      core_synchronisation
        mrs     x0,ICC_IAR0_EL1                 /* Group 0: acknowledge via IAR0 */
        msr     ICC_EOIR0_EL1,x0                /* priority drop + deactivate */
        ldr     x1,=gic_expected_intid
        ldr     x2,[x1]
        cmp     x0,x2
        b.ne    test_fail
        bl      gic_wait_fiq_clear              /* poll ISR bit[6] (FIQ) until 0 */
        b       test_pass

/*----------------------------------------------------------
 * gic_fiq_handler_grp1ns(void)
 *   FIQ handler for Non-secure Group 1 at EL3. At EL3 (Secure), NS Group 1
 *   interrupts are signaled as FIQ (they are "foreign" to Secure state).
 *   The handler reads IAR1 (the aliased Group 1 acknowledge register),
 *   not IAR0, because the interrupt is in Group 1. Test writes:
 *     curr_el_spx_fiq_vector: b gic_fiq_handler_grp1ns
 *
 *   Flow: ack(IAR1) -> eoi(EOIR1) -> compare expected ->
 *         wait_fiq_clear (poll FIQ bit) -> pass/fail.
 *----------------------------------------------------------*/
gic_fiq_handler_grp1ns:
        ldr     x0,=core_sync1
        bl      core_synchronisation
        mrs     x0,ICC_IAR1_EL1                 /* NS Group 1: acknowledge via IAR1 (aliased) */
        msr     ICC_EOIR1_EL1,x0                /* priority drop + deactivate */
        ldr     x1,=gic_expected_intid
        ldr     x2,[x1]
        cmp     x0,x2
        b.ne    test_fail
        bl      gic_wait_fiq_clear              /* NS Group 1 signals as FIQ at EL3 */
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
tb_notify_ready:
        ldr     x0,=TB_READY_ADDR
        mov     w1,#1
        str     w1,[x0]
        ret

test_pass:
        ldr     x1,=gic_pass_msg
        bl      end_test
1:      b       1b

/*----------------------------------------------------------
 * test_fail(void)
 *   Write fail message to tube (0x13000000) via end_test, then WFI spin.
 *----------------------------------------------------------*/
test_fail:
        ldr     x1,=gic_fail_msg
        bl      end_test
1:      b       1b

/******************************************************************************
 * Data
 ******************************************************************************/

        .section .data
        .align 3
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
        /* ICC_SRE_EL3: enable system register access + disable legacy bypass.
           Bit0=SRE, Bit1=DFB (Disable FIQ Bypass), Bit2=DIB (Disable IRQ Bypass).
           GIC-700 may have these RAO, but set explicitly for portability (ref: TF-A). */
        mrs     x0,ICC_SRE_EL3
        orr     x0,x0,#0x7              /* SRE | DFB | DIB */
        msr     ICC_SRE_EL3,x0
        isb
        /* ICC_SRE_EL1: same bits, enable system register access at EL1 */
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#0x7
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN1_EL1,x0
        dsb     sy
        isb
        ret

/*----------------------------------------------------------
 * ppi_set_group_1s(x0=intid)
 *   Assign to Secure Group 1. GICR_IGROUPR0: set bit; GICR_IGRPMODR0: set bit (=Sec Grp1).
 *----------------------------------------------------------*/
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
gic_wait_rwp_gicr:
        ldr     x0,=GICR_RD_BASE
1:      ldr     w1,[x0,#GICR_CTLR]
        tbnz    w1,#3,1b
        ret

/*----------------------------------------------------------
 * cpu_if_init_grp1(void) [low-level]
 *   ICC_SRE=1, ICC_PMR=0xFF, ICC_IGRPEN1=1.
 *----------------------------------------------------------*/
cpu_if_init_grp1:
        /* ICC_SRE_EL3: enable system register access + disable legacy bypass.
           Bit0=SRE, Bit1=DFB (Disable FIQ Bypass), Bit2=DIB (Disable IRQ Bypass).
           GIC-700 may have these RAO, but set explicitly for portability (ref: TF-A). */
        mrs     x0,ICC_SRE_EL3
        orr     x0,x0,#0x7              /* SRE | DFB | DIB */
        msr     ICC_SRE_EL3,x0
        isb
        /* ICC_SRE_EL1: same bits, enable system register access at EL1 */
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#0x7
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN1_EL1,x0
        dsb     sy
        isb
        ret

/*----------------------------------------------------------
 * cpu_if_init_grp0(void) [low-level]
 *   ICC_SRE=1, ICC_PMR=0xFF, ICC_IGRPEN0=1.
 *----------------------------------------------------------*/
cpu_if_init_grp0:
        /* ICC_SRE_EL3: enable system register access + disable legacy bypass.
           Bit0=SRE, Bit1=DFB, Bit2=DIB. Set explicitly (ref: TF-A gicv3_cpuif_enable). */
        mrs     x0,ICC_SRE_EL3
        orr     x0,x0,#0x7              /* SRE | DFB | DIB */
        msr     ICC_SRE_EL3,x0
        isb
        mrs     x0,ICC_SRE_EL1
        orr     x0,x0,#0x7
        msr     ICC_SRE_EL1,x0
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        mov     x0,#1
        msr     ICC_IGRPEN0_EL1,x0
        dsb     sy
        isb
        ret

/*----------------------------------------------------------
 * wfi_wait_irq(void) [low-level]
 *   dsb sy; daifclr #2 (unmask IRQ); wfi loop.
 *----------------------------------------------------------*/
wfi_wait_irq:
        dsb     sy
        msr     daifclr,#2
1:      wfi
        b       1b

/*----------------------------------------------------------
 * wfi_wait_fiq(void) [low-level]
 *   dsb sy; daifclr #1 (unmask FIQ); wfi loop.
 *----------------------------------------------------------*/
wfi_wait_fiq:
        dsb     sy
        msr     daifclr,#1
1:      wfi
        b       1b

/*----------------------------------------------------------
 * report_pass(void) [compat]
 *   Legacy: ldr gic_pass_msg; bl end_test. (Prefer test_pass for 样板 framework.)
 *----------------------------------------------------------*/
report_pass:
        ldr     x1,=gic_pass_msg
        bl      end_test
1:      b       1b

/*----------------------------------------------------------
 * report_fail(void) [compat]
 *   Legacy: ldr gic_fail_msg; bl end_test.
 *----------------------------------------------------------*/
report_fail:
        ldr     x1,=gic_fail_msg
        bl      end_test
1:      b       1b


/******************************************************************************
 * Read-only data
 ******************************************************************************/
        .section .rodata
gic_pass_msg: .asciz "** GIC TEST PASSED OK **\n"
gic_fail_msg: .asciz "** GIC TEST FAILED **\n"
