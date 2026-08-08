/*
 * User callback hook for GIC interrupt handler.
 *
 * This function is called from gic_irq_handler_grp1 after ack + eoi,
 * with the received INTID passed as the argument.
 *
 * Default implementation: does nothing. The handler proceeds to its
 * default pass/fail logic (compare against gic_expected_intid).
 *
 * To customize: either edit this file, or define gic_user_handler in
 * a separate .c file and exclude this one from the build. The assembly
 * side declares it .weak, so any strong definition overrides this.
 *
 * Compile: aarch64-linux-gnu-gcc -c user_handler.c -o user_handler.o
 * Link:    ld test.o gic_common.o gic_its.o user_handler.o ...
 *
 * IMPORTANT: This function runs in EL3 exception context.
 *   - IRQ is unmasked (can be preempted by higher priority)
 *   - Stack is valid (set up by bootcode, 16-byte aligned)
 *   - x0 = intid (AAPCS first argument)
 *   - x0 and x30 are saved/restored by the caller (handler)
 *   - Do NOT call test_pass/test_fail from here unless you also
 *     prevent the handler from continuing to its default logic.
 */

__attribute__((weak))
void gic_user_handler(unsigned int intid)
{
    /* TODO: add custom handler logic here.
     * intid = the interrupt ID that was acknowledged (read from IAR).
     *
     * Examples of what you can do:
     *   - Log the INTID to a testbench-accessible address
     *   - Perform additional GIC register checks
     *   - Count interrupt occurrences
     *   - Signal the testbench via TB_RESULT_ADDR
     */
    (void)intid;  /* suppress unused parameter warning */
}
