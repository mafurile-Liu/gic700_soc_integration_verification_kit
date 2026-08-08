# SPI Scan Test Guide

## 目的

一次仿真覆盖全部 960 个 SPI 中断口（INTID 32..991），验证每个 SPI 都能被
配置、注入、应答、结束，不遗漏任何一个口。这是接口覆盖率的兜底用例。

## 架构

.S 侧（跑在 A720 RTL 上）和 UVM 侧（跑在 testbench 外部）锁步循环：

~~~
.S (spi_scan.S)                     UVM (gic_int_scan_seq)
-----------------------             -----------------------
for INTID = 32 to 991:              for INTID = 32 to 991:
  config SPI(INTID)                   wait TB_READY == 1
  write TB_READY = 1                  (backdoor poll)
  WFI <------------------------------- inject SPI(INTID)
  [handler: ack/eoi/check]            wait TB_READY == 0
  write TB_RESULT(0/1)                (backdoor poll)
  clear TB_READY = 0                  read TB_RESULT
  next INTID                          check pass/fail
                                     next INTID
test_pass                          report summary
~~~

### 握手协议（backdoor poll，不用 AXI monitor）

1. .S 写 TB_READY_ADDR(0x274F_0540) = 1，然后 WFI。
2. UVM backdoor poll TB_READY_ADDR 直到读到 1 -> 知道 PE 到了 WFI。
3. UVM driver 注入 spi_int_in[INTID]（电平，hold 100 周期）。
4. GIC pending -> PE 被 WFI 唤醒 -> handler：ack(IAR1) + eoi(EOIR1) +
   比对 expected INTID + 写 TB_RESULT_ADDR(0x274F_0544) = 0(pass)/1(fail)。
5. handler eret 返回 .S 循环，.S 写 TB_READY_ADDR = 0（清除，表示本轮完成）。
6. UVM backdoor poll TB_READY_ADDR 直到读到 0 -> 读 TB_RESULT -> 判 pass/fail。
7. 下一轮 INTID。

### 为什么用 backdoor poll 不用 AXI monitor

- AXI monitor 需要挂总线、解析协议，复杂且依赖具体 AXI VIP。
- backdoor poll 直接读 slave VIP 的内存（bypass AXI 事务），简单、确定、
  与总线协议无关。slave VIP（如 Synopsys axi_slave_svt）建模的内存可直接
  backdoor peek。
- TODO：具体 backdoor API 取决于你用的 slave VIP，我在 driver/sequence 里留了
  stub（wait_tb_ready_clear / read_tb_result），你定了 VIP 后填上即可。

## .S 文件

spi/spi_scan.S：
- 循环 INTID 32..991。
- 每轮：spi_config_ns(INTID) -> 	b_notify_ready -> WFI -> handler
  (gic_ack_grp1 + gic_eoi_grp1 + 比对 + 写 TB_RESULT) -> eret ->
  清 TB_READY -> 下一轮。
- 全部通过后 	est_pass。
- handler 是自定义的（不用 gic_irq_handler_grp1，因为那个会 WFE 自旋结束，
  scan 需要返回循环）。

## UVM 文件

| 文件 | 作用 |
|------|------|
| tb/sequences/gic_int_scan_seq.sv | scan 序列：循环 32..991，每轮注入+poll 结果 |
| tests/gic_spi_scan_test.sv | UVM test：跑 scan 序列 |
| tb/gic_int_agent.sv | agent 全部代码（item+sequencer+driver+agent） |



## 运行

~~~
vcs +UVM_TESTNAME=gic_spi_scan_test -f filelist/gic_int.f +UVM_NO_RELNOTS
  (filelist 只含 3 个文件: gic_int_if.sv + gic_int_agent.sv + gic_spi_scan_test.sv)
~~~
（需接入 A720 RTL + GIC-700 RTL + slave VIP，替换 gic_int_top 里的占位。）

## 覆盖率

scan 跑完后，覆盖率模型（gic_int_coverage，待加）应显示 SPI_INTID 32..991
全部命中。交叉覆盖（INTID x group/trigger/priority）后续补充。

## SPI 输出方向（CPU 子系统产生 -> 核外）

interface 里有 spi_int_out（GIC/CPU -> 外部）。monitor 会观测这个方向的活动
（gic_int_monitor 里已实现 spi_int_out 的检测）。driver 不驱动输出方向
（DIR_OUTPUT 时 drive_item 直接 return）。等你确定了 RTL 怎么产生输出方向
的中断，我再加对应的激励/检查。

## 限制

1. backdoor poll 是 stub（TODO：接你的 slave VIP）。
2. scoreboard/coverage 待加（当前只有 sequence 里的 pass/fail 检查）。
3. PPI scan 类似（改 int_type=PPI + pe_id + 范围 16..31/1056..1087）。
4. LPI scan 更复杂（需要 ITS 配置），单独用例。
