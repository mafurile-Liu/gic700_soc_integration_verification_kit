/******************************************************************************
 * File:      ppi_basic_group1s.S
 * Purpose:   Basic PPI delivery, group1s. Testbench forces PPI input signal
 *            after WFI; handler acks/EOIs and checks INTID via common API.
 ******************************************************************************/
#include "gic_common.h"

.equ PPI_INTID, PPI_CNTV

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        bl      gic_check_secure
        cbz     x0,test_fail
        ldr     x1,=gic_expected_intid
        mov     x2,#PPI_INTID
        str     x2,[x1]
        mov     x0,#PPI_INTID
        bl      ppi_config_1s

/*---- Testbench: force PPI input signal active now (PE is entering WFI) ----*/

        dsb     sy
        isb
        msr     daifclr,#2
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
