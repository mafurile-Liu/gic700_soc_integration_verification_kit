#ifndef IRQ_DESC_H
#define IRQ_DESC_H

#include <stdint.h>

/*
 * Interrupt Descriptor Table (bare-metal equivalent of Linux irq_desc[]).
 *
 * Provides INTID -> handler function mapping with dynamic registration.
 * Usage:
 *   1. In user_int_test() (C, called before WFI):
 *        request_irq(32, my_spi_handler);
 *   2. When interrupt arrives, assembly calls gic_user_handler(intid),
 *      which dispatches to my_spi_handler(32).
 *   3. Handler does device-specific work, returns.
 *   4. Assembly does EOI + pass/fail check.
 *
 * Link irq_desc.o INSTEAD of user_handler.o to use dispatch table.
 * Link user_handler.o for simple tests (empty handler, no dispatch).
 */

/* Handler function type. Called with the acknowledged INTID.
 * Runs in EL3 exception context:
 *   - IRQ unmasked (can be preempted by higher priority)
 *   - Stack valid (set up by bootcode)
 *   - Do NOT call test_pass/test_fail from here
 *   - Return normally to let assembly proceed with EOI + pass/fail
 */
typedef void (*irq_handler_t)(unsigned int intid);

/*
 * request_irq: register a handler for the given INTID.
 *   intid:  interrupt ID (0..991 for SGI/PPI/SPI)
 *   handler: function to call when this interrupt is acknowledged
 *   Returns: 0 on success, -1 on failure (invalid INTID or already registered)
 *   Call from user_int_test() before WFI.
 */
int request_irq(unsigned int intid, irq_handler_t handler);

/*
 * free_irq: unregister the handler for the given INTID.
 *   Returns: 0 on success, -1 if no handler was registered.
 */
int free_irq(unsigned int intid);

/*
 * get_irq_handler: query registered handler for INTID.
 *   Returns: handler pointer, or NULL if not registered.
 */
irq_handler_t get_irq_handler(unsigned int intid);

#endif /* IRQ_DESC_H */
