/******************************************************************************
 * File:      common/soc_test_edge.s
 * Purpose:   Generic SoC test template (edge-triggered).
 *            Configures ALL SPIs (INTID 32..991) as edge-triggered
 *            Secure Group 1, then WFI. Testbench can inject any SPI.
 *
 *            Provides weak hooks for user customization:
 *              - test_start: override with your own .S test
 *              - user_int_test: C function called between tb_notify_ready
 *                and WFI (configure extra interrupts, custom init, etc.)
 *
 * Flow:
 *   1. gic_init_grp1s
 *   2. Loop: set group + edge + prio + route + enable for all 960 SPIs
 *   3. tb_notify_ready(1)  [1=edge]
 *   4. bl user_int_test (weak, NOP if undefined)
 *   5. DSB + ISB + daifclr + WFI
 *
 * For level-triggered tests, use soc_test_level.s instead.
 ******************************************************************************/
#include "gic_common.h"

.equ SCAN_START, 32
.equ SCAN_END,   991

        .section .text
        .align 4
        .weak   test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s

        /* Configure ALL SPIs (32..991) as Secure Group 1, edge, route self, enable */
        mov     x20,#SCAN_START
config_loop:
        mov     x0,x20
        bl      spi_set_group_1s
        mov     x0,x20
        mov     x1,#0x80
        bl      spi_set_prio
        mov     x0,x20
        bl      spi_set_edge
        mov     x0,x20
        bl      spi_route_self
        mov     x0,x20
        bl      spi_enable
        add     x20,x20,#1
        cmp     x20,#SCAN_END
        b.le    config_loop

        /* Set expected INTID to 0 (TB will write actual expected INTID
           to TB_EXPECTED_INTID_ADDR before injecting) */
        ldr     x1,=gic_expected_intid
        str     xzr,[x1]

        /* Notify testbench: edge-triggered (1), all SPIs configured */
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
