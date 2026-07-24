/******************************************************************************
 * File: gic_common.h
 * Purpose: GIC-700 common API declarations + SoC base addresses.
 *          Include this from every test. The API is in gic_common.S.
 *          After this layer, a typical testcase is ~20 lines.
 ******************************************************************************/
#ifndef GIC_COMMON_H
#define GIC_COMMON_H

#include "gic_reg.h"
#include "gic_macros.h"

/* ---- SoC base addresses (override with -DGICD_BASE=... on the cmd line) ---- */
#ifndef GICD_BASE
.equ GICD_BASE, 0x00000000

/* ---- Common PPI INTIDs (confirm vs Cortex-A720 TRM / SoC wiring) ---- */
#define PPI_CNTV   27
#define PPI_CNTP    30
#define PPI_CNTPS   29
#define PPI_CNTHP   26

/* ---- Testbench mailbox addresses (memory-mapped, for interrupt injection sync + result) ---- */
#ifndef TB_READY_ADDR
.equ TB_READY_ADDR, 0x10000000
#endif
#ifndef TB_RESULT_ADDR
.equ TB_RESULT_ADDR, 0x10000004
#endif

#endif
#ifndef GICR_RD_BASE
.equ GICR_RD_BASE, 0x00000000

/* ---- Common PPI INTIDs (confirm vs Cortex-A720 TRM / SoC wiring) ---- */
#define PPI_CNTV   27
#define PPI_CNTP    30
#define PPI_CNTPS   29
#define PPI_CNTHP   26

#endif
#ifndef GITS_BASE
.equ GITS_BASE, 0x00000000

/* ---- Common PPI INTIDs (confirm vs Cortex-A720 TRM / SoC wiring) ---- */
#define PPI_CNTV   27
#define PPI_CNTP    30
#define PPI_CNTPS   29
#define PPI_CNTHP   26

#endif
.equ GICR_SGI_BASE, (GICR_RD_BASE + 0x10000)

/* ---- API (args in x0-x7, AAPCS). All in gic_common.S ---- */

/* Bring-up (one call = GICD enable group + GICR wake + CPU interface) */
/*   void gic_init_grp1ns(void);  void gic_init_grp0(void);            */

/* PPI/SGI config (x0=intid 0..31), GICR SGI_base frame */
/*   ppi_set_group_ns(x0) ppi_set_group0(x0) ppi_set_prio(x0,x1)       */
/*   ppi_set_level(x0) ppi_set_edge(x0) ppi_enable(x0)                 */
/*   ppi_set_pend(x0) ppi_clr_pend(x0)                                 */
/*   ppi_config_ns(x0)  = group NS + prio 0x80 + level + enable        */
/*   ppi_config_grp0(x0)                                               */

/* SPI config (x0=intid >=32), GICD. bank/bit computed at runtime.     */
/*   spi_set_group_ns(x0) spi_set_group0(x0) spi_set_prio(x0,x1)       */
/*   spi_set_level(x0) spi_set_edge(x0) spi_enable(x0)                 */
/*   spi_route_self(x0) spi_set_pend(x0)                               */
/*   spi_config_ns(x0)  = group NS + prio 0x80 + level + route + enable*/
/*   spi_config_grp0(x0)                                               */

/* Ack / EOI */
/*   gic_ack_grp1(void)->x0=INTID  gic_ack_grp0(void)->x0=INTID        */
/*   gic_eoi_grp1(x0)  gic_eoi_grp0(x0)                                */

/* Wait */
/*   gic_wait_irq_clear(void)  gic_wait_fiq_clear(void)                */

/* Default vector handler: ack+eoi+check gic_expected_intid+pass/fail  */
/*   test does:  irq_handler: b gic_irq_handler_grp1                   */
/*   void gic_irq_handler_grp1(void); gic_irq_handler_grp0(void);      */
/*   extern uint64_t gic_expected_intid;  (test stores expected INTID) */

/* Result (simulator reads x0: 0=pass, 1=fail) */
/*   test_pass(void); test_fail(void);                                  */


/* ---- Common PPI INTIDs (confirm vs Cortex-A720 TRM / SoC wiring) ---- */
#define PPI_CNTV   27
#define PPI_CNTP    30
#define PPI_CNTPS   29
#define PPI_CNTHP   26

#endif
