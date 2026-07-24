# Porting to the testbench / 样板 framework

本 kit 沿用 样板.s 的框架约定（非 ARM wfi.s 的 end_test/core_synchronisation）：

1. 入口：test_start（.global）。
2. 中断向量：irq_handler（Group1/IRQ）或 fiq_handler（Group0/FIQ）。测试bench
   的向量表在收到 IRQ/FIQ 时跳到这两个标签。测试里写：
   irq_handler: b gic_irq_handler_grp1（用默认 handler）或自定义。
3. 结果：test_pass（x0=0 + wfe 自旋）/ test_fail（x0=1 + wfe 自旋）。仿真器读
   x0 判定。无需 end_test。
4. 期望 INTID：测试在 WFI 前把期望 INTID 存入 gic_expected_intid（common 提供），
   默认 handler 据此校验。
5. 基址：GICD_BASE / GICR_RD_BASE / GITS_BASE 在 common/gic_common.h 填或 -D 覆盖。
   多核：每个 PE 用自己的 GICR_RD_BASE。
6. SPI/PPI 注入：testbench force 信号（代码标注 /*---- Testbench ----*/）；或自
   注入 spi_set_pend / ppi_set_pend。
7. 链接：只需提供 gic_common.S + 各测试 .S，无需额外框架符号（end_test 等已不用）。
