# GIC Architecture Specification - Long-Term Reference (IHI0069H)

This document is the project long-term memory for the GIC architecture. Any implementation or modification in this kit must reference the GIC Architecture Specification (IHI0069H). The full text is extracted page-by-page for grep/lookup.

## Chapter/section index (with page numbers)

`
[p5] Contents
[p9] Preface
[p10] About this specification
[p11] Using this specification
[p13] Conventions
[p14] Additional reading
[p15] Feedback
[p17] Introduction
[p18] 1.1 About the Generic Interrupt Controller (GIC)
[p23] 1.2 Terminology
[p27] 1.3 Supported configurations and compatibility
[p33] Distribution and Routing of Interrupts
[p34] 2.1 The Distributor and Redistributors
[p35] 2.2 INTIDs
[p39] 2.3 Affinity routing
[p41] GIC Partitioning
[p42] 3.1 The GIC logical components
[p47] 3.2 Interrupt bypass support
[p49] Physical Interrupt Handling and Prioritization
[p50] 4.1 Interrupt lifecycle
[p58] 4.2 Locality-specific Peripheral Interrupts
[p59] 4.3 Private Peripheral Interrupts
[p60] 4.4 Software Generated Interrupts
[p61] 4.5 Shared Peripheral Interrupts
[p63] 4.6 Interrupt grouping
[p69] 4.7 Enabling the distribution of interrupts
[p71] 4.8 Interrupt prioritization
[p85] Locality-specific Peripheral Interrupts and the ITS
[p86] 5.1 LPIs
[p93] 5.2 The Interrupt Translation Service
[p102] 5.3 ITS commands
[p137] 5.4 Common ITS pseudocode functions
[p147] 5.5 ITS command error encodings
[p150] 5.6 ITS power management
[p151] Virtual Interrupt Handling and Prioritization
[p152] 6.1 About GIC support for virtualization
[p153] 6.2 Operation overview
[p157] 6.3 Configuration and control of VMs
[p160] 6.4 Pseudocode
[p163] GICv4.0 Virtual LPI Support
[p164] 7.1 About GICv4.0 virtual Locality-specific Peripheral Interrupt support
[p165] 7.2 Direct injection of virtual interrupts
[p167] GICv4.1 Virtual Interrupt Support
[p168] 8.1 About GICv4.1 virtual interrupt support
[p169] 8.2 Changes to the CPU interface
[p170] 8.3 ITS commands
[p171] 8.4 vPEID width
[p172] 8.5 Doorbells
[p174] 8.6 vPE residency and locating data structures
[p176] 8.7 Register based vLPI invalidation
[p177] 8.8 Direct injection of vSGIs
[p179] Memory Partitioning and Monitoring
[p180] 9.1 Overview
[p181] 9.2 MPAM and the Redistributors
[p182] 9.3 MPAM and the ITS
[p183] 9.4 GIC usage of MPAM
[p184] 9.5 GICv4.1 data structures and MPAM
[p185] Connecting to Armv8-R AArch64 PEs
[p186] 10.1 Armv8-R AArch64 CPU interface requirements
[p187] Power Management
[p188] 11.1 Power management
[p189] Programmers’ Model
[p190] 12.1 About the programmers’ model
[p215] 12.2 AArch64 System register descriptions
[p290] 12.3 AArch64 System register descriptions of the virtual registers
[p335] 12.4 AArch64 virtualization control System registers
[p365] 12.5 AArch32 System register descriptions
[p448] 12.6 AArch32 System register descriptions of the virtual registers
[p497] 12.7 AArch32 virtualization control System registers
[p529] 12.8 The GIC Distributor register map
[p533] 12.9 The GIC Distributor register descriptions
[p627] 12.10 The GIC Redistributor register map
[p631] 12.11 The GIC Redistributor register descriptions
[p722] 12.12 The GIC CPU interface register map
[p723] 12.13 The GIC CPU interface register descriptions
[p760] 12.14 The GIC virtual CPU interface register map
[p762] 12.15 The GIC virtual CPU interface register descriptions
[p793] 12.16 The GIC virtual interface control register map
[p794] 12.17 The GIC virtual interface control register descriptions
[p815] 12.18 The ITS register map
[p817] 12.19 The ITS register descriptions
[p845] Pseudocode
[p846] 13.1 AArch64 functions
[p862] 13.2 Functions for memory-mapped registers
[p865] System Error Reporting
[p866] 14.1 About System Error reporting
[p867] Legacy Operation and Asymmetric Configurations
[p868] 15.1 Legacy support of interrupts and asymmetric configurations
[p872] 15.2 The asymmetric configuration
[p873] 15.3 Support for legacy operation of VMs
[p875] GIC Stream Protocol interface
[p876] A.1 Overview
[p877] A.2 Signals and the GIC Stream Protocol
[p880] A.3 The GIC Stream Protocol
[p885] A.4 Alphabetic list of command and response packet formats
[p903] Pseudocode Definition
[p904] B.1 About Arm pseudocode
[p905] B.2 Data types
[p909] B.3 Expressions
[p911] B.4 Operators and built-in functions
[p916] B.5 Statements and program structure
[p920] B.6 Pseudocode terminology
[p921] B.7 Miscellaneous helper procedures and support functions
[p933] Glossary
`

