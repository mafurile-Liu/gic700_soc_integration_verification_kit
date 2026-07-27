# GIC Common API Reference (common/gic_common.S)

common/gic_common.S 是本 kit 的成熟 GIC-700 公共 API 层。所有测试调用这些函数，
新用例只需 ~20 行。本文逐个讲解 API。

## 框架约定（EL3/bootcode 风格）
- 入口：test_start（.global）。
- 中断向量：curr_el_spx_irq_vector（Group1/IRQ）或 curr_el_spx_fiq_vector（Group0/FIQ）。测试bench
  向量表在收到 IRQ/FIQ 时跳到这两个标签。测试写：curr_el_spx_irq_vector: b gic_curr_el_spx_irq_vector_grp1
- 期望 INTID：测试在 WFI 前存入 gic_expected_intid（common 提供的全局变量），默认
  handler 据此校验。
- 结果：test_pass（end_test 自旋）/ test_fail（end_test 自旋）。仿真器读 x0。
- 调用约定：AAPCS（参数 x0-x7），高层 config 函数会保存 x19/x30。

## 1. Bring-up（一次性完成 GICD + GICR + CPU 接口）

### gic_init_grp1ns(void)
Non-secure Group 1（IRQ）全套 bring-up：
1. GICD_CTLR bit[1]=EnableGrp1NS，轮询 bit[31]=RWP 直到 0。
2. GICR_WAKER bit[1]=ProcessorSleep 写 0（唤醒），轮询 bit[2]=ChildrenAsleep=0。
3. CPU 接口：ICC_SRE_EL1 bit[0]=1（系统寄存器访问）、ICC_PMR_EL1=0xFF（放行全部
   优先级）、ICC_IGRPEN1_EL1 bit[0]=1（使能 Group1 信号）。
ARE 在 GIC-700 固定=1，不用配。

### gic_init_grp0(void)
Group 0（FIQ）：GICD_CTLR bit[0]=EnableGrp0；CPU 接口 ICC_IGRPEN0_EL1。其余同上。

### gic_init_grp1s(void)
Secure Group 1：GICD_CTLR bit[2]=EnableGrp1S；CPU 接口 ICC_IGRPEN1。EL3 (bootcode 默认安全态)。

## 2. PPI / SGI 配置（x0=INTID 0..31，GICR SGI_base 帧）
bit = 1 << intid。

### ppi_set_group_ns(x0) / ppi_set_group0(x0) / ppi_set_group_1s(x0)
GICR_IGROUPR0 + IGRPMODR0 组合定组：
- NS Group1：IGROUPR set bit, IGRPMODR clear bit
- Group0：两者都 clear
- Secure Group1：两者都 set

### ppi_set_prio(x0=intid, x1=prio)
GICR_IPRIORITYRn + intid 字节 = prio（0x00 最高，0xFF 最低）。

### ppi_set_level(x0) / ppi_set_edge(x0)
GICR_ICFGR1，每 INTID 2 bit，shift=2*(intid-16)：0b00=电平，0b10=边沿。

### ppi_enable(x0)
GICR_ISENABLER0：set bit 使能。

### ppi_set_pend(x0) / ppi_clr_pend(x0)
GICR_ISPENDR0 / ICPENDR0：set bit 强制 pending（验证注入，无需外设）/ 清 pending。

### ppi_config_ns(x0) / ppi_config_grp0(x0) / ppi_config_1s(x0)
一键配置：set_group + prio 0x80 + level + enable。保存 x19/x30。

## 3. SPI 配置（x0=INTID >=32，GICD）
运行时算 bank=intid/32（udiv）、bit=1<<(intid%32)（msub）。offset=基址+bank*4。

### spi_set_group_ns(x0) / spi_set_group0(x0) / spi_set_group_1s(x0)
GICD_IGROUPRn + IGRPMODRn 定组（同 PPI 语义）。

### spi_set_prio(x0, x1)
GICD_IPRIORITYRn + intid 字节。

### spi_set_level(x0) / spi_set_edge(x0)
GICD_ICFGRn，idx=intid/16，shift=2*(intid%16)。

