/******************************************************************************
 * File:      spi_level.S
 * Purpose:   SPI level-sensitive. Testbench de-asserts after IAR.
 ******************************************************************************/
#include "gic_common.h"

.equ SPI_INTID, 32

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        bl      gic_check_secure
        cbz     x0,test_fail
        ldr     x1,=gic_expected_intid
        mov     x2,#SPI_INTID
        str     x2,[x1]
        mov     x0,#SPI_INTID
        bl      spi_config_1s

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
