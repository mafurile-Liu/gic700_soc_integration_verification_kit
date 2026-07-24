// LPI priority check (Non-secure Group 1).
// LPI priority is stored in the Property table byte ([7] Enable, [6:3] Priority,
// lower 5 bits used). This test sets a specific priority, programs ICC_PMR, and
// checks delivery. Reuses the ITS bring-up from lpi_basic.S; only the Property
// table entry and PMR differ.
//
// See lpi_basic.S for the full ITS bring-up and GITS_TRANSLATER trigger. Here we
// highlight the Property-table priority programming.
#include "gic_common.h"
#define LPI_INTID   (INTID_FIRST_LPI + 0)
#define LPI_PROP_BASE 0x00000000   // TODO: real addr (same table as lpi_basic)
// Property byte: [7]Enable [6:3]Priority [2:0]Res1. Priority 5-bit, 0 highest.
#define LPI_PRIO_BYTE(prio, en)  (((en) << 7) | (((prio) & 0x1f) << 3) | 0x7)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    // (Assume ITS + LPI tables already configured by the bring-up in lpi_basic.S.)
    bl gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1

    // Write the Property-table entry for LPI_INTID: enabled, priority 0x08.
    ldr x0, =LPI_PROP_BASE
    mov w1, #LPI_PRIO_BYTE(0x08, 1)
    strb w1, [x0, #(LPI_INTID - INTID_FIRST_LPI)]
    // Ensure the GIC sees the update (INV + SYNC, or rely on initial config).
    mov x0, #0xFF
    msr ICC_PMR_EL1, x0  // allow all priorities
    isb  //  Instruction Synchronization Barrier

    // Trigger the LPI (GITS_TRANSLATER) - reuse lpi_basic flow.
    // TODO: full ITS bring-up + GITS_TRANSLATER write (see lpi_basic.S).
    bl wfi_wait_irq

    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
    mrs x3, ICC_IAR1_EL1  //  Ack Group 1: read returns INTID, advances state (pending->active)
    msr ICC_EOIR1_EL1, x3  //  EOI Group 1: priority drop + deactivate (EOImode=0)
    mov x2, #LPI_INTID
    cmp x3, x2
    b.ne lpi_fail
    bl report_pass
lpi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
