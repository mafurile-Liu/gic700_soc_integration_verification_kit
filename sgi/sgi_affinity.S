/******************************************************************************
 * File:      sgi_affinity.S
 * Purpose:   SGI to THIS PE via ICC_SGI1R_EL1 IRM=0 (target list = self).
 *            Layout (IHI0069 p225): Aff3[55:48] Aff2[39:32] INTID[27:24]
 *            Aff1[23:16] TargetList[15:0].
 ******************************************************************************/
#include "gic_common.h"

.equ SGI_INTID, 0

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
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
        /* build ICC_SGI1R_EL1: target this PE (IRM=0) */
        mrs     x2,mpidr_el1
        ubfx    x3,x2,#8,#8
        ubfx    x4,x2,#16,#8
        ubfx    x5,x2,#32,#8
        and     x6,x2,#0xff
        mov     x7,#1
        lsl     x6,x7,x6
        mov     x1,#SGI_INTID
        lsl     x0,x1,#24
        bfi     x0,x3,#16,#8
        bfi     x0,x4,#32,#8
        bfi     x0,x5,#48,#8
        orr     x0,x0,x6
        msr     ICC_SGI1R_EL1,x0
                bl      tb_notify_ready
        dsb     sy
        isb
        msr     daifclr,#2

wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
