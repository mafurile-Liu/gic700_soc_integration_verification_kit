/******************************************************************************
 * File:      gic_common.h
 * Purpose:   GIC-700 common API declarations + SoC base addresses.
 *            Include this from every test. The API is in gic_common.S.
 *            After this layer, a typical testcase is ~20 lines.
 *
 * Framework: EL3 boot (bootcode.s provides boot + vector + end_test).
 *            Tests run at EL3 (Secure). SCR_EL3.IRQ=1,FIQ=1 (bootcode sets).
 *            Vector labels: curr_el_spx_irq_vector / curr_el_spx_fiq_vector.
 *            Result: end_test (writes pass/fail message to tube 0x13000000).
 *            TB sync: TB_READY_ADDR (PE->TB, ready for injection),
 *                     TB_RESULT_ADDR (PE->TB, per-INTID result for scan).
 ******************************************************************************/
#ifndef GIC_COMMON_H
#define GIC_COMMON_H

#include "gic_reg.h"
#include "gic_macros.h"

/* ---- SoC base addresses (override with -D on cmd line) ---- */
#ifndef GICD_BASE
.equ GICD_BASE, 0x100FF000
#endif
#ifndef GICR_RD_BASE
.equ GICR_RD_BASE, 0x10800000
#endif
#ifndef GITS_BASE
.equ GITS_BASE, 0x00000000
#endif
.equ GICR_SGI_BASE, (GICR_RD_BASE + 0x10000)

/* ---- Common PPI INTIDs (confirm vs Cortex-A720 TRM / SoC wiring) ---- */
#define PPI_CNTV   27
#define PPI_CNTP    30
#define PPI_CNTPS   29
#define PPI_CNTHP   26

/* ---- Testbench mailbox (tube region 0x13000000+, backdoor poll) ---- */
#ifndef TB_READY_ADDR
.equ TB_READY_ADDR, 0x13000040
#endif
#ifndef TB_RESULT_ADDR
.equ TB_RESULT_ADDR, 0x13000044
#endif

/* ---- API (args in x0-x7, AAPCS). All in gic_common.S ---- */

/* Bring-up (one call = GICD enable group + GICR wake + CPU interface) */
/*   void gic_init_grp1ns(void);  void gic_init_grp0(void);            */
/*   void gic_init_grp1s(void);                                        */

/* PPI/SGI config (x0=intid 0..31), GICR SGI_base frame */
/*   ppi_set_group_ns(x0) ppi_set_group0(x0) ppi_set_group_1s(x0)      */
/*   ppi_set_prio(x0,x1) ppi_set_level(x0) ppi_set_edge(x0)            */
/*   ppi_enable(x0) ppi_set_pend(x0) ppi_clr_pend(x0)                  */
/*   ppi_config_ns(x0) ppi_config_grp0(x0) ppi_config_1s(x0)           */

/* SPI config (x0=intid >=32), GICD. bank/bit computed at runtime.     */
/*   spi_set_group_ns(x0) spi_set_group0(x0) spi_set_group_1s(x0)      */
/*   spi_set_prio(x0,x1) spi_set_level(x0) spi_set_edge(x0)            */
/*   spi_enable(x0) spi_route_self(x0) spi_set_pend(x0)                */
/*   spi_config_ns(x0) spi_config_grp0(x0) spi_config_1s(x0)           */

/* Ack / EOI */
/*   gic_ack_grp1(void)->x0=INTID  gic_ack_grp0(void)->x0=INTID        */
/*   gic_eoi_grp1(x0)  gic_eoi_grp0(x0)                                */

/* Wait */
/*   gic_wait_irq_clear(void)  gic_wait_fiq_clear(void)                */

/* Default vector handlers (ack+eoi+core_sync+check+end_test):         */
/*   curr_el_spx_irq_vector: b gic_irq_handler_grp1  (Secure Grp1->IRQ)*/
/*   curr_el_spx_fiq_vector: b gic_fiq_handler_grp0  (Group0->FIQ,IAR0)*/
/*   curr_el_spx_fiq_vector: b gic_fiq_handler_grp1ns(NS Grp1->FIQ,   */
/*                                                     aliased, IAR1)   */
/*   extern uint64_t gic_expected_intid;  (test stores expected INTID) */

/* Result: end_test writes pass/fail message to tube (0x13000000).     */
/*   test_pass(void); test_fail(void);                                  */

/* Low-level + compat (gic_dist_enable_*, gicr_wake, cpu_if_init_*,    */
/*   wfi_wait_*, report_pass/fail, gic_wait_rwp_gicr)                  */

#endif
