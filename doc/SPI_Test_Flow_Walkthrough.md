# SPI 中断测试流程详解（全部 7 个 SPI case，按实际代码逐步讲解）

本文对照 spi/ 目录下 7 个 SPI 测试的实际代码，逐步讲解。所有测试都基于
common/gic_common.S 的成熟 API，每个测试只有 ~25 行。

## 0. 共同模式与 API

所有 SPI 测试共享同一个骨架：

~~~
test_start:
        bl      gic_init_<group>          // 1. 一次性 bring-up
        ldr     x1,=gic_expected_intid    // 2. 存期望 INTID
        mov     x2,#SPI_INTID
        str     x2,[x1]
        mov     x0,#SPI_INTID
        bl      spi_config_<group>        // 3. 配置 SPI（组/优先级/触发/路由/使能）
        ...（变体可能加 spi_set_prio / spi_set_edge）
        dsb     sy
        isb
        msr     daifclr,#2                // 4. 开 IRQ
wait_loop:
        wfi                               // 5. 等 testbench 注入
        b       wait_loop
curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1      // 6. 默认 handler（ack/eoi/校验/pass-fail）
~~~

API 做了什么（实现在 gic_common.S）：
- gic_init_grp1ns：GICD_CTLR.EnableGrp1NS=1 + 轮询 RWP；GICR_WAKER 唤醒 +
  轮询 ChildrenAsleep；CPU 接口 ICC_SRE=1/ICC_PMR=0xFF/ICC_IGRPEN1=1。
- spi_config_ns(x0=INTID)：运行时算 bank=INTID/32、bit=1<<(INTID%32)，做
  GICD_IGROUPR(置Group1)+IGRPMODR(清=NSGrp1)+IPRIORITYR(0x80)+ICFGR(电平)+
  IROUTER(路由到本核,IRM=0)+ISENABLER(使能)。
- gic_irq_handler_grp1：读 ICC_IAR1(INTID, pending->active) -> 写 ICC_EOIR1
  (priority drop+deactivate) -> 比对 gic_expected_intid -> 等 isr_el1 bit7 清
  -> test_pass(end_test) / 不符 test_fail(end_test)。

## 1. spi_basic_group1ns.S（Non-secure Group 1，IRQ）

完整代码与逐行讲解：

~~~
test_start:
        bl      gic_init_grp1ns
~~~
一次性 bring-up（见上）。GICD 使能 NS Group1、唤醒本核 Redistributor、使能 CPU
接口。ARE 在 GIC-700 固定为 1，不用配。

~~~
        ldr     x1,=gic_expected_intid
        mov     x2,#SPI_INTID            // SPI_INTID=32
        str     x2,[x1]
~~~
把期望的 INTID（32）存入全局变量 gic_expected_intid，供默认 handler 校验。

~~~
        mov     x0,#SPI_INTID
        bl      spi_config_ns
~~~
配置 SPI 32：分到 Non-secure Group 1、优先级 0x80、电平触发、路由到本核
（GICD_IROUTER 从 MPIDR 取亲和值，IRM=0）、使能。bank/bit 在函数内运行时算。

~~~
        dsb     sy
        isb
        msr     daifclr,#2
wait_loop:
        wfi
        b       wait_loop
~~~
dsb 保证前面的寄存器写对 GIC 可见；daifclr #2 清 PSTATE.I 开 IRQ；WFI 挂起。
**此时 testbench 要把 SPI 输入信号（接 SPI Collator）拉有效**，GIC 才 pending
并唤醒本核（电平型：IAR 后 de-assert；边沿型：一个脉冲）。

~~~
curr_el_spx_irq_vector:
        b       gic_irq_handler_grp1
~~~
中断被取后跳到 curr_el_spx_irq_vector，转默认 handler：ack(IAR1)->eoi(EOIR1)->比对
expected->等 IRQ 撤销->test_pass。INTID 不符则 test_fail。

## 2. spi_basic_group0.S（Group 0，FIQ）

与 group1ns 的差异：
- bl gic_init_grp0（GICD EnableGrp0、CPU IF ICC_IGRPEN0）
- bl spi_config_grp0（GICD_IGROUPR bit=0 = Group 0）
- msr daifclr,#1（开 FIQ，PSTATE.F）
- 向量标签 curr_el_spx_fiq_vector: b gic_fiq_handler_grp0（用 IAR0/EOIR0，isr bit6=FIQ）

## 3. spi_basic_group1s.S（Secure Group 1）

差异：
- bl gic_init_grp1s（GICD EnableGrp1S）
- bl spi_config_1s（IGROUP=1, IGRPMOD=1 = Secure Group 1）
- 仍走 curr_el_spx_irq_vector / gic_irq_handler_grp1（Secure Group1 在安全 EL 也以 IRQ 形式）
- EL3 (bootcode 默认安全态)

## 4. spi_priority.S（优先级覆盖）

在 spi_config_ns 之后额外：
~~~
        mov     x0,#SPI_INTID
        mov     x1,#0x40
        bl      spi_set_prio
