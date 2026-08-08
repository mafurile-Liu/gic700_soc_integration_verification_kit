/******************************************************************************
 * File:      sgi_broadcast.S
 * Purpose:   SGI broadcast via ICC_SGI1R_EL1 IRM=1 (all PEs except self).
 *            PE0 sends the broadcast, then signals the testbench via
 *            TB_READY_ADDR. The testbench backdoor-reads GICR_ISPENDR0
 *            for PE1..PE23 to verify all received the pending SGI.
 *
 *            NOTE: IRM=1 excludes the sender. PE0 will NOT have the SGI
 *            pending in its own GICR_ISPENDR0. The testbench checks 23 PEs
 *            (PE1 through PE23), not 24.
 *
 *            Layout (IHI0069 p225): INTID[27:24] IRM[40].
 *            IRM=1 -> broadcast to all PEs except originator.
 ******************************************************************************/
#include "gic_common.h"

.equ SGI_INTID, 0

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        /* Configure SGI 0 on PE0 (not strictly needed for sending,
           but ensures GICR is set up in case of unexpected reception) */
        mov     x0,#SGI_INTID
        bl      ppi_set_group_ns
        mov     x0,#SGI_INTID
        mov     x1,#0x80
        bl      ppi_set_prio
        mov     x0,#SGI_INTID
        bl      ppi_enable
        /* Broadcast: IRM[40]=1, INTID[27:24]=SGI_INTID */
        mov     x1,#SGI_INTID
        lsl     x1,x1,#24
        movz    x0,#0x100,lsl #32            /* IRM=1 (bit 40) */
        orr     x0,x0,x1
        msr     ICC_SGI1R_EL1,x0
        dsb     sy
        /* Signal testbench: broadcast sent, ready for GICR_ISPENDR0 check */
        mov     x0,#1   /* edge-triggered */
        bl      tb_notify_ready
        /* Wait for testbench to finish checking (it sets pass/fail) */
wait_loop:
        wfi
        b       wait_loop

/* Handler: PE0 should NOT receive its own broadcast (IRM=1 excludes self).
   If an unexpected interrupt arrives, fail. */
curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
