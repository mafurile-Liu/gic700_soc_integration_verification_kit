// SPI level-sensitive (Non-secure Group 1). Testbench holds active, de-asserts
// after IAR before EOIR.
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
    mov  w1,#PRIO_DEFAULT
    strb w1,[x0,#SPI_IPRIORITYR_OFF(SPI_INTID)]
    mrs  x2,mpidr_el1
    and x3,x2,#0xFFFFFF
    ubfx x4,x2,#32,#8
    orr x3,x3,x4,lsl #24
    str x3,[x0,#SPI_IROUTER_OFF(SPI_INTID)]
    mov  w1,#SPI_BIT(SPI_INTID)
    str w1,[x0,#SPI_ISENABLER_OFF(SPI_INTID)]
    bl   wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr  x0,=core_sync1
    bl core_synchronisation
    mrs  x3, ICC_IAR1_EL1
    msr  ICC_EOIR1_EL1, x3           // TESTBENCH: de-assert SPI before this
    mov  w2,#SPI_INTID
    cmp w3,w2
    b.ne spi_fail
1:  mrs  x21,isr_el1
tbnz x21,#7,1b
    bl   report_pass
spi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