~~~
spi_config_ns 默认设 0x80；这里用 spi_set_prio 覆盖成 0x40（更高优先级）。
结合 ICC_PMR 可验证优先级掩码（PMR<优先级 的不投递）。

## 5. spi_level.S（电平敏感）

就是 spi_config_ns（默认电平）。代码与 basic 相同；区别在 testbench 契约：
电平型必须 IAR 后、EOIR 前 de-assert 信号，否则 EOIR 后重新 pending。

## 6. spi_edge.S（边沿触发）

在 spi_config_ns 之后：
~~~
        mov     x0,#SPI_INTID
        bl      spi_set_edge
~~~
spi_set_edge 把 GICD_ICFGR 对应 2 bit 设为 0b10（边沿）。testbench 给一个有效
脉冲即可（边沿 pending 在被 activate 时清除）。

## 7. spi_preempt.S（抢占）

最复杂。LO（INTID 32, prio 0x80）先被处理，handler 里注入 HI（INTID 33,
prio 0x40）抢占。

~~~
        bl      gic_init_grp1ns
        msr     ICC_BPR1_EL1,xzr              // BPR=0：任意优先级差都可抢占
~~~
ICC_BPR1=0 让全部优先级位参与抢占判定。

~~~
        // config LO: group NS, prio 0x80, level, enable
        mov     x0,#LO_ID
        bl      spi_set_group_ns
        mov     x0,#LO_ID
        mov     x1,#0x80
        bl      spi_set_prio
        mov     x0,#LO_ID
        bl      spi_set_level
        mov     x0,#LO_ID
        bl      spi_enable
        // config HI: 同上但 prio 0x40
~~~
用单字段 API 分别配 LO（prio 0x80）和 HI（prio 0x40），都 NS Group1、电平、使能。

~~~
        ldr     x1,=gic_expected_intid
        mov     x2,#LO_ID
        str     x2,[x1]                       // expected = LO
        ldr     x1,=preempt_seen
        str     xzr,[x1]                      // 清 seen 标志
        mov     x0,#LO_ID
        bl      spi_set_pend                  // 注入 LO（自注入，不需 testbench）
~~~
expected 存 LO；清抢占标志；用 spi_set_pend 注入 LO（GICD_ISPENDRn）。注意
preempt 是自注入（spi_set_pend），不依赖 testbench。

~~~
curr_el_spx_irq_vector:
        bl      gic_ack_grp1                  // x0 = INTID
        mov     x9,x0
        cmp     x9,#HI_ID
        b.eq    hi_path
~~~
handler 用 gic_ack_grp1 读 INTID。先到的应是 LO；若是 HI（嵌套进入）走 hi_path。

LO 路径：
~~~
        ldr     x1,=preempt_lo_id
        str     x9,[x1]                       // 存 LO INTID 到内存（跨嵌套保留）
        msr     daifclr,#2                    // 开 IRQ 让 HI 能抢占
        mov     x0,#HI_ID
        bl      spi_set_pend                  // 注入 HI -> 抢占
        dsb     sy
1:      ldr     x1,=preempt_seen              // 自旋等 HI 跑完
        ldr     x2,[x1]
        cmp     x2,#1
        b.ne    1b
        ldr     x0,=preempt_lo_id
        ldr     x0,[x0]                       // 取回 LO INTID
        bl      gic_eoi_grp1                  // 结束 LO
        cmp     x0,#LO_ID
        b.ne    test_fail
        b       test_pass
~~~
LO handler：存 INTID 到内存（寄存器会被嵌套破坏）；开 IRQ；注入 HI（抢占发生，
跳 hi_path）；自旋等 preempt_seen=1（HI 跑完）；取回 LO INTID；gic_eoi_grp1 结束
LO；校验后 test_pass。

HI 路径（嵌套）：
~~~
hi_path:
        ldr     x1,=preempt_seen
        mov     x2,#1
        str     x2,[x1]                       // 标记 HI 已跑
        mov     x0,x9
        bl      gic_eoi_grp1                  // 结束 HI
        eret                                  // 返回 LO handler
~~~
HI handler：置 preempt_seen=1；gic_eoi_grp1 结束 HI；eret 返回被抢占的 LO handler
（LO 的自旋随后检测到 seen=1，继续 EOIR LO）。

数据：preempt_seen / preempt_lo_id（内存标志，跨嵌套保留）。

## 小结

| case | 关键点 |
|------|--------|
| basic_group1ns | NS Group1，IRQ，spi_config_ns 全套 |
| basic_group0 | Group0，FIQ，IAR0/EOIR0 |
| basic_group1s | Secure Group1，spi_config_1s |
| priority | spi_set_prio 覆盖优先级 |
| level | 电平（默认），testbench IAR 后 de-assert |
| edge | spi_set_edge 边沿，一个脉冲 |
| preempt | 双优先级抢占，自注入，嵌套 handler+eret |
