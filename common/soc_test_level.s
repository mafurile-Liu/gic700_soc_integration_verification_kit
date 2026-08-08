/******************************************************************************
 * File:      common/soc_test_level.s
 * Purpose:   Generic SoC test template (level-triggered).
 *            Configures SPI 32 as level-triggered Secure Group 1.
 *            Provides weak hooks for user customization:
 *              - test_start: override with your own .S test
 *              - user_int_test: C function called between tb_notify_ready
 *                and WFI (configure extra interrupts, custom init, etc.)
 *
 * Flow:
 *   1. gic_init_grp1s
 *   2. spi_config_1s (SPI 32, level, group 1s)
 *   3. set expected INTID
 *   4. tb_notify_ready(2)  [2=level]
 *   5. bl user_int_test (weak, NOP if undefined)
 *   6. DSB + ISB + daifclr + WFI
 *
 * For edge-triggered tests, use soc_test_edge.s instead.
 ******************************************************************************/
#include "gic_common.h"

.equ SOC_INTID, 32

        .section .text
        .align 4
        .weak   test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s

        /* Configure SPI 32: Secure Group 1, level, route self, enable */
        mov     x0,#SOC_INTID
        bl      spi_config_1s

        /* Set expected INTID */
        ldr     x1,=gic_expected_intid
        mov     x2,#SOC_INTID
        str     x2,[x1]

        /* Notify testbench: level-triggered (2) */
        mov     x0,#2
        bl      tb_notify_ready

        /* Weak hook: user custom C code (NOP if not linked) */
        .weak   user_int_test
        bl      user_int_test

        /* Prepare for WFI */
        dsb     sy
        isb
        msr     daifclr,#2

wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
