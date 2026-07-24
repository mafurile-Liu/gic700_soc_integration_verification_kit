/******************************************************************************
 * File:      vlpi_basic.S
 * Purpose:   Virtual LPI (GICv4) skeleton. vPE setup (VMAPP/VMOVP) + vLPI
 *            injection. See IHI0069 ch7/8, TRM 4.13/5.6.
 ******************************************************************************/
#include "gic_common.h"

.equ VLPI_INTID, 8192

        .section .text
        .align 4
        .global test_start
        .global irq_handler

test_start:
        bl      gic_init_grp1ns
        /* TODO(GICv4): vPE map (VMAPP), vLPI injection, guest ack via ICH_LR */
        ldr     x1,=gic_expected_intid
        mov     x2,#VLPI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#2
wait_loop:
        wfi
        b       wait_loop

irq_handler:
        b       gic_irq_handler_grp1
