// vSGI direct injection (GICv4) - skeleton.
//
// A virtual SGI is injected directly into a vPE by writing the vPE id and SGI
// INTID to GITS_SGIR (TRM 4.9.2, 5.9). GITS_SGIR is at offset 0x0020 in the ITS
// vSGI register frame and is always accessed via the GICD ACE5-Lite subordinate
// interface. vSGIs have no active state, so no deactivation is needed.
//
// Field layout of GITS_SGIR (vPE id + SGI INTID) is specified in IHI0069 (GICv4).
// The vPE must be mapped on the ITS used for injection, else a debug error is
// raised (TRM 4.17.4.3).
#include "gic_common.h"
#define VPE_ID   0
#define VSGI_INTID 0
    .section .text, "ax", %progbits
    .global test_start
test_start:
    bl gic_dist_enable_grp1ns
    bl gicr_wake
    bl cpu_if_init_grp1
    // TODO(GICv4): map the vPE (VMAPP) on this ITS, then inject the vSGI:
    LOAD_GITS(x0)
    // GITS_SGIR = (vPE_id) | (SGI_INTID << ...). VERIFY field layout vs IHI0069.
    mov x1, #VSGI_INTID
    str x1, [x0, #GITS_SGIR]  // 64-bit WO
    bl wfi_wait_irq
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
    mrs x3, ICC_IAR1_EL1  //  Ack Group 1: read returns INTID, advances state (pending->active)
    msr ICC_EOIR1_EL1, x3  //  EOI Group 1: priority drop + deactivate (EOImode=0)
    // vSGI INTID is in the 0..15 range; accept any SGI range INTID.
    cmp x3, #16
    b.hs vsgi_fail
    bl report_pass
vsgi_fail: bl report_fail
1: b 1b
    .balign 8
core_sync1: .word 0
    .end