### spi_enable(x0)
GICD_ISENABLERn：set bit。

### spi_route_self(x0)
GICD_IROUTERn + intid*8 = 本核 MPIDR 亲和值（Aff0/1/2[23:0] + Aff3[39:32] via
bfi），IRM[31]=0（路由到指定 PE）。=1 则 1-of-N 任意 PE。

### spi_set_pend(x0)
GICD_ISPENDRn：set bit 强制 pending（注入）。

### spi_config_ns(x0) / spi_config_grp0(x0) / spi_config_1s(x0)
一键：set_group + prio 0x80 + level + route_self + enable。

## 4. 应答 / 结束

### gic_ack_grp1(void) -> x0=INTID
读 ICC_IAR1_EL1：返回被取走中断的 INTID，状态 pending->active。

### gic_ack_grp0(void) -> x0=INTID
读 ICC_IAR0_EL1（Group 0 / FIQ）。

### gic_eoi_grp1(x0=intid) / gic_eoi_grp0(x0=intid)
写 ICC_EOIR1/0_EL1：priority drop + deactivate（EOImode=0 二合一）。

## 5. 等待

### gic_wait_irq_clear(void)
轮询 ISR_EL1 bit[7]（IRQ）直到 0。电平中断 IAR 后用，等信号 de-assert。

### gic_wait_fiq_clear(void)
轮询 ISR_EL1 bit[6]（FIQ）直到 0。

## 6. 默认中断处理程序

### gic_curr_el_spx_irq_vector_grp1(void)
默认 IRQ handler，测试写 curr_el_spx_irq_vector: b gic_curr_el_spx_irq_vector_grp1 即用。流程：
ack(IAR1) -> eoi(EOIR1) -> 比对 gic_expected_intid -> 不符 test_fail；
相符 -> wait_irq_clear -> test_pass。

### gic_curr_el_spx_irq_vector_grp0(void)
FIQ 版：IAR0/EOIR0 + wait_fiq_clear。

### gic_expected_intid（全局变量，.data）
测试在 WFI 前存期望 INTID：
~~~
        ldr     x1,=gic_expected_intid
        mov     x2,#SPI_INTID
        str     x2,[x1]
~~~

## 7. 结果

### test_pass(void) / test_fail(void)
test_pass: end_test (tube 0x13000000) 自旋。test_fail: end_test (tube 0x13000000) 自旋。仿真器读 x0 判定。

## 8. 底层构建块（兼容 / 自定义测试）
gic_init_* 内部含这些；自定义测试（如 preempt）也可单独调用：
- gic_dist_enable_grp1ns/1s/grp0：GICD_CTLR 使能组 + 轮询 RWP
- gicr_wake：GICR_WAKER 唤醒
- gic_wait_rwp_gicr：轮询 GICR_CTLR.RWP
- cpu_if_init_grp1/grp0：CPU 接口使能
- wfi_wait_irq/fiq：dsb + daifclr + wfi 循环
- report_pass/fail（兼容）：ldr msg + bl end_test（旧框架；新测试用 test_pass）

## 9. 如何写一个新用例（~20 行模板）
~~~
test_start:
        bl      gic_init_grp1ns              // bring-up
        ldr     x1,=gic_expected_intid       // 期望 INTID
        mov     x2,#MY_INTID
        str     x2,[x1]
        mov     x0,#MY_INTID
        bl      spi_config_ns                // 配置（或 ppi_config_ns）
        dsb     sy
        isb
        msr     daifclr,#2                   // 开 IRQ
wait_loop:
        wfi
        b       wait_loop
curr_el_spx_irq_vector:
        b       gic_curr_el_spx_irq_vector_grp1         // 默认 handler
~~~
自定义场景（抢占、特殊校验）自己写 curr_el_spx_irq_vector，用 gic_ack_grp1 /
gic_eoi_grp1 / test_pass / test_fail 组合。

## 参考
- 寄存器偏移：doc/Register_Reference.md
- 架构规范：doc/Architecture_Reference.md（IHI0069 长期记忆）
- SPI 全 case 讲解：doc/SPI_Test_Flow_Walkthrough.md
