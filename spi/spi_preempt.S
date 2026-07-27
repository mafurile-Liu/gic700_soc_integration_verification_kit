/******************************************************************************
 * File:      spi_preempt.S
 * Purpose:   SPI preemption: LO (INTID 32, prio 0x80) is taken,
 *            handler injects HI (INTID 33, prio 0x40) which preempts.
 *            Verifies nested ack order and preemption occurrence.
 ******************************************************************************/
#include "gic_common.h"

.equ LO_ID, 32
.equ HI_ID, 33

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        bl      gic_check_secure
        cbz     x0,test_fail
        msr     ICC_BPR1_EL1,xzr
        /* config LO: group NS, prio 0x80, level, enable */
        mov     x0,#LO_ID
        bl      spi_set_group_ns
        mov     x0,#LO_ID
        mov     x1,#0x80
        bl      spi_set_prio
        mov     x0,#LO_ID
        bl      spi_set_level
        mov     x0,#LO_ID
        bl      spi_enable
        /* config HI: group NS, prio 0x40, level, enable */
        mov     x0,#HI_ID
        bl      spi_set_group_ns
        mov     x0,#HI_ID
        mov     x1,#0x40
        bl      spi_set_prio
        mov     x0,#HI_ID
        bl      spi_set_level
        mov     x0,#HI_ID
        bl      spi_enable
        /* expected = LO */
        ldr     x1,=gic_expected_intid
        mov     x2,#LO_ID
        str     x2,[x1]
        /* clear seen flag, inject LO */
        ldr     x1,=preempt_seen
        str     xzr,[x1]
        mov     x0,#LO_ID
        bl      spi_set_pend
        dsb     sy
        isb
        msr     daifclr,#2
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        bl      gic_ack_grp1
        mov     x9,x0
        cmp     x9,#HI_ID
        b.eq    hi_path
        /* LO path: save id, unmask, inject HI, wait for HI seen, eoi, check */
        ldr     x1,=preempt_lo_id
        str     x9,[x1]
        msr     daifclr,#2
        mov     x0,#HI_ID
        bl      spi_set_pend
        dsb     sy
1:      ldr     x1,=preempt_seen
        ldr     x2,[x1]
        cmp     x2,#1
        b.ne    1b
        ldr     x0,=preempt_lo_id
        ldr     x0,[x0]
        bl      gic_eoi_grp1
        cmp     x0,#LO_ID
        b.ne    test_fail
        b       test_pass
hi_path:
        ldr     x1,=preempt_seen
        mov     x2,#1
        str     x2,[x1]
        mov     x0,x9
        bl      gic_eoi_grp1
        eret

        .section .data
        .align 3
preempt_seen:
        .quad 0
preempt_lo_id:
        .quad 0
