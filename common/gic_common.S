// gic_common.S - shared GIC-700 helper subroutines.
// Build: aarch64-none-elf-gcc -c gic_common.S -Icommon
#include "gic_common.h"
    .section .text, "ax", %progbits

    .global gic_dist_enable_grp1ns
gic_dist_enable_grp1ns:
    LOAD_GICD(x0)
    ldr w1, [x0, #GICD_CTLR]  //  GICD Control: [0]EnGrp0(FIQ) [1]EnGrp1NS [2]EnGrp1S [31]RWP; ARE fixed=1 in GIC-700
    orr w1, w1, #GICD_CTLR_EnableGrp1NS
    str w1, [x0, #GICD_CTLR]  //  GICD Control: [0]EnGrp0(FIQ) [1]EnGrp1NS [2]EnGrp1S [31]RWP; ARE fixed=1 in GIC-700
1:  ldr  w1, [x0, #GICD_CTLR]
    tbnz w1, #31, 1b
    ret

    .global gic_dist_enable_grp1s
gic_dist_enable_grp1s:
    LOAD_GICD(x0)
    ldr w1, [x0, #GICD_CTLR]  //  GICD Control: [0]EnGrp0(FIQ) [1]EnGrp1NS [2]EnGrp1S [31]RWP; ARE fixed=1 in GIC-700
    orr w1, w1, #GICD_CTLR_EnableGrp1S
    str w1, [x0, #GICD_CTLR]  //  GICD Control: [0]EnGrp0(FIQ) [1]EnGrp1NS [2]EnGrp1S [31]RWP; ARE fixed=1 in GIC-700
1:  ldr  w1, [x0, #GICD_CTLR]
    tbnz w1, #31, 1b
    ret

    .global gic_dist_enable_grp0
gic_dist_enable_grp0:
    LOAD_GICD(x0)
    ldr w1, [x0, #GICD_CTLR]  //  GICD Control: [0]EnGrp0(FIQ) [1]EnGrp1NS [2]EnGrp1S [31]RWP; ARE fixed=1 in GIC-700
    orr w1, w1, #GICD_CTLR_EnableGrp0
    str w1, [x0, #GICD_CTLR]  //  GICD Control: [0]EnGrp0(FIQ) [1]EnGrp1NS [2]EnGrp1S [31]RWP; ARE fixed=1 in GIC-700
1:  ldr  w1, [x0, #GICD_CTLR]
    tbnz w1, #31, 1b
    ret

    .global gicr_wake
gicr_wake:
    LOAD_GICR(x0)
    ldr w1, [x0, #GICR_WAKER]  //  GICR Wake: [1]ProcessorSleep(0=awake) [2]ChildrenAsleep(RO, poll until 0)
    bic w1, w1, #GICR_WAKER_ProcessorSleep
    str w1, [x0, #GICR_WAKER]  //  GICR Wake: [1]ProcessorSleep(0=awake) [2]ChildrenAsleep(RO, poll until 0)
1:  ldr  w1, [x0, #GICR_WAKER]
    tbnz w1, #2, 1b
    ret

    .global gic_wait_rwp_gicr
gic_wait_rwp_gicr:
    LOAD_GICR(x0)
1:  ldr  w1, [x0, #GICR_CTLR]
    tbnz w1, #3, 1b
    ret

    .global cpu_if_init_grp1
cpu_if_init_grp1:
    mrs x0, ICC_SRE_EL1  //  System-reg access enable: [0]SRE=1 enables ICC_*_EL1 use
    orr x0, x0, #1
    msr ICC_SRE_EL1, x0  //  System-reg access enable: [0]SRE=1 enables ICC_*_EL1 use
    mov x0, #0xFF
    msr ICC_PMR_EL1, x0  //  Priority Mask: only interrupts with prio < PMR are signaled; 0xFF = allow all
    mov x0, #1
    msr ICC_IGRPEN1_EL1, x0  //  Group 1 signaling enable: [0]=1 (current security state)
    isb  //  Instruction Synchronization Barrier
    ret

    .global cpu_if_init_grp0
cpu_if_init_grp0:
    mrs x0, ICC_SRE_EL1  //  System-reg access enable: [0]SRE=1 enables ICC_*_EL1 use
    orr x0, x0, #1
    msr ICC_SRE_EL1, x0  //  System-reg access enable: [0]SRE=1 enables ICC_*_EL1 use
    mov x0, #0xFF
    msr ICC_PMR_EL1, x0  //  Priority Mask: only interrupts with prio < PMR are signaled; 0xFF = allow all
    mov x0, #1
    msr ICC_IGRPEN0_EL1, x0  //  Group 0 signaling enable: [0]=1
    isb  //  Instruction Synchronization Barrier
    ret

    .global wfi_wait_irq
wfi_wait_irq:
    dsb sy  //  Data Synchronization Barrier (make GIC writes visible)
    msr daifclr, #2  //  unmask IRQ (clear PSTATE.I)
1:  wfi
    b 1b

    .global wfi_wait_fiq
wfi_wait_fiq:
    dsb sy  //  Data Synchronization Barrier (make GIC writes visible)
    msr daifclr, #1  //  unmask FIQ (clear PSTATE.F)
1:  wfi
    b 1b

    .global report_pass
report_pass:
    ldr x1, =gic_pass_msg
    bl end_test
1:  b    1b

    .global report_fail
report_fail:
    ldr x1, =gic_fail_msg
    bl end_test
1:  b    1b

    .section .rodata
gic_pass_msg: .asciz "** GIC TEST PASSED OK **\n"
gic_fail_msg: .asciz "** GIC TEST FAILED **\n"
