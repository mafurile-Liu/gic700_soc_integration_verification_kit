/******************************************************************************
 * File:      ppi_basic_group0.S
 * Purpose:   Basic PPI delivery, Group 0.
 *            EL3: Group 0 -> FIQ. Handler: IAR0/EOIR0 via gic_fiq_handler_grp0.
 ******************************************************************************/
#include "gic_common.h"

.equ PPI_INTID, PPI_CNTV

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_fiq_vector

test_start:
        bl      gic_init_grp0
        ldr     x1,=gic_expected_intid
        mov     x2,#PPI_INTID
        str     x2,[x1]
        mov     x0,#PPI_INTID
        bl      ppi_config_grp0

/*---- Testbench: force PPI input signal active now (PE is entering WFI) ----*/

                bl      tb_notify_ready
        dsb     sy
        isb
        msr     daifclr,#1

wait_loop:
        wfi
        b       wait_loop

curr_el_spx_fiq_vector:
        b       gic_fiq_handler_grp0
