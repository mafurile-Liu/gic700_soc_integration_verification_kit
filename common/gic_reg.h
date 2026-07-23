// gic_reg.h - GIC-700 register offsets and bit fields.
// Source: Arm CoreLink GIC-700 TRM (101516_0400_12_en), Chapter 5.
// Standard GICv3 offsets; cross-check with doc/Register_Reference.md.
#ifndef GIC_REG_H
#define GIC_REG_H

// ---- GICD (Distributor) ----
#define GICD_CTLR          0x0000
#define GICD_TYPER         0x0004
#define GICD_IIDR          0x0008
#define GICD_SETSPI_NSR    0x0040   // WO message-set NS SPI
#define GICD_CLRSPI_NSR    0x0048
#define GICD_SETSPI_SR     0x0050   // WO message-set Secure SPI
#define GICD_CLRSPI_SR     0x0058
#define GICD_IGROUPRn      0x0080   // +4*n
#define GICD_ISENABLERn    0x0100   // +4*n
#define GICD_ICENABLERn    0x0180   // +4*n
#define GICD_ISPENDRn      0x0200   // +4*n
#define GICD_ICPENDRn      0x0280   // +4*n
#define GICD_ISACTIVERn    0x0300   // +4*n
#define GICD_ICACTIVERn    0x0380   // +4*n
#define GICD_IPRIORITYRn   0x0400   // +n (byte per INTID)
#define GICD_ICFGRn        0x0C00   // +4*(n/16), 2 bits/INTID
#define GICD_IGRPMODRn     0x0D00   // +4*n (RAZ/WI if DS==1)
#define GICD_NSACRn        0x0E00   // +4*(n/16)
#define GICD_IROUTERn      0x6000   // +8*n (GICD_IROUTER32 == 0x6100)

// GICD_CTLR bits (TRM p145)
#define GICD_CTLR_EnableGrp0    (1 << 0)
#define GICD_CTLR_EnableGrp1NS  (1 << 1)
#define GICD_CTLR_EnableGrp1S   (1 << 2)   // RES0 if DS==1
#define GICD_CTLR_ARE_S         (1 << 4)   // RO=1 in GIC-700
#define GICD_CTLR_ARE_NS        (1 << 5)   // RO=1 in GIC-700
#define GICD_CTLR_RWP           (1 << 31)

// ---- GICR RD_base frame ----
#define GICR_CTLR          0x0000
#define GICR_TYPER         0x0008
#define GICR_WAKER         0x0014
#define GICR_PROPBASER     0x0070
#define GICR_PENDBASER     0x0078
#define GICR_CTLR_EnableLPIs   (1 << 0)
#define GICR_CTLR_RWP          (1 << 3)
#define GICR_CTLR_DPG1S        (1 << 26)
#define GICR_CTLR_DPG1NS       (1 << 27)
#define GICR_CTLR_DPG0         (1 << 28)
#define GICR_WAKER_Sleep           (1 << 0)
#define GICR_WAKER_ProcessorSleep  (1 << 1)
#define GICR_WAKER_ChildrenAsleep  (1 << 2)

// ---- GICR SGI_base frame (RD_base + 0x10000): SGI/PPI config ----
#define GICR_IGROUPR0      0x0080
#define GICR_ISENABLER0    0x0100
#define GICR_ICENABLER0    0x0180
#define GICR_ISPENDR0      0x0200
#define GICR_ICPENDR0      0x0280
#define GICR_ISACTIVER0    0x0300
#define GICR_ICACTIVER0    0x0380
#define GICR_IPRIORITYRn   0x0400   // +n (byte per INTID 0..31)
#define GICR_ICFGR0        0x0C00   // SGIs: RAO/WI (always edge)
#define GICR_ICFGR1        0x0C04   // PPIs: 2 bits/INTID
#define GICR_IGRPMODR0     0x0D00
#define GICR_NSACR         0x0E00

// ---- ITS ----
#define GITS_CTLR          0x0000
#define GITS_TYPER         0x0008
#define GITS_CBASER        0x0080
#define GITS_CWRITER       0x0088
#define GITS_CREADR        0x0090
#define GITS_BASER0        0x0100   // Device table
#define GITS_BASER1        0x0108   // Collection table
#define GITS_TRANSLATER    0xC040   // WO: EventID -> LPI
#define GITS_SGIR          0x0020   // WO: vSGI injection (ITS vSGI frame)
#define GITS_CTLR_Enabled      (1 << 0)
#define GITS_CTLR_Quiescent    (1 << 31)

// ---- INTID ranges ----
#define INTID_FIRST_SGI    0
#define INTID_LAST_SGI     15
#define INTID_FIRST_PPI    16
#define INTID_LAST_PPI     31
#define INTID_FIRST_SPI    32
#define INTID_LAST_SPI     1019
#define INTID_FIRST_LPI    8192
#define INTID_SPURIOUS     1023
#endif
