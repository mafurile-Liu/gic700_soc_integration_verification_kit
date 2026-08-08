/******************************************************************************
 * File:      spi_basic_group1s.S
 * Purpose:   Basic SPI delivery, group1s. Testbench forces SPI input signal (SPI Collator)
 *            after WFI; handler acks/EOIs and checks INTID via common API.
 ******************************************************************************/
#include "gic_common.h"

.equ SPI_INTID, 32

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        ldr     x1,=gic_expected_intid
        mov     x2,#SPI_INTID
        str     x2,[x1]
        mov     x0,#SPI_INTID
        bl      spi_config_1s

/*---- Testbench: force SPI input signal (SPI Collator) active now (PE is entering WFI) ----*/

        dsb     sy
        isb
        msr     daifclr,#2
        mov     x0,#2   /* level-triggered */
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
