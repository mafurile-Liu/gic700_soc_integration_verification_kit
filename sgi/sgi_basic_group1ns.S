/******************************************************************************
 * File:      sgi_basic_group1ns.S
 * Purpose:   Basic SGI delivery, group1ns. Self-injected via GICR_ISPENDR0
 *            (no testbench needed). Handler acks/EOIs via common API.
 ******************************************************************************/
#include "gic_common.h"

.equ SGI_INTID, 0

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        bl      gic_check_secure
        cbz     x0,test_fail
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
        msr     daifclr,#2
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
