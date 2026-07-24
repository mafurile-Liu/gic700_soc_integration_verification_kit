/******************************************************************************
 * File:      sgi_broadcast.S
 * Purpose:   SGI broadcast via ICC_SGI1R_EL1 IRM=1 (all PEs except self).
 *            NOTE: broadcast excludes the originator; on a single-PE run this
 *            PE does NOT receive it. Reception is verified on a peer PE.
 *            Layout (IHI0069 p225): INTID[27:24] IRM[40].
 ******************************************************************************/
#include "gic_common.h"

.equ SGI_INTID, 0

        .section .text
        .align 4
        .global test_start
        .global irq_handler

test_start:
        bl      gic_init_grp1ns
        mov     x0,#SGI_INTID
        bl      ppi_set_group_ns
        mov     x0,#SGI_INTID
        mov     x1,#0x80
        bl      ppi_set_prio
        mov     x0,#SGI_INTID
        bl      ppi_enable
        /* broadcast: IRM[40]=1, INTID[27:24] */
        mov     x1,#SGI_INTID
        lsl     x1,x1,#24
        movz    x0,#0x100,lsl #32
        orr     x0,x0,x1
        msr     ICC_SGI1R_EL1,x0
        dsb     sy
        b       test_pass

irq_handler:
        b       gic_irq_handler_grp1
