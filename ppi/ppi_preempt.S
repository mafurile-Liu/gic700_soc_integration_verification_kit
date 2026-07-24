// PPI preemption (Non-secure Group 1).
// PPI_LO (INTID 27, prio 0x80) is taken first; inside its handler we unmask IRQ
// and inject PPI_HI (INTID 30, prio 0x40, higher) via GICR_ISPENDR0, so PPI_HI
// preempts PPI_LO. Verifies nested IAR order (HI then LO), both EOIR'd, and that
// preemption actually occurred (HI handler ran before LO's EOIR).
// BPR1=0 so any priority difference allows preemption (TRM 4.8.5).
// For testbench-force PPI, force PPI_HI during the LO handler window instead of
// the ISPENDR0 self-injection used here.
#include "gic_common.h"
#define PPI_LO 27
#define PPI_HI 30
#define LO_BIT (1 << PPI_LO)
#define HI_BIT (1 << PPI_HI)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl   gic_dist_enable_grp1ns
    bl   gicr_wake
    bl   cpu_if_init_grp1
    msr  ICC_BPR1_EL1, xzr           // BPR=0: full group priority, allow preempt
    LOAD_GICR(x0)
    add  x5, x0, #0x10000            // SGI_base
    mov  w2, #LO_BIT
    orr  w2, w2, #HI_BIT             // LO|HI bits
    ldr  w1, [x5, #GICR_IGROUPR0]
    orr  w1, w1, w2
    str  w1, [x5, #GICR_IGROUPR0]
    ldr  w1, [x5, #GICR_IGRPMODR0]
    bic  w1, w1, w2
    str  w1, [x5, #GICR_IGRPMODR0]
    mov  w1, #0x80
    strb w1, [x5, #(GICR_IPRIORITYRn + PPI_LO)]
    mov  w1, #0x40
    strb w1, [x5, #(GICR_IPRIORITYRn + PPI_HI)]
    ldr  w1, [x5, #GICR_ICFGR1]
    bic  w1, w1, #(3 << ICFGR_PPI_SHIFT(PPI_LO))
    bic  w1, w1, #(3 << ICFGR_PPI_SHIFT(PPI_HI))
    str  w1, [x5, #GICR_ICFGR1]
    mov  w1, w2
    str  w1, [x5, #GICR_ISENABLER0]
    adr  x1, preempt_seen
    str  xzr, [x1]                   // clear seen flag
    mov  w1, #LO_BIT
    str  w1, [x5, #GICR_ISPENDR0]    // inject LO
    bl   wfi_wait_irq                // unmask IRQ, WFI -> LO taken
1:  b    1b

    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    mrs  x3, ICC_IAR1_EL1            // x3 = taken INTID
    cmp  x3, #PPI_HI
    b.eq ppi_hi
    // ---- LO handler ----
    adr  x1, preempt_lo_id
    str  x3, [x1]                    // save LO INTID to memory (survives nesting)
    msr  daifclr, #2                 // unmask IRQ so HI can preempt
    LOAD_GICR(x10)
    add  x10, x10, #0x10000
    mov  w11, #HI_BIT
    str  w11, [x10, #GICR_ISPENDR0]  // inject HI -> preempts
    dsb  sy
2:  adr  x1, preempt_seen
    ldr  x2, [x1]
    cmp  x2, #1
    b.ne 2b                          // spin until HI handler ran
    adr  x1, preempt_lo_id
    ldr  x3, [x1]                    // reload LO INTID
    msr  ICC_EOIR1_EL1, x3           // deactivate LO
    cmp  x3, #PPI_LO
    b.ne ppi_preempt_fail
    bl   report_pass
ppi_preempt_fail:
    bl   report_fail
3:  b    3b

ppi_hi:
    adr  x1, preempt_seen
    mov  x2, #1
    str  x2, [x1]                    // mark HI ran
    msr  ICC_EOIR1_EL1, x3           // deactivate HI (x3 = HI INTID)
    eret                             // return to LO handler

    .balign 8
preempt_seen:  .word 0
    .word 0
preempt_lo_id: .quad 0
    .end
