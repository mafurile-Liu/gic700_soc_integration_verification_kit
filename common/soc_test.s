/******************************************************************************
 * File:      common/soc_test.s
 * Purpose:   Generic SoC test template. Provides a complete, compilable
 *            test with a weak C hook (user_int_test) between tb_notify_ready
 *            and WFI. Users implement user_int_test in C to add custom
 *            initialization without modifying assembly.
 *
 *            Flow:
 *              1. gic_init_grp1s (GICD + GICR + CPU interface)
 *              2. Configure default SPI 32 (level, group 1s)
 *              3. Set expected INTID
 *              4. tb_notify_ready (signal testbench, trigger type)
 *              5. bl user_int_test (WEAK: NOP if not defined)
 *              6. DSB + ISB + daifclr + WFI
 *
 *            To customize: define user_int_test in a C file:
 *              void user_int_test(void) { ... your code ... }
 *            Compile and link with soc_test.o + gic_common.o + user_handler.o
 *
 *            To override entirely: define your own test_start label
 *            in a separate .S file. This file's test_start is weak.
 ******************************************************************************/
#include "gic_common.h"

.equ SOC_INTID, 32

        .section .text
        .align 4
        .weak   test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s

        /* Default: configure SPI 32 as level-triggered Secure Group 1 */
        mov     x0,#SOC_INTID
        bl      spi_config_1s

        /* Set expected INTID */
        ldr     x1,=gic_expected_intid
        mov     x2,#SOC_INTID
        str     x2,[x1]

        /* Notify testbench: level-triggered (2) */
        mov     x0,#2
        bl      tb_notify_ready

        /* Weak hook: user can insert custom C code here.
           Example uses: configure additional interrupts, set up custom
           handlers, write testbench signals, read/write GIC state. */
        .weak   user_int_test
        bl      user_int_test

        /* Prepare for WFI */
        dsb     sy
        isb
        msr     daifclr,#2

wait_loop:
        wfi
        b       wait_loop

/*----------------------------------------------------------
 * Default IRQ handler: ack + notify + user_handler + pending wait + EOI + check
 *----------------------------------------------------------*/
curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
