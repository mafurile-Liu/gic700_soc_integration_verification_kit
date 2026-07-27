/******************************************************************************
 * File:      lpi_basic.S
 * Purpose:   LPI delivery via ITS: MAPD/MAPC/MAPI/INV/SYNC then write
 *            GITS_TRANSLATER. LPI config in memory tables (Property/Pending).
 *            TRM 4.12/4.13, IHI0069 ch5.
 * NOTE:      ITS command 32-byte field packing must be filled per IHI0069 ch5
 *            figures (its_issue_commands TODO). Register setup is complete.
 ******************************************************************************/
#include "gic_common.h"

.equ LPI_INTID, 8192
.equ DEV_ID, 0
.equ EVT_ID, 0
.equ COL_ID, 0
.equ RD_PROCNUM, 0

        .section .text
        .align 4
        .global test_start
        .global curr_el_spx_irq_vector

test_start:
        bl      gic_init_grp1s
        /* GICR: LPI Property/Pending tables + EnableLPIs (TRM 4.13.1) */
        ldr     x0,=GICR_RD_BASE
        ldr     x1,=lpi_prop_base
        str     x1,[x0,#GICR_PROPBASER]
        ldr     x1,=lpi_pend_base
        orr     x1,x1,#1
        str     x1,[x0,#GICR_PENDBASER]
        ldr     w1,[x0,#GICR_CTLR]
        orr     w1,w1,#GICR_CTLR_EnableLPIs
        str     w1,[x0,#GICR_CTLR]
        bl      gic_wait_rwp_gicr
        /* ITS init: BASER0(Device)/BASER1(Collection)/CBASER(cmdq)/CTLR enable */
        ldr     x9,=GITS_BASE
        ldr     x1,=its_dev_base
        str     x1,[x9,#GITS_BASER0]
        ldr     x1,=its_col_base
        str     x1,[x9,#GITS_BASER1]
        ldr     x1,=its_cmdq_base
        str     x1,[x9,#GITS_CBASER]
        str     xzr,[x9,#GITS_CWRITER]
        mov     w1,#GITS_CTLR_Enabled
        str     w1,[x9,#GITS_CTLR]
1:      ldr     w1,[x9,#GITS_CTLR]
        tbnz    w1,#31,1b
        /* ITS commands: MAPD/MAPC/MAPI/INV/SYNC (TODO: encode per IHI0069 ch5) */
        bl      its_issue_commands
        /* trigger LPI: write EventID to GITS_TRANSLATER */
        mov     x0,#EVT_ID
        mov     x10,#GITS_TRANSLATER
        str     x0,[x9,x10]
        ldr     x1,=gic_expected_intid
        mov     x2,#LPI_INTID
        str     x2,[x1]
        dsb     sy
        isb
        msr     daifclr,#2
        bl      tb_notify_ready
wait_loop:
        wfi
        b       wait_loop

curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1

its_issue_commands:
        ret

        .section .data
        .align 3
lpi_prop_base:  .quad 0
lpi_pend_base:  .quad 0
its_dev_base:   .quad 0
its_col_base:   .quad 0
its_cmdq_base:  .quad 0
