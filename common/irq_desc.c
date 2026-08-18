/*
 * Interrupt Descriptor Table implementation.
 *
 * Static array of function pointers, indexed by INTID.
 * Covers INTID 0..991 (SGI 0-15, PPI 16-31, SPI 32-991).
 * LPI (8192+) are not in this table (handled via ITS, separate path).
 *
 * This file provides a STRONG definition of gic_user_handler that
 * dispatches via the table. Link this file instead of user_handler.c
 * when you want interrupt dispatch.
 *
 * Bare-metal equivalent of Linux:
 *   request_irq()      <=> Linux request_irq() / request_threaded_irq()
 *   gic_user_handler() <=> Linux generic_handle_irq() -> desc->handle_irq()
 *   irq_desc[]         <=> Linux irq_desc[] array
 */

#include "irq_desc.h"

/* Static descriptor table. 992 entries * 8 bytes = ~8KB BSS.
 * Index directly by INTID (0..991). NULL = not registered. */
#define IRQ_DESC_MAX  992
static irq_handler_t irq_desc[IRQ_DESC_MAX];

int request_irq(unsigned int intid, irq_handler_t handler)
{
    if (intid >= IRQ_DESC_MAX || handler == (void *)0) {
        return -1;
    }
    if (irq_desc[intid] != (void *)0) {
        return -1;  /* already registered */
    }
    irq_desc[intid] = handler;
    return 0;
}

int free_irq(unsigned int intid)
{
    if (intid >= IRQ_DESC_MAX) {
        return -1;
    }
    if (irq_desc[intid] == (void *)0) {
        return -1;  /* not registered */
    }
    irq_desc[intid] = (void *)0;
    return 0;
}

irq_handler_t get_irq_handler(unsigned int intid)
{
    if (intid >= IRQ_DESC_MAX) {
        return (void *)0;
    }
    return irq_desc[intid];
}

/*
 * gic_user_handler: STRONG definition (overrides weak in user_handler.c
 * and weak in gic_common.S/gic_its.S).
 *
 * Dispatches to the registered handler for the given INTID.
 * If no handler is registered, does nothing -- assembly proceeds to
 * default pass/fail check (compare against gic_expected_intid).
 *
 * This is called from assembly between tb_notify_int_taken (IAR done)
 * and tb_wait_int_deasserted (pending poll before EOI):
 *
 *   IAR -> notify_flag -> gic_user_handler(intid) -> pending_poll -> EOI
 *                              |
 *                              v
 *                        irq_desc[intid](intid)
 *                              |
 *                              v
 *                        user's registered handler
 */
void gic_user_handler(unsigned int intid)
{
    irq_handler_t handler = get_irq_handler(intid);
    if (handler != (void *)0) {
        handler(intid);
    }
    /* No handler registered: NOP. Assembly does default pass/fail. */
}
