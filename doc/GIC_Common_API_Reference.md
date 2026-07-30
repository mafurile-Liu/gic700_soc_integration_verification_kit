# GIC Common API Reference (common/gic_common.S + gic_its.S)

common/gic_common.S（核心 API）+ gic_its.S（ITS/LPI/vLPI/vSGI API）是本 kit 的公共 API 层。所有测试调用这些函数，
新用例只需 ~20 行。本文逐个讲解 API。

## 框架约定（EL3/bootcode 风格）
- 入口：test_start（.global）。
- 中断向量：curr_el_spx_irq_vector（Group1/IRQ）或 curr_el_spx_fiq_vector（Group0/FIQ）。测试bench
  向量表在收到 IRQ/FIQ 时跳到这两个标签。测试写：curr_el_spx_irq_vector: b gic_irq_handler_grp1
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

### gic_irq_handler_grp1(void)
默认 IRQ handler，测试写 curr_el_spx_irq_vector: b gic_irq_handler_grp1 即用。流程：
ack(IAR1) -> eoi(EOIR1) -> 比对 gic_expected_intid -> 不符 test_fail；
相符 -> wait_irq_clear -> test_pass。

### gic_fiq_handler_grp0(void)
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

## 8.5. ITS (Interrupt Translation Service) API

ITS 负责 LPI 的设备/事件到 INTID 的映射。所有 ITS 命令通过 32 字节命令队列下发。
参考 Arm AArch64_GIC_v3_v4_example gicv3_lpis.c，IHI0069 ch5。

### its_init(void)
初始化 ITS：设置 GITS_CBASER（命令队列）、GITS_BASER0（Device 表）、
GITS_BASER1（Collection 表），然后使能 GITS_CTLR bit[0]。调用前需先 gic_init_*。

### its_add_command(void) [内部]
将 its_cmd_buf 中的 32 字节命令复制到命令队列，推进 GITS_CWRITER，
轮询 GITS_CREADR == GITS_CWRITER 等待命令执行完毕。每个 its_xxx 函数填充
its_cmd_buf 后尾调此函数。

### its_mapd(x0=device_id, x1=itt_addr, x2=id_bits)
MAPD 命令（0x08）：将 DeviceID 映射到 ITT 表。id_bits = EventID 位宽
（命令中编码为 id_bits-1）。

### its_mapc(x0=target_rd_procnum, x1=collection_id)
MAPC 命令（0x09）：将 Collection ID 映射到目标 Redistributor。
PTA=0 时用 Processor_Number（由 gicr_get_procnum 获取）。

### its_mapti(x0=device_id, x1=event_id, x2=intid, x3=collection_id)
MAPTI 命令（0x0A）：将 DeviceID/EventID 映射到指定 pINTID 和 Collection。

### its_mapi(x0=device_id, x1=event_id, x2=collection_id)
MAPI 命令（0x0B）：将 EventID 映射到 Collection（pINTID = EventID）。

### its_int(x0=device_id, x1=event_id)
INT 命令（0x03）：软件触发 LPI（命令队列方式，替代写 GITS_TRANSLATER）。

### its_inv(x0=device_id, x1=event_id)
INV 命令（0x0C）：使 ITS 缓存的 LPI 配置失效。修改配置表后必须调用。

### its_invall(x0=collection_id)
INVALL 命令（0x0D）：使 Collection 内所有 LPI 配置缓存失效。

### its_sync(x0=target_rd_procnum)
SYNC 命令（0x05）：确保目标 RD 上所有未完成 ITS 操作已完成。

## 8.6. LPI 配置 API

### lpi_set_tables(x0=prop_addr, x1=pend_addr, x2=id_bits)
写 GICR_PROPBASER（配置表）和 GICR_PENDBASER（pending 表）。
id_bits >= 14（LPI 从 8192 开始）。Cache 属性 = Device-nGnRnE。

