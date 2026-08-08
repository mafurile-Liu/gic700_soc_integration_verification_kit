/******************************************************************************
 * File:      sgi_basic_group1ns.S
 * Purpose:   Basic SGI delivery, NS Group 1. Self-injected via GICR_ISPENDR0.
 *            EL3: NS Group 1 -> FIQ (aliased). Handler: IAR1/EOIR1.
 ******************************************************************************/
#include "gic_common.h"

.equ SGI_INTID, 0

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_fiq_vector

test_start:
        bl      gic_init_grp1ns
        ldr     x1,=gic_expected_intid
        mov     x2,#SGI_INTID
        str     x2,[x1]
        mov     x0,#SGI_INTID
        bl      ppi_set_group_ns
        mov     x0,#SGI_INTID
        mov     x1,#0x80
        bl      ppi_set_prio
        mov     x0,#SGI_INTID
        bl      ppi_enable
        mov     x0,#SGI_INTID
        bl      ppi_set_pend
        dsb     sy
        isb
        msr     daifclr,#1
        mov     x0,#1   /* edge-triggered */
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_fiq_vector:
        b       gic_fiq_handler_grp1ns
