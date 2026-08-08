/******************************************************************************
 * File:      common/soc_test_edge.s
 * Purpose:   Generic SoC test template (edge-triggered).
 *            Configures SPI 32 as edge-triggered Secure Group 1.
 *            Provides weak hooks for user customization:
 *              - test_start: override with your own .S test
 *              - user_int_test: C function called between tb_notify_ready
 *                and WFI (configure extra interrupts, custom init, etc.)
 *
 * Flow:
 *   1. gic_init_grp1s
 *   2. spi_set_group_1s + spi_set_edge + spi_set_prio + spi_route_self + spi_enable
 *   3. set expected INTID
 *   4. tb_notify_ready(1)  [1=edge]
 *   5. bl user_int_test (weak, NOP if undefined)
 *   6. DSB + ISB + daifclr + WFI
 *
 * For level-triggered tests, use soc_test_level.s instead.
 ******************************************************************************/
#include "gic_common.h"

.equ SOC_INTID, 32

        .section .text
        .align 4
        .weak   test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s

        /* Configure SPI 32: Secure Group 1, edge-triggered, route self */
        mov     x0,#SOC_INTID
        bl      spi_set_group_1s
        mov     x0,#SOC_INTID
        mov     x1,#0x80
        bl      spi_set_prio
        mov     x0,#SOC_INTID
        bl      spi_set_edge
        mov     x0,#SOC_INTID
        bl      spi_route_self
        mov     x0,#SOC_INTID
        bl      spi_enable

        /* Set expected INTID */
        ldr     x1,=gic_expected_intid
        mov     x2,#SOC_INTID
        str     x2,[x1]

        /* Notify testbench: edge-triggered (1) */
        mov     x0,#1
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