### lpi_enable(void)
GICR_CTLR bit[0]=EnableLPIs，轮询 GICR_CTLR bit[3]=RWP 直到 0。

### lpi_config(x0=intid, x1=enable, x2=priority)
写 LPI 配置表内存条目：byte = (priority & 0xFC) | (enable & 1)。
bit[0]=使能，bits[7:2]=优先级（0x00 最高，0xFC 最低）。

### lpi_trigger(x0=event_id)
写 EventID 到 GITS_TRANSLATER（ITS_BASE+0x10040），硬件方式触发 LPI。

## 8.7. Redistributor 亲和匹配（多核测试用）

### gicr_find_rd(void) -> x0 = RD_base 地址
扫描 GICR_TYPER，找到 Affinity[63:32] 匹配当前 PE MPIDR 的 Redistributor。
RD 帧起始 = GICR_RD_BASE，步长 = 0x40000（GICv4.1: 4 页 x 64KB）。
未找到返回 0xFFFFFFFF。

### gicr_get_procnum(void) -> x0 = Processor_Number
读 GICR_TYPER[23:8]。用于 ITS MAPC/SYNC 命令的目标指定（PTA=0 时）。

## 8.8. LPI 专用 FIQ 处理程序

### gic_fiq_handler_lpi(void)
LPI 始终为 NS Group 1，在 EL3 以 FIQ 形式到达。Handler 流程：
1. 读 IAR0 -> 若返回 1020/1021（Group 1 pending），读 IAR1 取实际 LPI INTID，EOI1
2. 若返回 1023（spurious）-> test_fail
3. 若返回其他 -> 直接 Group 0，EOI0
4. 比对 gic_expected_intid -> 匹配 test_pass / 不匹配 test_fail

## 8.9. vLPI / vSGI API（GICv4.1）

### vlpi_set_vpe_table(x0=vpe_conf_addr, x1=num_pages)
写 GICR_VPROPBASER（vLPI 帧 RD_base+0x20000），指向 vPE 配置表。

### vlpi_make_resident(x0=vpeid)
写 GICR_VPENDBASER：Valid=1 + vPEID。使 vPE 驻留在当前 RD 上。

### vlpi_config(x0=intid, x1=enable, x2=priority)
写 vLPI 配置表条目（格式同物理 LPI）。

### its_vmapp(x0=vpeid, x1=target_rd_procnum, x2=conf_addr, x3=pend_addr)
VMAPP 命令（0x41）：映射 vPEID 到目标 RD + vPE 配置/pending 表。

### its_vmapti(x0=device_id, x1=event_id, x2=vpeid, x3=vintid)
VMAPTI 命令（0x2A）：映射 DeviceID/EventID 到 vPEID + vINTID。

### its_vsync(x0=vpeid)
VSYNC 命令（0x25）：同步 vPEID 的虚拟中断操作。

### its_invdb(x0=vpeid)
INVDB 命令（0x2E）：使 vPEID 的配置缓存失效。

### its_vsgi(x0=vpeid, x1=vintid, x2=enable, x3=priority, x4=group)
VSGI 命令（0x23）：配置虚拟 SGI（使能/优先级/组）并注入。

### vsgi_send(x0=vintid, x1=vpeid)
写 GITS_SGIR（ITS_BASE+0x20020）注入 vSGI。
格式：[31:0]=vINTID, [47:32]=vPEID。

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
        b       gic_irq_handler_grp1         // 默认 handler
~~~
自定义场景（抢占、特殊校验）自己写 curr_el_spx_irq_vector，用 gic_ack_grp1 /
gic_eoi_grp1 / test_pass / test_fail 组合。

## 参考
- 寄存器偏移：doc/Register_Reference.md
- 架构规范：doc/Architecture_Reference.md（IHI0069 长期记忆）
- SPI 全 case 讲解：doc/SPI_Test_Flow_Walkthrough.md
