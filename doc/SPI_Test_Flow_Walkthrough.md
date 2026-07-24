# SPI 中断测试流程详解（严格按 spi_basic_group1ns.S 逐行讲解）

本文严格对照 spi/spi_basic_group1ns.S 的实际代码，从第一条指令到最后一条，逐步
讲解一个 Non-secure Group 1 SPI 中断用例在干什么。每一步都给出对应代码并解释
寄存器/bit 含义。

## 0. 这段代码在干什么（整体）

配置一个 SPI（默认 INTID 32）为 Non-secure Group 1、电平触发、路由到本核，使能
它；然后本核进 WFI 挂起；由 testbench 把 SPI 输入信号拉有效，GIC 把该 SPI 置
pending 并唤醒本核；中断处理程序读 IAR 应答、写 EOIR 结束、校验 INTID 正确后
报 PASS。下面逐步对照代码。

## 1. 使能 GICD 的 Non-secure Group 1

~~~
    bl gic_dist_enable_grp1ns
~~~
调用公共子程序（见 common/gic_common.S）：在 GICD_CTLR 把 bit[1] EnableGrp1NS
置 1，允许 Non-secure Group 1 中断被分发；写后轮询 GICD_CTLR.RWP（bit[31]）到 0
等写生效。GIC-700 的 ARE（亲和路由）固定为 1，不用单独配。

## 2. 唤醒本核 Redistributor

~~~
    bl gicr_wake
~~~
SPI 经 GICD 分发后最终送到本核 Redistributor。gicr_wake 把 GICR_WAKER.
ProcessorSleep（bit[1]）写 0 让本核 Redistributor 上线，轮询 ChildrenAsleep
（bit[2]）==0 确认 GIC-CPU 接口总线就绪。必须在配 CPU 接口之前做。

## 3. 使能 CPU 接口

~~~
    bl cpu_if_init_grp1
~~~
- ICC_SRE_EL1.SRE（bit[0]）=1：允许用系统寄存器（ICC_*_EL1）访问 CPU 接口。
- ICC_PMR_EL1=0xFF：优先级掩码，0xFF=放行全部优先级。
- ICC_IGRPEN1_EL1（bit[0]）=1：使能 Group 1 中断信号送到本核。

## 4. 取 GICD 基址

~~~
    LOAD_GICD(x0)        // 即 ldr x0, =GICD_BASE
~~~
x0 = Distributor 基地址（在 common/gic_common.h 里定义为 GICD_BASE，需按你的
SoC 地址表填）。后面所有 GICD 寄存器访问都以 x0 为基址。

## 5. 分组：GICD_IGROUPRn（置 Group 1）

