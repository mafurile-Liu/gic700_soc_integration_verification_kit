# GIC Verification Flow

Every test follows the same shape:

1. GICD bring-up: enable the target interrupt group (EnableGrp0 / EnableGrp1NS /
   EnableGrp1S) and poll GICD_CTLR.RWP. ARE is fixed=1 in GIC-700.
2. Redistributor wake: GICR_WAKER.ProcessorSleep=0, poll ChildrenAsleep=0.
3. Configure the interrupt source:
   - SPI: GICD_IGROUPR/IGRPMODR/IPRIORITYR/ICFGR/IROUTER/ISENABLER.
   - PPI/SGI: same fields in the GICR SGI_base frame (GICR_*0).
   - LPI: memory tables + ITS (see lpi_basic.S).
4. CPU interface: ICC_SRE=1, ICC_PMR=0xFF, ICC_IGRPEN0/1=1.
5. Inject the interrupt:
   - SPI/PPI: testbench forces the input signal (contract in each test header).
   - SGI: GICR_ISPENDR0 (this kit) or ICC_SGI1R_EL1 (multi-PE).
   - LPI: write GITS_TRANSLATER.
6. WFI: unmask IRQ/FIQ (daifclr) and WFI; the GIC wakes the PE.
7. Handler: read ICC_IAR0/1 (ack, returns INTID) -> clear source (level) ->
   write ICC_EOIR0/1 (deactivate) -> compare INTID -> report pass/fail.

## Testbench contract (SPI/PPI force injection)
- After the PE enters WFI, force the interrupt input to its active level.
- Level-sensitive: de-assert AFTER the handler reads IAR and BEFORE it writes EOIR.
- Edge-triggered: a single active edge is enough.

## TODOs before running
- Fill GICD_BASE / GICR_RD_BASE / GITS_BASE in common/gic_common.h (ZJ100 map).
- Confirm PPI INTID vs Cortex-A720 TRM / ZJ100 PPI wiring.
- Verify ITS command 32-byte encodings vs IHI0069 ch5 (lpi_basic.S).
