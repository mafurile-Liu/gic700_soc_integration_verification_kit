// vLPI basic delivery (GICv4 virtual LPI) - skeleton.
//
// Virtual LPIs target a vPE (virtual Processing Element) instead of a physical PE.
// Flow (TRM 4.13, 5.6 vLPI registers):
//   - Map a vPE: VMAPP command (vPE -> vPE config table + vPE translation).
//   - Configure the vPE on a Redistributor: GICR_VFCTLR, GICR_VCFGBASER
//     (vICM final vPE CFG attribute), GICR_VINVCHIPR (vPE invalidate chip).
//   - Issue VMOVP to move the vPE to the target ITS.
//   - Inject the vLPI: write GITS_TRANSLATER with the vPE context (virtual),
//     or use the GIC Stream for vLPI set.
//   - The guest acks via the virtual CPU interface (ICH_* registers).
//
// vLPIs have no active state (like LPI). This file is a structured skeleton; the
// VMAPP/VMOVP command encodings and vPE table layout follow IHI0069 (GICv4) and
// TRM 4.13.2/5.6.
#include "gic_common.h"
#define VPE_ID 0
#define VLPI_INTID (INTID_FIRST_LPI + 0)
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1
    // TODO(GICv4): physical LPI bring-up (see lpi_basic.S) + vPE setup:
    //   - GICR_VCFGBASER: vPE config table base (TRM 5.6.2)
    //   - GICR_VFCTLR: virtual function control (TRM 5.6.1)
    //   - VMAPP command (map vPE) + VMOVP (move vPE to ITS)
    //   - vLPI injection via GITS_TRANSLATER (virtual context)
    //   - guest ack via ICH_LR/ICH_APR (virtual CPU interface)
    bl wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
    mrs x3, ICC_IAR1_EL1  //  Ack Group 1: read returns INTID, advances state (pending->active)
    msr ICC_EOIR1_EL1, x3  //  EOI Group 1: priority drop + deactivate (EOImode=0)
    mov x2, #VLPI_INTID
    cmp x3, x2
    b.ne vlpi_fail
    bl report_pass
vlpi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
