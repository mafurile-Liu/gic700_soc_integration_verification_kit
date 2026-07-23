// gic_common.h - shared config + helper declarations. Include from every test .S.
#ifndef GIC_COMMON_H
#define GIC_COMMON_H
#include "gic_reg.h"
#include "gic_macros.h"

// TODO: fill from ZJ100 address map (gic700 = 7168KB in CPU cmn region).
// Multi-PE: each PE uses its OWN GICR_RD_BASE.
#ifndef GICD_BASE
#define GICD_BASE     0x00000000
#endif
#ifndef GICR_RD_BASE
#define GICR_RD_BASE  0x00000000
#endif
#ifndef GITS_BASE
#define GITS_BASE     0x00000000
#endif
#define GICR_SGI_BASE (GICR_RD_BASE + 0x10000)
#ifndef TB_MAILBOX
#define TB_MAILBOX    0x13000000
#endif

// PPI INTIDs (confirm vs Cortex-A720 TRM / ZJ100 wiring)
#define PPI_CNTV   27
#define PPI_CNTP   30
#define PPI_CNTPS  29
#define PPI_CNTHP  26

// Helpers in gic_common.S (AAPCS: args x0-x7, no callee saves):
//  gic_dist_enable_grp1ns/grp1s/grp0, gicr_wake, gic_wait_rwp_gicr,
//  cpu_if_init_grp1/grp0, wfi_wait_irq/fiq, report_pass, report_fail.
// Framework externals: core_synchronisation(u32*), end_test(const char*),
// extern u32 exec_pe_var.
#endif
