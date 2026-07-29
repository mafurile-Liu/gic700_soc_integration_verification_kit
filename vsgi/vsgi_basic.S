/******************************************************************************
 * File:      vsgi_basic.S
 * Purpose:   Virtual SGI (GICv4.1) injection test. Full flow:
 *              1) GIC init (NS Group 1 + Group 0)
 *              2) Physical LPI tables + enable (doorbell support)
 *              3) vPE table (GICR_VPROPBASER) + make resident (GICR_VPENDBASER)
 *              4) ITS init + GITS_BASER2 (vPE table)
 *              5) ITS commands: VMAPP -> INVDB -> VSYNC
 *              6) VSGI command: configure vSGI 0 (enable, priority, group)
 *              7) Inject vSGI via GITS_SGIR register write
 *              8) WFI -> FIQ handler
 *
 *            Reference: Arm AArch64_GIC_v3_v4_example main_vsgi.c.
 *            Spec: IHI0069 ch8, TRM 4.9.2.
 *
 * Note:      vSGIs are virtual SGIs delivered via the ITS. The VSGI ITS
 *            command configures the vSGI (enable/priority/group), and the
 *            GITS_SGIR register write (at ITS_BASE + 0x20020) injects it.
 *            Format: GITS_SGIR[31:0] = vINTID, [47:32] = vPEID.
 ******************************************************************************/
#include "gic_common.h"

.equ VSGI_INTID, 0             /* vSGI INTID (0-15, like physical SGIs) */
.equ VPE_ID,    0
.equ VSGI_PRIO, 0              /* priority 0 (highest) */
.equ VSGI_GRP,  1              /* group 1 (NS Group 1) */

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

        /* ---- 2) Physical LPI tables + enable ---- */
        ldr     x0,=LPI_PROP_TABLE_ADDR
        ldr     x1,=LPI_PEND_TABLE_ADDR
        mov     x2,#15
        bl      lpi_set_tables
        bl      lpi_enable

        /* ---- 3) vPE table + make resident ---- */
        ldr     x0,=VLPE_CONF_TABLE_ADDR
        mov     x1,#1
        bl      vlpi_set_vpe_table
        mov     x0,#VPE_ID
        bl      vlpi_make_resident

        /* ---- 4) ITS init + GITS_BASER2 ---- */
        bl      its_init
        ldr     x9,=GITS_BASE
        ldr     x0,=ITS_VPE_TABLE_ADDR
        and     x0,x0,#0x0000FFFFFFFFF000
        mov     x1,#0
        orr     x0,x0,x1
        mov     x1,#1
        lsl     x1,x1,#63
        orr     x0,x0,x1
        str     x0,[x9,#GITS_BASER2]

        /* ---- 5) ITS commands: VMAPP -> INVDB -> VSYNC ---- */
        bl      gicr_get_procnum
        mov     x4,x0
        mov     x0,#VPE_ID
        mov     x1,x4
        ldr     x2,=VLPE_CONF_TABLE_ADDR
        ldr     x3,=VLPE_PEND_TABLE_ADDR
        bl      its_vmapp
        mov     x0,#VPE_ID
        bl      its_invdb
        mov     x0,#VPE_ID
        bl      its_vsync

        /* ---- 6) VSGI command: configure vSGI 0 (enable, prio 0, group 1) ---- */
        /* its_vsgi(x0=vpeid, x1=vintid, x2=enable, x3=priority, x4=group) */
        mov     x0,#VPE_ID
        mov     x1,#VSGI_INTID
        mov     x2,#1                           /* enable */
        mov     x3,#VSGI_PRIO
        mov     x4,#VSGI_GRP
        bl      its_vsgi

        /* ---- 7) Set expected INTID + prepare for WFI ---- */
        ldr     x1,=gic_expected_intid
        mov     x2,#VSGI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#3
        bl      tb_notify_ready

        /* ---- 8) Inject vSGI via GITS_SGIR ---- */
        /* vsgi_send(x0=vintid, x1=vpeid) */
        mov     x0,#VSGI_INTID
        mov     x1,#VPE_ID
        bl      vsgi_send

        /* ---- 9) Wait for FIQ ---- */
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_fiq_vector:
        b       gic_fiq_handler_lpi
