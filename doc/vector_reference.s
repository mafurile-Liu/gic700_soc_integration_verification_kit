        .section vectors, "ax", %progbits
        .global vector_table

        // Weakly-import test-defined handlers. The weak import means that if
        // a test does not define the handler then the default one will be
        // used.
        .weak   curr_el_sp0_sync_vector
        .weak   curr_el_sp0_irq_vector
        .weak   curr_el_sp0_fiq_vector
        .weak   curr_el_sp0_serror_vector
        .weak   curr_el_spx_sync_vector
        .weak   curr_el_spx_irq_vector
        .weak   curr_el_spx_fiq_vector
        .weak   curr_el_spx_serror_vector
        .weak   lower_el_aarch64_sync_vector
        .weak   lower_el_aarch64_irq_vector
        .weak   lower_el_aarch64_fiq_vector
        .weak   lower_el_aarch64_serror_vector
        .weak   lower_el_aarch32_sync_vector
        .weak   lower_el_aarch32_irq_vector
        .weak   lower_el_aarch32_fiq_vector
        .weak   lower_el_aarch32_serror_vector

        // Start of vectors
        .balign 0x800

        // Current EL with SP0
vector_table:
curr_el_sp0_sync:
        // Branch to the weakly-imported test-defined handler. If the test
        // does not define a handler then this instruction behaves like a NOP.
        b       curr_el_sp0_sync_vector

        // Default code when a test does not define a replacement handler
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_sp0_sync\n"

        // Ensure next vector is aligned to the correct boundary
        .balign 0x80
curr_el_sp0_irq:
        b       curr_el_sp0_irq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_sp0_irq\n"

        .balign 0x80
curr_el_sp0_fiq:
        b       curr_el_sp0_fiq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_sp0_fiq\n"

        .balign 0x80
curr_el_sp0_serror:
        b       curr_el_sp0_serror_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_sp0_serror\n"

        .balign 0x80
        // Current EL with SPx
curr_el_spx_sync:
        b       curr_el_spx_sync_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_spx_sync\n"

        .balign 0x80
curr_el_spx_irq:
        b       curr_el_spx_irq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_spx_irq\n"

        .balign 0x80
curr_el_spx_fiq:
        b       curr_el_spx_fiq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_spx_fiq\n"

        .balign 0x80
curr_el_spx_serror:
        b       curr_el_spx_serror_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: curr_el_spx_serror\n"

        .balign 0x80
        // Lower EL using AArch64
lower_el_aarch64_sync:
        b       lower_el_aarch64_sync_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch64_sync\n"

        .balign 0x80
lower_el_aarch64_irq:
        b       lower_el_aarch64_irq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch64_irq\n"

        .balign 0x80
lower_el_aarch64_fiq:
        b       lower_el_aarch64_fiq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch64_fiq\n"

        .balign 0x80
lower_el_aarch64_serror:
        b       lower_el_aarch64_serror_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch64_serror\n"

        .balign 0x80
        // Lower EL using AArch32
lower_el_aarch32_sync:
        b       lower_el_aarch32_sync_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch32_sync\n"

        .balign 0x80
lower_el_aarch32_irq:
        b       lower_el_aarch32_irq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch32_irq\n"

        .balign 0x80
lower_el_aarch32_fiq:
        b       lower_el_aarch32_fiq_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch32_fiq\n"

        .balign 0x80
lower_el_aarch32_serror:
        b       lower_el_aarch32_serror_vector
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: lower_el_aarch32_serror\n"

        .balign 0x80
        .weak   lower_el_aarch32_sync_vector
        .balign 64
lower_el_aarch32_sync_vector:
        mrs     x0, ESR_EL1
        ubfx    x1, x0, #26, #6          // Extract EC field
        cmp     x1, #17
        b.ne    non_svc

        ubfx    x0, x0, #0, 16           // Extract the ISS field
        cmp     x0, #1
        b.ne    mpidr_extract
        mrs     x0, midr_el1             // Reading the MIDR_EL1 register
        b       return

mpidr_extract:
        cmp     x0, #2
        b.ne    id_extract
        mrs     x0, mpidr_el1            // Reading the MPIDR_EL1 register
        b       return

id_extract:
        cmp     x0, #3
        b.ne    unsupported_ISS_field
        mrs     x0, ID_AA64ISAR0_EL1     // Reading the ID_AA64ISAR0_EL1 register

return:
        eret

non_svc:
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: Not a SVC exception\n"

        .balign 0x80
unsupported_ISS_field:
        mov     x0, #0x13000000          // Tube address
        adr     x1, 1f
        bl      print
        b       terminate
1:
        .asciz  "Unexpected exception: Only svc #1, #2, #3 are supported\n"

        .balign 0x80
// End of vectors
//-----------------------------------------------------------------------------

        // Print a string to the tube
        // Expects: x0 = tube
        //          x1 = message
        // Modifies x2
print:
        ldrb    w2, [x1], #1
        cbz     w2, 1f
        strb    w2, [x0]
        b       print
1:
        ret

        // Print failure message and terminate simulation.
        // Assumes x0 points to the tube
terminate:
        adr     x1, fail_str
        bl      print
        mov     w2, #0x04                // EOT character
        strb    w2, [x0]                 // Terminate simulation
        b       .

        // Failure string for unexpected exceptions
        .balign 4
fail_str:
        .asciz  "** TEST FAILED**\n"
        .end