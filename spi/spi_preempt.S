// SPI preemption (Non-secure Group 1).
// SPI_LO (INTID 32, prio 0x80) is taken first; its handler injects SPI_HI (INTID
// 33, prio 0x40, higher) via GICD_ISPENDRn -> preempts. Both routed to this PE.
// BPR1=0. Verifies nested IAR order and preemption occurrence.
#include "gic_common.h"
#define SPI_LO 32
#define SPI_HI 33
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1
    msr ICC_BPR1_EL1, xzr  //  Binary Point (Group1): group/sub-priority split; lower value = more preemption
    LOAD_GICD(x0)
    ldr w1, [x0, #SPI_IGROUPR_OFF(SPI_LO)]
    orr w1, w1, #SPI_BIT(SPI_LO)
    orr w1, w1, #SPI_BIT(SPI_HI)
    str w1, [x0, #SPI_IGROUPR_OFF(SPI_LO)]
    ldr w1, [x0, #(GICD_IGRPMODRn + SPI_BANK(SPI_LO)*4)]  //  SPI Group modifier
    bic w1, w1, #SPI_BIT(SPI_LO)
    bic w1, w1, #SPI_BIT(SPI_HI)
    str w1, [x0, #(GICD_IGRPMODRn + SPI_BANK(SPI_LO)*4)]  //  SPI Group modifier
    mov w1, #0x80
    strb w1, [x0, #SPI_IPRIORITYR_OFF(SPI_LO)]
    mov w1, #0x40
    strb w1, [x0, #SPI_IPRIORITYR_OFF(SPI_HI)]
    ldr w1, [x0, #SPI_ICFGR_OFF(SPI_LO)]
    bic w1, w1, #(3 << SPI_ICFGR_SHIFT(SPI_LO))
    bic w1, w1, #(3 << SPI_ICFGR_SHIFT(SPI_HI))
    str w1, [x0, #SPI_ICFGR_OFF(SPI_LO)]
    mrs x2, mpidr_el1  //  MPIDR: Aff0[7:0] Aff1[15:8] Aff2[23:16] Aff3[39:32]
    and x3, x2, #0xFFFFFF
    ubfx x4, x2, #32, #8
    bfi x3, x4, #32, #8
    str x3, [x0, #SPI_IROUTER_OFF(SPI_LO)]
    str x3, [x0, #SPI_IROUTER_OFF(SPI_HI)]
    ldr w1, [x0, #SPI_ISENABLER_OFF(SPI_LO)]
    orr w1, w1, #SPI_BIT(SPI_LO)
    orr w1, w1, #SPI_BIT(SPI_HI)
    str w1, [x0, #SPI_ISENABLER_OFF(SPI_LO)]
    adr x1, preempt_seen
    str xzr, [x1]
    mov w1, #SPI_BIT(SPI_LO)
    str w1, [x0, #SPI_ISPENDR_OFF(SPI_LO)]  // inject LO
    bl wfi_wait_irq
1:  b    1b

    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    mrs x3, ICC_IAR1_EL1  //  Ack Group 1: read returns INTID, advances state (pending->active)
    cmp x3, #SPI_HI
    b.eq spi_hi
    adr x1, preempt_lo_id
    str x3, [x1]
    msr daifclr, #2  //  unmask IRQ (clear PSTATE.I)
    LOAD_GICD(x10)
    mov w11, #SPI_BIT(SPI_HI)
    str w11, [x10, #SPI_ISPENDR_OFF(SPI_HI)]  // inject HI -> preempts
    dsb sy  //  Data Synchronization Barrier (make GIC writes visible)
2:  adr  x1, preempt_seen
    ldr x2, [x1]
    cmp x2, #1
    b.ne 2b
    adr x1, preempt_lo_id
    ldr x3, [x1]
    msr ICC_EOIR1_EL1, x3  //  EOI Group 1: priority drop + deactivate (EOImode=0)
    cmp x3, #SPI_LO
    b.ne spi_preempt_fail
    bl report_pass
spi_preempt_fail:
    bl report_fail
3:  b    3b

spi_hi:
    adr x1, preempt_seen
    mov x2, #1
    str x2, [x1]
    msr ICC_EOIR1_EL1, x3  //  EOI Group 1: priority drop + deactivate (EOImode=0)
    eret  //  Exception Return - resume interrupted code

    .balign 8
preempt_seen:  .word 0
    .word 0
preempt_lo_id: .quad 0
    .end
