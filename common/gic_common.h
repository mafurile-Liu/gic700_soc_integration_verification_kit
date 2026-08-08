/******************************************************************************
 * File:      gic_common.h
 * Purpose:   GIC-700 common API declarations + SoC base addresses.
 *            Include this from every test. The API is in gic_common.S.
 *            After this layer, a typical testcase is ~20 lines.
 *
 * Framework: EL3 boot (bootcode.s provides boot + vector + end_test).
 *            Tests run at EL3 (Secure). SCR_EL3.IRQ=1,FIQ=1 (bootcode sets).
 *            Vector labels: curr_el_spx_irq_vector / curr_el_spx_fiq_vector.
 *            Result: end_test (writes pass/fail message to tube 0x274F0500).
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
.equ GITS_BASE, (GICD_BASE + 0x40000)    // ITS Control frame = GICD page 4
#endif
.equ GICR_SGI_BASE, (GICR_RD_BASE + 0x10000)
.equ GICR_VLPI_BASE, (GICR_RD_BASE + 0x20000)

/* ---- Common PPI INTIDs (confirm vs Cortex-A720 TRM / SoC wiring) ---- */
#define PPI_CNTV   27
#define PPI_CNTP    30
#define PPI_CNTPS   29
#define PPI_CNTHP   26

/* ---- Testbench mailbox (tube region 0x274F0500+, backdoor poll) ---- */
.equ TB_BASE, 0x274F0500
#ifndef TB_READY_ADDR
.equ TB_READY_ADDR, (TB_BASE + 0x40)
#endif
#ifndef TB_RESULT_ADDR
.equ TB_RESULT_ADDR, (TB_BASE + 0x44)
#endif
.equ TB_EXPECTED_INTID_ADDR, (TB_BASE + 0x48)

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

/* Result: end_test writes pass/fail message to tube (0x274F0500).     */
/*   test_pass(void); test_fail(void);                                  */

/* ---- LPI / ITS API (all in gic_common.S) ---- */
/*
 * its_init(void)
 *   Set GITS_CBASER (cmd queue), GITS_BASER0 (device), GITS_BASER1 (collection),
 *   then set GITS_CTLR bit[0]=Enabled. Call after gic_init_*.
 * its_add_command(void) [internal]
 *   Copy 32-byte its_cmd_buf to queue, advance CWRITER, poll CREADR==CWRITER.
 * its_mapd(x0=device_id, x1=itt_addr, x2=id_bits)
 *   MAPD: map DeviceID to ITT table. id_bits = EventID width (encoded as id_bits-1).
 * its_mapc(x0=target_rd_procnum, x1=collection_id)
 *   MAPC: map Collection ID to target Redistributor (PTA=0: use Processor_Number).
 * its_mapti(x0=device_id, x1=event_id, x2=intid, x3=collection_id)
 *   MAPTI: map EventID to specific pINTID + Collection.
 * its_mapi(x0=device_id, x1=event_id, x2=collection_id)
 *   MAPI: map EventID to Collection (pINTID = EventID, no separate ITT entry).
 * its_int(x0=device_id, x1=event_id)
 *   INT: software-trigger LPI via ITS command (alternative to GITS_TRANSLATER write).
 * its_inv(x0=device_id, x1=event_id)
 *   INV: invalidate cached LPI config for this DeviceID/EventID.
 * its_invall(x0=collection_id)
 *   INVALL: invalidate all cached LPI configs in a Collection.
 * its_sync(x0=target_rd_procnum)
 * its_movi(x0=device_id, x1=event_id, x2=new_collection_id)
 *   MOVI: move an LPI from one Collection to another.
 * its_clear(x0=device_id, x1=event_id)
 *   CLEAR: clear pending state of an LPI (via ITS command).
 * its_movall(x0=src_rd_procnum, x1=dst_rd_procnum)
 *   MOVALL: move all pending LPIs from source RD to destination RD.
 * its_discard(x0=device_id, x1=event_id)
 *   DISCARD: clear pending + remove ITT entry for an LPI.
 *   SYNC: ensure all outstanding ITS ops for target RD are complete.
 * lpi_set_tables(x0=prop_addr, x1=pend_addr, x2=id_bits)
 *   Write GICR_PROPBASER (config table) + GICR_PENDBASER (pending table).
 *   id_bits >= 14 (LPI starts at 8192). Cache attrs = Device-nGnRnE.
 * lpi_enable(void)
 *   Set GICR_CTLR bit[0]=EnableLPIs, poll GICR_CTLR bit[3]=RWP until 0.
 * lpi_config(x0=intid, x1=enable, x2=priority)
 *   Write 1-byte entry in LPI Configuration Table: byte = (prio & 0xFC) | (enable & 1).
 *   Table base = LPI_PROP_TABLE_ADDR. intid must be >= 8192.
 * lpi_trigger(x0=event_id)
 *   Write EventID to GITS_TRANSLATER (hardware-style LPI injection).
 * gicr_find_rd(void) -> x0 = matching RD_base address
 *   Scan GICR_TYPER across RD frames to find the one whose Affinity[63:32]
 *   matches this PE's MPIDR. Returns 0xFFFFFFFF if not found.
 * gicr_get_procnum(void) -> x0 = Processor_Number (for ITS commands when PTA=0)
 *   Read GICR_TYPER[23:8] of the current PE's Redistributor.
 * gic_fiq_handler_lpi(void)
 *   LPI-specific FIQ handler: IAR0 may return 1020/1021 (Group 1 pending),
 *   then read IAR1 for actual LPI INTID, EOI1, compare expected, pass/fail.
 *
 * ---- vLPI / vSGI API (GICv4.1, all in gic_common.S) ---- */
