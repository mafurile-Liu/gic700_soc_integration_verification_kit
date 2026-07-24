/******************************************************************************
 * File:      spi_basic_group1ns.S
 * Purpose:   Basic SPI delivery, group1ns. Testbench forces SPI input signal (SPI Collator)
 *            after WFI; handler acks/EOIs and checks INTID via common API.
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

/*---- Testbench: force SPI input signal (SPI Collator) active now (PE is entering WFI) ----*/

        dsb     sy
        isb
        msr     daifclr,#2
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

irq_handler:
        b       gic_irq_handler_grp1
