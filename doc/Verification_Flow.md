# GIC Verification Flow

所有测试基于 common/gic_common.S（核心）+ gic_its.S（ITS/LPI）的成熟 API，骨架统一：

1. Bring-up：bl gic_init_grp1ns（或 grp1s/grp0）—— 一次调用完成 GICD 组使能
   +RWP 轮询、GICR 唤醒、CPU 接口使能。
2. 设期望 INTID：存入 gic_expected_intid（供默认 handler 校验）。
3. 配置中断源：
   - SPI：bl spi_config_ns(intid)（组/优先级/触发/路由/使能，运行时算 bank/bit）
   - PPI/SGI：bl ppi_config_ns(intid)
   - 单字段覆盖：spi_set_prio / spi_set_edge / spi_set_level 等
   - LPI：ITS bring-up + GITS_TRANSLATER（见 lpi_basic.S）
4. WFI：dsb sy; isb; msr daifclr,#2(IRQ)/#1(FIQ); wfi 循环。
5. 注入中断：
   - SPI/PPI basic：testbench force 输入信号（代码里有 /*---- Testbench ----*/ 标注）
   - SGI/preempt：自注入 ppi_set_pend / spi_set_pend（无需 testbench）
   - LPI：写 GITS_TRANSLATER
6. Handler：curr_el_spx_irq_vector: b gic_irq_handler_grp1（默认：ack IAR1 + eoi EOIR1 +
   比对 expected + 等 IRQ 撤销 + test_pass/test_fail）。
   抢占等自定义场景自己写 handler（用 gic_ack_grp1/gic_eoi_grp1/test_pass）。

## 结果约定（EL3/bootcode 风格）
test_pass: end_test (tube) 循环。test_fail: end_test (tube) 循环。仿真器读 x0 判
pass/fail。

## Testbench 注入契约（SPI/PPI）
- PE 进 WFI 后，force 中断输入信号到有效电平。
- 电平：IAR 后、EOIR 前 de-assert（否则重新 pending）。
- 边沿：一个有效脉冲。
- 不想用 testbench：SPI 写 GICD_SETSPI_NSR；PPI/SGI 写 GICR_ISPENDR0。

## 上板前 TODO
- common/gic_common.h 填 GICD_BASE / GICR_RD_BASE / GITS_BASE（ZJ100 地址表）
- PPI INTID 对齐 Cortex-A720 TRM（默认 CNTV=27）
- LPI 的 ITS 命令字节编码对照 IHI0069 ch5（lpi_basic.S 的 its_issue_commands）
