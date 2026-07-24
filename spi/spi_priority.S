/******************************************************************************
 * File:      spi_priority.S
 * Purpose:   SPI priority override (0x40).
 ******************************************************************************/
#include "gic_common.h"

.equ SPI_INTID, 32

        .section .text
        .align 4
        .global test_start
        .global irq_handler

test_start:
        bl      gic_init_grp1ns
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

irq_handler:
        b       gic_irq_handler_grp1
