/******************************************************************************
 * File:      ppi_priority.S
 * Purpose:   PPI priority mask (ICC_PMR) verification.
 *
 *            Tests that ICC_PMR correctly filters interrupts by priority:
 *              1. Configure PPI 27 (CNTV): Secure Group 1, priority 0x80, enable
 *              2. Set ICC_PMR = 0x40 (only allows priority < 0x40 through)
 *                 PPI priority 0x80 >= 0x40, so PPI 27 must be masked
 *              3. Set PPI 27 pending via GICR_ISPENDR0, wait 10000 cycles
 *                 -> interrupt must NOT fire (PMR blocks it)
 *              4. Raise ICC_PMR = 0xFF (allow all)
 *                 -> pending interrupt is now delivered
 *              5. Handler verifies INTID = 27 -> pass
 *
 *            If PMR is broken and the interrupt fires during step 3,
 *            the handler detects phase=0 and fails.
 *
 *            Priority rule (IHI0069): interrupt is forwarded only if
 *            priority < ICC_PMR (numerically lower = higher priority).
 *              0x80 >= 0x40 -> masked (not forwarded)
 *              0x80 <  0xFF -> forwarded
 ******************************************************************************/
#include "gic_common.h"

.equ PPI_INTID, PPI_CNTV             /* INTID 27: Generic Timer virtual count */
.equ PPI_PRIO,  0x80
.equ PMR_BLOCK, 0x40                /* blocks interrupts with priority >= 0x40 */

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s                 /* GICD enable + GICR wake + CPU IF (PMR=0xFF) */

        /* Configure PPI 27: Secure Group 1, prio 0x80, level, enable */
        mov     x0,#PPI_INTID
        bl      ppi_config_1s

        /* Set expected INTID */
        ldr     x1,=gic_expected_intid
        mov     x2,#PPI_INTID
        str     x2,[x1]

        /* Phase 0 = not expecting interrupt (PMR should block).
           If handler sees phase=0, it means PMR failed to mask. */
        ldr     x1,=prio_phase
        str     xzr,[x1]

        /* Set ICC_PMR = 0x40: only forward interrupts with priority < 0x40.
           PPI 27 has priority 0x80 >= 0x40, so it must be blocked. */
        mov     x0,#PMR_BLOCK
        msr     ICC_PMR_EL1,x0
        isb

        /* Unmask IRQ (DAIF.I=0). Interrupts can now be taken,
           but PMR should block PPI 27. */
        msr     daifclr,#2

        /* Force PPI 27 pending via GICR_ISPENDR0 (software injection,
           no testbench signal needed). */
        mov     x0,#PPI_INTID
        bl      ppi_set_pend
        dsb     sy
        isb

        /* Wait loop: if PMR works, no interrupt fires here.
           If PMR is broken, interrupt fires -> handler sees phase=0 -> FAIL. */
        mov     x20,#10000
wait_masked:
        subs    x20,x20,#1
        b.ne    wait_masked

        /* Reached here: interrupt was correctly masked by PMR. Good.
           Now raise ICC_PMR = 0xFF (allow all priorities).
           The pending PPI 27 should now be forwarded and delivered. */
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        isb

        /* Phase 1 = expecting interrupt now.
           Handler will check INTID and pass. */
        ldr     x1,=prio_phase
        mov     x2,#1
        str     x2,[x1]

        /* Wait for interrupt (should fire immediately -- pending + PMR allows) */
wait_loop:
        wfi
        b       wait_loop

/*----------------------------------------------------------
 * Custom handler: uses prio_phase flag to detect PMR failure.
 *   phase=0: interrupt fired during mask period -> PMR broken -> FAIL
 *   phase=1: interrupt fired after PMR raised -> check INTID -> pass/fail
 *----------------------------------------------------------*/
curr_el_spx_irq_vector:
        bl      gic_ack_grp1                    /* x0 = INTID (pending -> active) */
        mov     x9,x0                           /* save INTID */
        bl      gic_eoi_grp1                    /* EOIR1: priority drop + deactivate */
        /* Check phase flag */
        ldr     x1,=prio_phase
        ldr     x2,[x1]
        cbz     x2,test_fail                   /* phase=0: fired during mask = FAIL */
        /* phase=1: verify INTID */
        cmp     x9,#PPI_INTID
        b.ne    test_fail
        bl      gic_wait_irq_clear
        b       test_pass

        .section .data
        .align 3
prio_phase:
        .quad 0