/*
 * vlpi_set_vpe_table(x0=vpe_conf_addr, x1=num_pages)
 *   Write GICR_VPROPBASER (vPE Config Table base, in vLPI frame).
 * vlpi_make_resident(x0=vpeid)
 *   Write GICR_VPENDBASER: Valid=1, vPEID=vpeid. Makes vPE resident on this RD.
 * vlpi_config(x0=intid, x1=enable, x2=priority)
 *   Write 1-byte vLPI config entry: byte = (prio & 0xFC) | (enable & 1).
 * its_vmapp(x0=vpeid, x1=target_rd_procnum, x2=conf_addr, x3=pend_addr)
 *   VMAPP: map vPEID to target RD + vPE config/pending tables.
 * its_vmapti(x0=device_id, x1=event_id, x2=vpeid, x3=vintid)
 *   VMAPTI: map DeviceID/EventID to vPEID + vINTID (doorbell=1023).
 * its_vsync(x0=vpeid)
 *   VSYNC: sync virtual interrupt ops for vPEID.
 * its_invdb(x0=vpeid)
 * its_vmovi(x0=device_id, x1=event_id, x2=dst_vpeid)
 *   VMOVI: move a vLPI to a different vPE.
 * its_vmovp(x0=vpeid, x1=dst_rd_procnum)
 *   VMOVP: move a vPE to a different RD.
 * its_vmapi(x0=device_id, x1=event_id, x2=vpeid)
 *   VMAPI: map EventID to vPEID (vINTID = EventID).
 * its_vinvall(void)
 *   VINVALL: invalidate all vPE configs on this ITS.
 *   INVDB: invalidate vPE config cache for vPEID.
 * its_vsgi(x0=vpeid, x1=vintid, x2=enable, x3=priority, x4=group)
 *   VSGI: configure virtual SGI (enable/priority/group) via ITS command.
 * vsgi_send(x0=vintid, x1=vpeid)
 *   Write GITS_SGIR to inject a vSGI. Format: [31:0]=vINTID, [47:32]=vPEID.
 */

/* Low-level + compat (gic_dist_enable_*, gicr_wake, cpu_if_init_*,    */
/*   wfi_wait_*, report_pass/fail, gic_wait_rwp_gicr)                  */

#endif
