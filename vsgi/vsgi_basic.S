/******************************************************************************
 * File:      vsgi_basic.S
 * Purpose:   Virtual SGI direct injection via GITS_SGIR (vPE + SGI INTID).
 *            TRM 4.9.2, IHI0069 ch8. GITS_SGIR at offset 0x0020 (vSGI frame).
 ******************************************************************************/
#include "gic_common.h"

.equ VSGI_INTID, 0

        .section .text
        .align 4
        .global test_start
        .global irq_handler

test_start:
        bl      gic_init_grp1ns
        /* TODO(GICv4): map vPE (VMAPP), then inject vSGI via GITS_SGIR */
        ldr     x0,=GITS_BASE
        mov     x1,#VSGI_INTID
        str     x1,[x0,#GITS_SGIR]
        ldr     x1,=gic_expected_intid
        mov     x2,#VSGI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#2
wait_loop:
        wfi
        b       wait_loop

irq_handler:
        b       gic_irq_handler_grp1
