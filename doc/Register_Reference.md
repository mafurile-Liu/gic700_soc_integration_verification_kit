# GIC-700 Register Reference (quick)

Source: Arm CoreLink GIC-700 TRM (101516_0400_12_en), Chapter 5. Offsets in bytes.
For the full per-register summary see the TRM; this is the verification quick-ref.

## GICD (Distributor)
CTLR 0x0000 / TYPER 0x0004 / IIDR 0x0008 / SETSPI_NSR 0x0040 / CLRSPI_NSR 0x0048 /
SETSPI_SR 0x0050 / CLRSPI_SR 0x0058 / IGROUPRn 0x0080 / ISENABLERn 0x0100 /
ICENABLERn 0x0180 / ISPENDRn 0x0200 / ICPENDRn 0x0280 / ISACTIVERn 0x0300 /
ICACTIVERn 0x0380 / IPRIORITYRn 0x0400 / ICFGRn 0x0C00 / IGRPMODRn 0x0D00 /
NSACRn 0x0E00 / IROUTERn 0x6000 (+8*n).

GICD_CTLR bits (TRM p145): [0]EnableGrp0 [1]EnableGrp1NS [2]EnableGrp1S [4]ARE_S
[5]ARE_NS(RO=1 in GIC-700) [31]RWP.

## GICR RD_base frame
CTLR 0x0000 / TYPER 0x0008 / WAKER 0x0014 / PROPBASER 0x0070 / PENDBASER 0x0078.
GICR_CTLR: [0]EnableLPIs [3]RWP [26]DPG1S [27]DPG1NS [28]DPG0.
GICR_WAKER: [0]Sleep [1]ProcessorSleep [2]ChildrenAsleep.

## GICR SGI_base frame (RD_base + 0x10000) - SGI/PPI config
IGROUPR0 0x0080 / ISENABLER0 0x0100 / ICENABLER0 0x0180 / ISPENDR0 0x0200 /
ICPENDR0 0x0280 / ISACTIVER0 0x0300 / ICACTIVER0 0x0380 / IPRIORITYRn 0x0400 /
ICFGR0 0x0C00 (SGI, RAO/WI) / ICFGR1 0x0C04 (PPI) / IGRPMODR0 0x0D00 / NSACR 0x0E00.

## ITS (Control frame at GITS_BASE)
CTLR 0x0000 / TYPER 0x0008 / CBASER 0x0080 / CWRITER 0x0088 / CREADR 0x0090 /
BASER0 0x0100 (Device table) / BASER1 0x0108 (Collection table) /
BASER2 0x0110 (vPE table, GICv4.1).
GITS_CTLR: [0]Enabled [31]Quiescent.
GITS_TYPER: [1]VLPIS(GICv4) [19]PTA(1=PA,0=ProcNum).
Translation frame (Control+0x10000): TRANSLATER 0x0040 (WO, EventID -> LPI).
vSGI frame (Control+0x20000): GITS_SGIR 0x0020 (WO, vSGI injection, GICv4.1).
  GITS_SGIR format: [31:0]=vINTID, [47:32]=vPEID.

## GICR vLPI_base frame (RD_base + 0x20000, GICv4.1)
VPROPBASER 0x0070 (vPE Config Table base) / VPENDBASER 0x0078 (vPE Pending Table + Valid).
GICR_VPENDBASER: [63]Valid [15:0]=vPEID.

## GICR_TYPER bits (64-bit, offset 0x0008)
[1]VLPIS(GICv4) [4]Last(RD tuple) [7]RVPEID(GICv4.1) [23:8]Processor_Number [63:32]Affinity.

## GICR stride (GICv4.1)
Each Redistributor = 4 frames x 64KB = 256KB = 0x40000.
RD[n] base = GICR_RD_BASE + n * 0x40000.

## ITS command opcodes (byte 0 of 32-byte command, IHI0069 ch5)
INT=0x03 SYNC=0x05 MAPD=0x08 MAPC=0x09 MAPTI=0x0A MAPI=0x0B
INV=0x0C INVALL=0x0D
GICv4.1: VSGI=0x23 VSYNC=0x25 VMAPP=0x41 VMAPTI=0x2A INVDB=0x2E.

## Special INTIDs
1020 = IAR0 returns this when Group 1 int pending (read IAR1 for actual).
1021 = IAR1 returns this when Group 0 int pending (read IAR0 for actual).
1022 = ITS maintenance interrupt. 1023 = spurious.

## CPU interface (system registers)
ICC_IAR0/1_EL1, ICC_EOIR0/1_EL1, ICC_HPPIR0/1_EL1, ICC_RPR_EL1, ICC_PMR_EL1,
ICC_BPRn_EL1, ICC_IGRPEN0/1_EL1, ICC_SRE_ELn, ICC_CTLR_ELn, ICC_DIR_EL1,
ICC_SGI0R_EL1 / ICC_SGI1R_EL1 / ICC_ASGI1R_EL1.


## Field layouts (IHI0069)
GICD_IROUTER<n> (64-bit): Aff3[39:32] IRM[31] RES0[30:24] Aff2[23:16] Aff1[15:8] Aff0[7:0].
  IRM=0 -> route to PE a.b.c.d; IRM=1 -> 1-of-N (any participating PE). (p580)

ICC_SGI1R_EL1 / ICC_SGI0R_EL1 / ICC_ASGI1R_EL1 (WO, 64-bit):
  Aff3[55:48] RS[43:41] IRM[40] Aff2[39:32] INTID(SGI id)[27:24] Aff1[23:16] TargetList[15:0].
  IRM=1 -> all PEs except originator; IRM=0 -> PEs in Aff3.Aff2.Aff1.TargetList. (p225)
