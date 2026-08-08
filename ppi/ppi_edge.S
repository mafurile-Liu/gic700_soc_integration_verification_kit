/******************************************************************************
 * File:      ppi_edge.S
 * Purpose:   PPI edge-triggered via ppi_set_edge.
 ******************************************************************************/
#include "gic_common.h"

.equ PPI_INTID, PPI_CNTV

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        ldr     x1,=gic_expected_intid
        mov     x2,#PPI_INTID
        str     x2,[x1]
        mov     x0,#PPI_INTID
        bl      ppi_config_1s
        mov     x0,#PPI_INTID
        bl      ppi_set_edge

/*---- Testbench: force PPI input active now ----*/

        dsb     sy
        isb
        msr     daifclr,#2
        mov     x0,#1   /* edge-triggered */
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
