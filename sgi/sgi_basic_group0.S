/******************************************************************************
 * File:      sgi_basic_group0.S
 * Purpose:   Basic SGI delivery, Group 0. Self-injected via GICR_ISPENDR0.
 *            EL3: Group 0 -> FIQ. Handler: IAR0/EOIR0.
 ******************************************************************************/
#include "gic_common.h"

.equ SGI_INTID, 0

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_fiq_vector

test_start:
        bl      gic_init_grp0
        ldr     x1,=gic_expected_intid
        mov     x2,#SGI_INTID
        str     x2,[x1]
        mov     x0,#SGI_INTID
        bl      ppi_set_group0
        mov     x0,#SGI_INTID
        mov     x1,#0x80
        bl      ppi_set_prio
        mov     x0,#SGI_INTID
        bl      ppi_enable
        mov     x0,#SGI_INTID
        bl      ppi_set_pend
                bl      tb_notify_ready
        dsb     sy
        isb
        msr     daifclr,#1

wait_loop:
        wfi
        b       wait_loop

curr_el_spx_fiq_vector:
        b       gic_fiq_handler_grp0
