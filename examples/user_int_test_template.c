/*
 * Template for user_int_test() with irq_desc dispatch table.
 *
 * This function is called from assembly (soc_test_*.s) between
 * tb_notify_ready and WFI. Use it to register interrupt handlers.
 *
 * Compile: aarch64-linux-gnu-gcc -c -Icommon user_int_test_template.c -o user_int_test.o
 * Link:    ld test.o gic_common.o gic_its.o irq_desc.o user_int_test.o ...
 *
 * Note: link irq_desc.o (NOT user_handler.o) to get the dispatch table.
 *       The gic_user_handler in irq_desc.c is a strong definition that
 *       overrides the weak one in user_handler.c.
 */

#include "irq_desc.h"
#include <stdint.h>

/* ---- Example handlers ---- */

/* Handler for SPI 32 (level-triggered timer or similar) */
static void spi32_handler(unsigned int intid)
{
    /* Device-specific work:
     *   - Clear interrupt source (write to device register)
     *   - Read device data
     *   - Record statistics
     *   - Signal testbench
     *
     * Runs in EL3 exception context. Keep it short.
     * Assembly will do pending poll + EOI after this returns.
     */
    (void)intid;
}

/* Handler for SPI 33 */
static void spi33_handler(unsigned int intid)
{
    (void)intid;
}

/* ---- Entry point: called from assembly before WFI ---- */

void user_int_test(void)
{
    /* Register handlers for specific INTIDs */
    request_irq(32, spi32_handler);
    request_irq(33, spi33_handler);
    /* request_irq(34, another_handler); */

    /* Set expected INTID for the first interrupt.
     * Testbench can update this via TB_EXPECTED_INTID_ADDR before
     * injecting the next interrupt. */
    volatile uint32_t *expected = (volatile uint32_t *)0x274F0548UL;
    *expected = 32;  /* expect SPI 32 first */
}
