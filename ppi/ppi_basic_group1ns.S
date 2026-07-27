/******************************************************************************
 * File:      ppi_basic_group1ns.S
 * Purpose:   Basic PPI delivery, NS Group 1.
 *            EL3: NS Group 1 -> FIQ (aliased). Handler: IAR1/EOIR1 via
 *            gic_fiq_handler_grp1ns.
 ******************************************************************************/
#include "gic_common.h"

.equ PPI_INTID, PPI_CNTV

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_fiq_vector

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
        msr     daifclr,#1
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_fiq_vector:
        b       gic_fiq_handler_grp1ns