~~~
    ldr w1, [x0, #SPI_IGROUPR_OFF(SPI_INTID)]
    orr w1, w1, #SPI_BIT(SPI_INTID)
    str w1, [x0, #SPI_IGROUPR_OFF(SPI_INTID)]
~~~
SPI 每 32 个 INTID 共用一个 GICD_IGROUPRn（n=INTID/32）。读出该寄存器，把本 SPI
对应 bit 置 1（=Group 1），写回。这是经典的 读-改-写。

## 6. 分组修饰：GICD_IGRPMODRn（定为 Non-secure Group 1）

~~~
    ldr w1, [x0, #(GICD_IGRPMODRn + SPI_BANK(SPI_INTID)*4)]
    bic w1, w1, #SPI_BIT(SPI_INTID)
    str w1, [x0, #(GICD_IGRPMODRn + SPI_BANK(SPI_INTID)*4)]
~~~
IGROUPR=1 配合 IGRPMODR：bit=0 -> Non-secure Group 1；bit=1 -> Secure Group 1。
这里把对应 bit 清 0，定为 Non-secure Group 1（-> IRQ）。若 GICD_CTLR.DS=1（单安
全态）此寄存器 RAZ/WI。

## 7. 优先级：GICD_IPRIORITYRn

~~~
    mov w1, #PRIO_DEFAULT      // 0x80
    strb w1, [x0, #SPI_IPRIORITYR_OFF(SPI_INTID)]
~~~
每个 INTID 一个字节优先级（0x00 最高，0xFF 最低）。写 0x80（中等）。strb 是字节
写。

## 8. 触发方式：GICD_ICFGRn（电平）

~~~
    ldr w1, [x0, #SPI_ICFGR_OFF(SPI_INTID)]
    bic w1, w1, #(3 << SPI_ICFGR_SHIFT(SPI_INTID))   // 0b00 = level
    str w1, [x0, #SPI_ICFGR_OFF(SPI_INTID)]
~~~
每个 INTID 占 2 bit：0b00=电平敏感，0b10=边沿触发。这里把本 SPI 的 2 bit 清成
0b00（电平）。

## 9. 路由：GICD_IROUTERn（路由到本核，IRM=0）

~~~
    // route to this PE: Aff0/Aff1/Aff2 = MPIDR[23:0]; Aff3 = MPIDR[39:32] -> IROUTER[39:32] (bfi); IRM[31]=0 (specific PE)
    mrs x2, mpidr_el1
    and x3, x2, #0xFFFFFF
    ubfx x4, x2, #32, #8
    bfi x3, x4, #32, #8
    str x3, [x0, #SPI_IROUTER_OFF(SPI_INTID)]
~~~
GICD_IROUTER 字段：Aff0[7:0] Aff1[15:8] Aff2[23:16] Aff3[39:32]，IRM（bit[31]）
=0=路由到这个指定 PE（=1 则 1-of-N 任意 PE）。代码从本核 MPIDR 取：低 24 位
（Aff0/Aff1/Aff2）直接用，Aff3 在 MPIDR[39:32]、用 ubfx 取出再 bfi 放到
IROUTER[39:32]。IRM 留 0，所以这个 SPI 发给本核自己。

## 10. 使能：GICD_ISENABLERn

~~~
    mov w1, #SPI_BIT(SPI_INTID)
    str w1, [x0, #SPI_ISENABLER_OFF(SPI_INTID)]
~~~
把本 SPI 对应 bit 置 1 使能它。到这里 SPI 配置全部完成。

## 11. 进 WFI 等 testbench 注入（关键：需要你的环境配合）

~~~
    // ===== TESTBENCH INJECTION POINT =====
    // ...testbench 把 SPI 输入信号拉有效...
    bl wfi_wait_irq
~~~
wfi_wait_irq（见 common/gic_common.S）：先 dsb sy（保证前面所有寄存器写对 GIC
可见），再 msr daifclr, #2 清 PSTATE.I（开 IRQ），然后 wfi 挂起。

**就在这里，需要你的 testbench 把 SPI 输入信号（接到 SPI Collator 的那根线）拉
到有效电平**，GIC 才会把该 SPI 置 pending 并唤醒本核：
- 电平型：拉有效后，要等处理程序读 IAR 之后再 de-assert，否则 EOIR 之后会重新
  pending。
- 边沿型：给一个有效脉冲即可。
- 不想用 testbench 也可以：往 GICD_SETSPI_NSR 写 INTID（消息触发），或写
  GICD_ISPENDRn 直接置 pending。

## 12. 中断处理程序入口

~~~
    .global curr_el_spx_irq_vector
curr_el_spx_irq_vector:
    ldr x0, =core_sync1
    bl core_synchronisation
~~~
中断被取后，PE 跳到当前异常级别的 IRQ 向量 curr_el_spx_irq_vector（由测试框架的
向量表跳过来）。先 ldr 取一个同步变量地址 core_sync1，调 core_synchronisation
做核间同步（框架提供，沿用 ARM wfi.s 用例的约定）。

## 13. 应答：读 ICC_IAR1_EL1

~~~
    mrs x3, ICC_IAR1_EL1
~~~
读中断应答寄存器，返回被取走中断的 INTID（存 x3），同时该中断状态机推进
（pending -> active）。这是 告诉 GIC 我收到了。

## 14. 结束：写 ICC_EOIR1_EL1

~~~
    msr ICC_EOIR1_EL1, x3
~~~
把刚应答的 INTID 写回 EOI 寄存器，完成 priority drop + deactivation
（EOImode=0 时二合一）。这表示我处理完了。

## 15. 校验 INTID

~~~
    mov w2, #SPI_INTID
    cmp w3, w2
    b.ne spi_fail
~~~
比较收到的 INTID（x3）和配置的 SPI_INTID，不一致就跳 spi_fail 报失败。

## 16. 等 IRQ 信号撤销

~~~
1:  mrs  x21, isr_el1
    tbnz x21, #7, 1b
~~~
读 ISR_EL1（中断状态寄存器），bit[7]=IRQ。如果还是 1（IRQ 仍有效）就循环等，直到
IRQ 撤销。对电平中断，这依赖 testbench 在 IAR 之后 de-assert 了信号。

## 17. 校验本核就是预期跑这个用例的核

~~~
    mrs x0, mpidr_el1
    ubfx x0, x0, #0, #16
    adr x1, exec_pe_var
    ldr w2, [x1]
    cmp x0, x2
    bne end_wfi
~~~
取本核 MPIDR 低 16 位，和框架变量 exec_pe_var（预期执行该用例的 PE 号）比较；不
符就跳 end_wfi（不报结果）。这是沿用 wfi.s 的多核用例约定，确保只在指定核上报。

## 18. 报结果

~~~
    bl report_pass
spi_fail:
    bl report_fail
end_wfi:
    b end_wfi
~~~
校验全过则 report_pass（调框架 end_test 打印 PASS 并结束仿真）；否则 spi_fail 走
report_fail。end_wfi 是个死循环，防止 end_test 万一返回。

## 19. 数据

~~~
    .balign 8
core_sync1: .word 0
    .end
~~~
core_sync1 是第 12 步 core_synchronisation 用的同步变量（4 字节，初值 0）。

## 20. 可调项

- 默认 SPI_INTID=32，编译时用 -DSPI_INTID=<n> 覆盖（n 在 32~1019）。
- GICD_BASE / GICR_RD_BASE 必须按你的 SoC 地址表填（common/gic_common.h）。
- 想测边沿看 spi/spi_edge.S；优先级/掩码看 spi/spi_priority.S；抢占看
  spi/spi_preempt.S；Group 0（FIQ）看 spi/spi_basic_group0.S。
