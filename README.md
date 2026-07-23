# GIC-700 SoC Integration Verification Kit

Assembly-level GIC-700 interrupt verification cases for SoC integration (e.g.
ZJ100 SYS_CPU: 24x Cortex-A720, 6 clusters, GIC-700 with GICD + 6x GCI, ITS).
Built on the ARM bare-metal WFI example style (test_start / vector handlers /
end_test).

## Structure
~~~
common/   gic_reg.h, gic_macros.h, gic_common.h, gic_common.S (shared helpers)
ppi/      PPI cases (testbench force-injects the PPI signal)
spi/      SPI cases (testbench force-injects the SPI signal)
sgi/      SGI cases (GICR_ISPENDR0 injection; ICC_SGI1R documented)
lpi/      LPI cases (ITS: MAPD/MAPC/MAPI/INV/SYNC + GITS_TRANSLATER)
vlpi/     Virtual LPI (GICv4) skeleton
vsgi/     Virtual SGI (GITS_SGIR) skeleton
doc/      Register_Reference.md, Verification_Flow.md, GIC_TestCase_Guide.md
examples/ example_makefile.md, porting_to_arm_delivery.md
~~~

## What each test does
Configure the GIC-700 for an interrupt source -> WFI -> (testbench/software
injects) -> GIC delivers IRQ/FIQ -> handler acks ICC_IAR / deactivates ICC_EOIR ->
checks INTID -> pass/fail. See doc/Verification_Flow.md.

## Before running (TODOs)
- Fill GICD_BASE / GICR_RD_BASE / GITS_BASE in common/gic_common.h from your SoC
  address map. (ZJ100: gic700 = 7168KB in the CPU cmn region; per-PE GICR bases TBD.)
- Confirm PPI INTID vs the Cortex-A720 TRM / SoC PPI wiring (default CNTV=27).
- Verify the ITS command 32-byte encodings against GIC Architecture Spec IHI0069
  ch5 (lpi_basic.S).
- SPI/PPI: the testbench must force the interrupt input (contract in each header).

## References
- Arm CoreLink GIC-700 TRM (101516_0400_12_en)
- GIC Architecture Spec (IHI0069)
- GIC-700_LPI_寄存器配置流程.md (LPI register flow, parent project)
- GIC-700_四种中断配置与激励生成流程.md (four-interrupt stimulus guide)
