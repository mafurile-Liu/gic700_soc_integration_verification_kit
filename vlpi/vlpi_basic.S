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
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        /* TODO(GICv4): vPE map (VMAPP), vLPI injection, guest ack via ICH_LR */
        ldr     x1,=gic_expected_intid
        mov     x2,#VLPI_INTID
        str     x2,[x1]
                bl      tb_notify_ready
        dsb     sy
        isb
        msr     daifclr,#2

wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
