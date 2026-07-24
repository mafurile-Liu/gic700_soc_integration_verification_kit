# SPI 中断测试流程详解（以 spi_basic_group1ns.S 为例）

以 Non-secure Group 1 的 SPI 基本收发为例，逐步讲一个 GIC-700 SPI 中断用例从
配置到收中断的完整流程。对应源码：spi/spi_basic_group1ns.S。

## 0. 背景

- SPI（Shared Peripheral Interrupt）：共享外设中断，INTID 32~1019，可路由到任意
  PE，由 GICD（Distributor）统一管理。
- Group：Non-secure Group 1 的中断以 IRQ 发给 PE。
- 一次测试核心：在 GICD 配好这个 SPI（组/优先级/触发/路由/使能）-> PE 进 WFI ->
  testbench 拉有效 SPI 输入 -> GIC pending 并唤醒 PE -> 处理程序 IAR 应答、EOIR
  结束、校验 INTID。

## 1. GICD 使能 Group 1

~~~
    bl gic_dist_enable_grp1ns
~~~
在 GICD_CTLR 把 bit[1] EnableGrp1NS 置 1，允许 Non-secure Group 1 中断被分发；
写后轮询 GICD_CTLR.RWP（bit[31]）到 0 等写生效。（GIC-700 的 ARE 固定=1，不用配。）

## 2. 唤醒本核 Redistributor

~~~
    bl gicr_wake
~~~
SPI 经 GICD 分发后最终送到本核 Redistributor。gicr_wake 把 GICR_WAKER.
ProcessorSleep（bit[1]）写 0 让本核上线，轮询 ChildrenAsleep（bit[2]）==0 确认
就绪。必须在配 CPU 接口之前做。

## 3. 使能 CPU 接口

~~~
    bl cpu_if_init_grp1
~~~
- ICC_SRE_EL1.SRE（bit[0]）=1：允许用系统寄存器访问 CPU 接口。
- ICC_PMR_EL1=0xFF：优先级掩码，0xFF=放行全部优先级。
- ICC_IGRPEN1_EL1（bit[0]）=1：使能 Group 1 信号送到本核。

## 4. 在 GICD 配置这个 SPI（每步都是 读-改-写）

### 4.1 分组 GICD_IGROUPRn / GICD_IGRPMODRn
~~~
    ldr  w1, [x0, #SPI_IGROUPR_OFF(SPI_INTID)]
    orr  w1, w1, #SPI_BIT(SPI_INTID)
    str  w1, [x0, #SPI_IGROUPR_OFF(SPI_INTID)]
~~~
SPI 每 32 个放一组（n=INTID/32）。对应 bit 置 1=分到 Group 1；IGRPMODRn 对应
bit 清 0 = Non-secure Group 1。

### 4.2 优先级 GICD_IPRIORITYRn
~~~
    mov  w1, #PRIO_DEFAULT
    strb w1, [x0, #SPI_IPRIORITYR_OFF(SPI_INTID)]
~~~
每 INTID 一个字节（0x00 最高，0xFF 最低），这里写 0x80。

### 4.3 触发方式 GICD_ICFGRn
~~~
    ldr  w1, [x0, #SPI_ICFGR_OFF(SPI_INTID)]
    bic  w1, w1, #(3 << SPI_ICFGR_SHIFT(SPI_INTID))   // 0b00=level
    str  w1, [x0, #SPI_ICFGR_OFF(SPI_INTID)]
~~~
每 INTID 占 2 bit：0b00=电平，0b10=边沿。这里清成电平。

### 4.4 路由 GICD_IROUTERn（路由到本核）
~~~
    mrs  x2, mpidr_el1
    and  x3, x2, #0xFFFFFF
    ubfx x4, x2, #32, #8
    bfi  x3, x4, #32, #8
    str  x3, [x0, #SPI_IROUTER_OFF(SPI_INTID)]
~~~
IROUTER 填目标 PE 亲和值：Aff0[7:0] Aff1[15:8] Aff2[23:16] Aff3[39:32]，
IRM（bit[31]）=0=路由到指定 PE（=1 则 1-of-N 任意）。从本核 MPIDR 取值填入，
让 SPI 发给本核。

### 4.5 使能 GICD_ISENABLERn
~~~
    mov  w1, #SPI_BIT(SPI_INTID)
    str  w1, [x0, #SPI_ISENABLER_OFF(SPI_INTID)]
~~~
对应 bit 置 1 使能该 SPI。配置完成。

## 5. 进 WFI 等 testbench 注入

~~~
    // ===== TESTBENCH INJECTION POINT =====
    bl   wfi_wait_irq
~~~
wfi_wait_irq：先 dsb sy（保证前面寄存器写对 GIC 可见），再 daifclr #2 清
PSTATE.I（开 IRQ），然后 WFI 挂起。**此时你的 testbench 要把 SPI 输入信号（接
SPI Collator 的线）拉到有效电平**，GIC 才会 pending 并唤醒 PE。
- 电平型：拉有效后，等 handler 读 IAR 再 de-assert，否则 EOIR 后重新 pending。
- 边沿型：一个有效脉冲即可。
- 不想用 testbench：往 GICD_SETSPI_NSR 写 INTID，或写 GICD_ISPENDRn 直接置 pending。

## 6. 中断处理程序（curr_el_spx_irq_vector）

~~~
    mrs  x3, ICC_IAR1_EL1    // 应答：读出 INTID，状态 pending->active
    msr  ICC_EOIR1_EL1, x3   // 结束：优先级下降 + 去活（EOImode=0）
    mov  w2, #SPI_INTID
    cmp  w3, w2              // 校验 INTID 是否就是配的那个 SPI
    b.ne spi_fail
    ...
    bl   report_pass
~~~
- ICC_IAR1_EL1：读返回被取走中断的 INTID，状态机推进。
- ICC_EOIR1_EL1：写回 INTID，完成 priority drop + deactivation。
- 校验 INTID==SPI_INTID：对则 PASS，错则 FAIL。

## 7. 可调项

- 默认 SPI_INTID=32，用 -DSPI_INTID=<n> 覆盖。
- GICD_BASE / GICR_RD_BASE 按 SoC 地址表填（common/gic_common.h）。
- 边沿看 spi_edge.S；优先级/掩码看 spi_priority.S；抢占看 spi_preempt.S。
