/******************************************************************************
 * File:      vlpi_basic.S
 * Purpose:   Virtual LPI (GICv4.1) delivery test. Full flow:
 *              1) GIC init (NS Group 1 + Group 0)
 *              2) Physical LPI tables + enable (doorbell support)
 *              3) vPE table (GICR_VPROPBASER) + make resident (GICR_VPENDBASER)
 *              4) ITS init + vPE table (GITS_BASER2)
 *              5) ITS commands: VMAPP -> INVDB -> VMAPTI -> VSYNC
 *              6) Configure vLPI (enable + priority in vPE config table)
 *              7) INV + INT (trigger)
 *              8) WFI -> FIQ handler (same 1020/1021 flow as physical LPI)
 *
 *            Reference: Arm AArch64_GIC_v3_v4_example main_vlpi.c.
 *            Spec: IHI0069 ch7/8, TRM 4.13/5.6.
 *
 * Note:      vLPIs require the vPE to be "resident" on the Redistributor
 *            (GICR_VPENDBASER.Valid=1). The vPE Config Table (pointed to by
 *            GICR_VPROPBASER) holds the vLPI enable/priority entries, same
 *            1-byte format as physical LPIs.
 ******************************************************************************/
#include "gic_common.h"

.equ VLPI_INTID, 8192          /* vLPI INTID (>= 8192) */
.equ DEV_ID,     0
.equ EVT_ID,     0
.equ VPE_ID,     0             /* vPEID for this test */
.equ ID_BITS,    2

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_fiq_vector

test_start:
        /* ---- 1) GIC bring-up: NS Group 1 + Group 0 ---- */
        bl      gic_init_grp1ns
        mov     x0,#1
        msr     ICC_IGRPEN0_EL1,x0
        ldr     x0,=GICD_BASE
        ldr     w1,[x0,#GICD_CTLR]
        orr     w1,w1,#GICD_CTLR_EnableGrp0
        str     w1,[x0,#GICD_CTLR]
1:      ldr     w1,[x0,#GICD_CTLR]
        tbnz    w1,#31,1b
        isb

        /* ---- 2) Physical LPI tables + enable (needed for doorbell) ---- */
        ldr     x0,=LPI_PROP_TABLE_ADDR
        ldr     x1,=LPI_PEND_TABLE_ADDR
        mov     x2,#15
        bl      lpi_set_tables
        bl      lpi_enable

        /* ---- 3) vPE table: GICR_VPROPBASER + make resident ---- */
        ldr     x0,=VLPE_CONF_TABLE_ADDR
        mov     x1,#1                           /* 1 page */
        bl      vlpi_set_vpe_table
        mov     x0,#VPE_ID
        bl      vlpi_make_resident              /* GICR_VPENDBASER: Valid=1, vPEID=0 */

        /* ---- 4) ITS init (also sets GITS_BASER2 for vPE table) ---- */
        bl      its_init
        /* Set GITS_BASER2: vPE table (GICv4) */
        ldr     x9,=GITS_BASE
        ldr     x0,=ITS_VPE_TABLE_ADDR
        and     x0,x0,#0x0000FFFFFFFFF000
        mov     x1,#0                           /* 1 page - 1 = 0 */
        orr     x0,x0,x1
        mov     x1,#1
        lsl     x1,x1,#63                       /* Valid */
        orr     x0,x0,x1
        str     x0,[x9,#GITS_BASER2]

        /* ---- 5) ITS commands: VMAPP -> INVDB -> VMAPTI -> VSYNC ---- */
        bl      gicr_get_procnum
        mov     x4,x0                           /* save procnum */
        /* VMAPP: map vPEID 0 to this RD, with vPE config/pending tables */
        mov     x0,#VPE_ID
        mov     x1,x4                           /* target = procnum */
        ldr     x2,=VLPE_CONF_TABLE_ADDR
        ldr     x3,=VLPE_PEND_TABLE_ADDR
        bl      its_vmapp
        /* INVDB: invalidate vPE config cache for vPEID 0 */
        mov     x0,#VPE_ID
        bl      its_invdb
        /* VMAPTI: map DeviceID 0 / EventID 0 -> vPEID 0 / vINTID 8192 */
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        mov     x2,#VPE_ID
        mov     x3,#VLPI_INTID
        bl      its_vmapti
        /* VSYNC: sync virtual interrupt ops for vPEID 0 */
        mov     x0,#VPE_ID
        bl      its_vsync

        /* ---- 6) Configure vLPI 8192: enable, priority 0 ---- */
        mov     x0,#VLPI_INTID
        mov     x1,#1
        mov     x2,#0
        bl      vlpi_config

        /* ---- 7) INV + INT: trigger vLPI ---- */
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        bl      its_inv
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        bl      its_int

        /* ---- 8) Set expected INTID + WFI ---- */
        ldr     x1,=gic_expected_intid
        mov     x2,#VLPI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#3
        bl      tb_notify_ready

wait_loop:
        wfi
        b       wait_loop

curr_el_spx_fiq_vector:
        b       gic_fiq_handler_lpi
