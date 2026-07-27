/******************************************************************************
 * File:      spi_scan.S
 * Purpose:   Scan ALL SPI INTIDs (32..991, 960 SPIs) in one simulation.
 *            For each INTID: config -> notify TB -> WFI -> handler acks/eois/
 *            checks/writes result -> clear notify -> next INTID.
 *            TB (UVM scan sequence) injects each SPI in lockstep.
 *            One sim covers all 960 SPIs for interface coverage.
 ******************************************************************************/
#include "gic_common.h"

.equ SCAN_START, 32
.equ SCAN_END,   991

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        bl      gic_check_secure
        cbz     x0,test_fail
        mov     x20, #SCAN_START
scan_loop:
        ldr     x1,=gic_expected_intid
        str     x20,[x1]
        mov     x0, x20
        bl      spi_config_1s
        bl      tb_notify_ready
        dsb     sy
        isb
        msr     daifclr,#2
        wfi
        /* handler runs (IRQ taken), erets back here */
        ldr     x1,=TB_READY_ADDR
        str     xzr,[x1]               /* clear notify for next round */
        add     x20, x20, #1
        cmp     x20, #SCAN_END
        b.le    scan_loop
        bl      test_pass

curr_el_spx_irq_vector:
        bl      gic_ack_grp1
        mov     x9, x0
        bl      gic_eoi_grp1
        ldr     x1,=gic_expected_intid
        ldr     x2,[x1]
        cmp     x9, x2
        b.ne    scan_one_fail
        ldr     x1,=TB_RESULT_ADDR
        str     xzr,[x1]               /* pass (0) */
        b       scan_done
scan_one_fail:
        ldr     x1,=TB_RESULT_ADDR
        mov     x2, #1
        str     x2,[x1]                /* fail (1) */
scan_done:
        eret
