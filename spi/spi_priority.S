/******************************************************************************
 * File:      spi_priority.S
 * Purpose:   SPI priority override (0x40).
 ******************************************************************************/
#include "gic_common.h"

.equ SPI_INTID, 32

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1ns
        bl      gic_check_ns
        cbz     x0,test_fail
        ldr     x1,=gic_expected_intid
        mov     x2,#SPI_INTID
        str     x2,[x1]
        mov     x0,#SPI_INTID
        bl      spi_config_ns
        mov     x0,#SPI_INTID
        mov     x1,#0x40
        bl      spi_set_prio

/*---- Testbench: force SPI input active now ----*/

        dsb     sy
        isb
        msr     daifclr,#2
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
