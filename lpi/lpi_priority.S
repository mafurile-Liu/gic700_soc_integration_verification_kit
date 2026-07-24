/******************************************************************************
 * File:      lpi_priority.S
 * Purpose:   LPI priority (Property table byte [7]enable [6:3]priority).
 *            Reuses ITS bring-up from lpi_basic.S; only the Property entry
 *            differs. See lpi_basic.S for the full ITS flow.
 ******************************************************************************/
#include "gic_common.h"

.equ LPI_INTID, 8192

        .section .text
        .align 4
        .global test_start
        .global irq_handler

test_start:
        bl      gic_init_grp1ns
        /* Property entry: enabled, priority 0x08 -> byte = (1<<7)|(0x08<<3)|0x7 */
        ldr     x0,=lpi_prop_base
        ldr     x1,[x0]
        mov     w2,#0x47
        strb    w2,[x1,#(LPI_INTID-8192)]
        mov     x0,#0xff
        msr     ICC_PMR_EL1,x0
        isb
        /* TODO: full ITS bring-up + GITS_TRANSLATER (see lpi_basic.S) */
        ldr     x1,=gic_expected_intid
        mov     x2,#LPI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#2
wait_loop:
        wfi
        b       wait_loop

irq_handler:
        b       gic_irq_handler_grp1

        .section .data
        .align 3
lpi_prop_base:  .quad 0
