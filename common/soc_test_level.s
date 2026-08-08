/******************************************************************************
 * File:      common/soc_test_level.s
 * Purpose:   Generic SoC test template (level-triggered).
 *            Configures ALL SPIs (INTID 32..991) as level-triggered
 *            Secure Group 1, then WFI. Testbench can inject any SPI.
 *
 *            Provides weak hooks for user customization:
 *              - test_start: override with your own .S test
 *              - user_int_test: C function called between tb_notify_ready
 *                and WFI (configure extra interrupts, custom init, etc.)
 *
 * Flow:
 *   1. gic_init_grp1s
 *   2. Loop: spi_config_1s for all 960 SPIs (32..991)
 *   3. tb_notify_ready(2)  [2=level]
 *   4. bl user_int_test (weak, NOP if undefined)
 *   5. DSB + ISB + daifclr + WFI
 *
 * For edge-triggered tests, use soc_test_edge.s instead.
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

        /* Configure ALL SPIs (32..991) as Secure Group 1, level, route self, enable */
        mov     x20,#SCAN_START
config_loop:
        mov     x0,x20
        bl      spi_config_1s
        add     x20,x20,#1
        cmp     x20,#SCAN_END
        b.le    config_loop

        /* Set expected INTID to 0 (TB will write actual expected INTID
           to TB_EXPECTED_INTID_ADDR before injecting) */
        ldr     x1,=gic_expected_intid
        str     xzr,[x1]

        /* Notify testbench: level-triggered (2), all SPIs configured */
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
