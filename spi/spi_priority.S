// SPI priority + priority-mask (Non-secure Group 1). See ppi_priority.S pattern.
#include "gic_common.h"
#ifndef SPI_INTID
#define SPI_INTID 32
#endif
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl   gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1
    LOAD_GICD(x0)
    ldr  w1,[x0,#SPI_IGROUPR_OFF(SPI_INTID)]
    orr w1,w1,#SPI_BIT(SPI_INTID)
    str w1,[x0,#SPI_IGROUPR_OFF(SPI_INTID)]
    ldr  w1,[x0,#(GICD_IGRPMODRn+SPI_BANK(SPI_INTID)*4)]
    bic w1,w1,#SPI_BIT(SPI_INTID)
    str w1,[x0,#(GICD_IGRPMODRn+SPI_BANK(SPI_INTID)*4)]
    ldr  w1,[x0,#SPI_ICFGR_OFF(SPI_INTID)]
    bic w1,w1,#(3<<SPI_ICFGR_SHIFT(SPI_INTID))
    str w1,[x0,#SPI_ICFGR_OFF(SPI_INTID)]
    mrs  x2,mpidr_el1
    and x3,x2,#0xFFFFFF
    ubfx x4,x2,#32,#8
    bfi  x3, x4, #32, #8  // Aff3->[39:32]; IRM[31]=0 (specific PE, IHI0069 p580)
    str x3,[x0,#SPI_IROUTER_OFF(SPI_INTID)]
    mov  w1,#0x40
    strb w1,[x0,#SPI_IPRIORITYR_OFF(SPI_INTID)]
    mov  w1,#SPI_BIT(SPI_INTID)
    str w1,[x0,#SPI_ISENABLER_OFF(SPI_INTID)]
    mov  x0,#0xFF
    msr ICC_PMR_EL1,x0
    isb
    bl   wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr  x0,=core_sync1
    bl core_synchronisation
    mrs  x3, ICC_IAR1_EL1
    msr ICC_EOIR1_EL1, x3
    mov  w2,#SPI_INTID
    cmp w3,w2
    b.ne spi_fail
    bl   report_pass
spi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