## Verification cheat sheet (with arch-spec page refs)

Source PDF: IHI0069H_gic_architecture_specification.pdf.
Full text extracted to: gic_work/extract_archspec/page-NNNN.txt (942 pages).
This file is the project long-term memory for GIC architecture; consult it for any
implementation or modification.

### INTID ranges (p35-37)
- 0-15 SGI (banked per PE); 16-31 PPI (banked); 1056-1119 ext PPI (GICv3.1)
- 32-1019 SPI; 4096-5119 ext SPI (GICv3.1); 1020-1023 special; 8192+ LPI
- 1023 = spurious (no interrupt to ack); 1020/1021 cross-security; 1022 NMI

### Interrupt states (p24, p55)
- Inactive -> Pending -> Active -> Active&Pending -> Inactive (SGI/PPI/SPI)
- LPI: simpler (no active state, only pending/not-pending)

### Groups & security -> IRQ/FIQ (p63-67)
- Group 0 -> FIQ; Secure Group 1 / Non-secure Group 1 -> IRQ
- IGROUPR + IGRPMODR select the group (when DS=0 two-security; DS=1 single, IGRPMOD RAZ/WI)
- 4.6.2: assignment of groups to IRQ/FIQ signals

### Affinity routing (p39)
- ARE_S/ARE_NS enable affinity routing; GIC-700 fixed=1
- SPI routed by GICD_IROUTER (IRM bit31: 0=specific PE a.b.c.d, 1=1-of-N any)
- SGI routed by ICC_SGI*R (IRM + target list); PPI to owning PE; LPI via ITS

### GIC partitioning (p42)
- Distributor (GICD): SPI management + LPI property/pending tables
- Redistributor (GICR): per-PE; SGI/PPI config in SGI_base frame; LPI table base; power mgmt
- ITS: LPI translation (Device/Collection/ITT tables + command queue)
- CPU interface (ICC_*): ack/EOI/priority on the PE

### Interrupt handling (p50-55, p71)
- ICC_IAR0/1: read -> INTID, state pending->active
- ICC_EOIR0/1: priority drop + deactivate (EOImode=0); or split: EOIR drop + ICC_DIR deactivate (EOImode=1)
- Priority: 8-bit, 0x00 highest; ICC_PMR masks (only prio < PMR signaled)
- ICC_BPR: group/sub-priority split; lower BPR = more preemption
- Preemption (4.8.5): higher-prio preempts active lower-prio

### SGI generation - ICC_SGI1R_EL1 (p225)
- Aff3[55:48] RS[43:41] IRM[40] Aff2[39:32] INTID[27:24] Aff1[23:16] TargetList[15:0]
- IRM=1 broadcast (all PEs except self); IRM=0 targeted (Aff3.Aff2.Aff1.TargetList)
- ICC_SGI0R=Group0, ICC_SGI1R=Grp1 current sec, ICC_ASGI1R=Grp1 other sec

### ITS (p83-120)
- Tables: Device (GITS_BASER0), Collection (GITS_BASER1), ITT (memory), command queue (GITS_CBASER)
- Commands (p106-120): MAPD(Device->ITT), MAPC(Collection->RDbase), MAPI/MAPTI(Event->INTID+ICID),
  INV/INVALL(invalidate cache), MOVALL/MOVI(move), DISCARD, CLEAR, SYNC(wait)
- LPI trigger: write EventID to GITS_TRANSLATER (p816) -> ITS translates -> LPI pends on target RD
- LPI tables: Property (1 byte/LPI: [7]enable [6:3]priority), Pending (1 bit/LPI); pending per-RD, property shared

### GICD_IROUTER fields (p580)
- Aff3[39:32] IRM[31] RES0[30:24] Aff2[23:16] Aff1[15:8] Aff0[7:0]

### ITS registers (p816)
- GITS_TRANSLATER 0x0040 (translation frame); GITS_SGIR 0x0020 (vSGI frame); GITS_CTLR/CBASER/CWRITER/CREADR/BASER in control frame

### Virtualization (ch6 p?, ch7 GICv4.0, ch8 GICv4.1)
- GICv4: vLPI/vSGI direct injection to vPE; vPE table; VMAPP/VMOVP/VMAPI/VMOVI/VSGI/VINVALL commands (5.3.16-5.3.25)
- CPU interface virtualization: ICH_* list registers (ICH_LR<n>, ICH_VMCR_EL2, ICH_HCR_EL2, ICH_AP0R/AP1R)

### GIC Stream Protocol (Appendix A)
- Inter-block protocol between GICD/GCI/CPU interface: Set/Clear/Activate/Deactivate/Generate SGI/Quiesce packets

### Error reporting (ch14)
- GICT error records (GICT_ERR<n>FR/CTLR/STATUS/ADDR/MISC); GICT_ERRGSR; GICT_ERRIRQCR
