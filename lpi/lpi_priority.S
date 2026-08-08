/******************************************************************************
 * File:      lpi_priority.S
 * Purpose:   LPI priority test. Same ITS bring-up as lpi_basic.S, but the
 *            LPI Configuration Table entry is set with a non-zero priority
 *            (0x40 = medium). Verifies the ITS reads and respects the
 *            priority field from the in-memory config table.
 *
 *            Config byte format: bit[0]=enable, bits[7:2]=priority.
 *              priority 0x40 -> byte = (0x40 & 0xFC) | 1 = 0x41
 *              (0x40 = 0100_0000, priority field [7:2] = 0b010000 = 16,
 *               effective 8-bit priority = 16<<2 = 0x40)
 *
 *            Reference: Arm AArch64_GIC_v3_v4_example main_lpi.c.
 ******************************************************************************/
#include "gic_common.h"

.equ LPI_INTID,  8192
.equ DEV_ID,     0
.equ EVT_ID,     0
.equ COL_ID,     0
.equ ID_BITS,    2
.equ LPI_PRIO,   0x40          /* medium priority (0x00 highest, 0xFC lowest) */

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

        /* ---- 2) LPI tables + enable ---- */
        ldr     x0,=LPI_PROP_TABLE_ADDR
        ldr     x1,=LPI_PEND_TABLE_ADDR
        mov     x2,#15
        bl      lpi_set_tables
        bl      lpi_enable

        /* ---- 3) ITS init ---- */
        bl      its_init

        /* ---- 4) ITS commands: MAPD -> MAPC -> MAPTI -> SYNC ---- */
        bl      gicr_get_procnum
        mov     x4,x0
        mov     x0,#DEV_ID
        ldr     x1,=ITS_ITT_ADDR
        mov     x2,#ID_BITS
        bl      its_mapd
        mov     x0,x4
        mov     x1,#COL_ID
        bl      its_mapc
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        mov     x2,#LPI_INTID
        mov     x3,#COL_ID
        bl      its_mapti
        mov     x0,x4
        bl      its_sync

        /* ---- 5) Configure LPI 8192: enable, priority 0x40 ---- */
        /* byte = (0x40 & 0xFC) | 1 = 0x41 */
        mov     x0,#LPI_INTID
        mov     x1,#1
        mov     x2,#LPI_PRIO
        bl      lpi_config

        /* ---- 6) INV: flush ITS config cache ---- */
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        bl      its_inv

        /* ---- 7) Set expected INTID + prepare for WFI ---- */
        ldr     x1,=gic_expected_intid
        mov     x2,#LPI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#3
        mov     x0,#1   /* edge-triggered */
        bl      tb_notify_ready

        /* ---- 8) Trigger LPI ---- */
        mov     x0,#DEV_ID
        mov     x1,#EVT_ID
        bl      its_int

        /* ---- 9) Wait for FIQ ---- */
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_fiq_vector:
        b       gic_fiq_handler_lpi
