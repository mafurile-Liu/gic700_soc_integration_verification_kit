/******************************************************************************
 * File:      ppi_basic_group1ns.S
 * Purpose:   Basic PPI delivery, group1ns. Testbench forces PPI input signal
 *            after WFI; handler acks/EOIs and checks INTID via common API.
 ******************************************************************************/
#include "gic_common.h"

.equ PPI_INTID, PPI_CNTV

        .section .text
        .align 4
        .global test_start
        .global irq_handler

test_start:
        bl      gic_init_grp1ns
        ldr     x1,=gic_expected_intid
        mov     x2,#PPI_INTID
        str     x2,[x1]
        mov     x0,#PPI_INTID
        bl      ppi_config_ns

/*---- Testbench: force PPI input signal active now (PE is entering WFI) ----*/

        dsb     sy
        isb
        msr     daifclr,#2
wait_loop:
        wfi
        b       wait_loop

irq_handler:
        b       gic_irq_handler_grp1
