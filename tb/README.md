# GIC Testbench Agent (tb/)

本目录是中断注入 testbench agent（SystemVerilog），配合 common/ 的 .S 测试用。
目的：在 PE（A720）跑到 WFI 时精确注入中断，并自动判定 pass/fail。

## 方案：怎么做到 跑到某条指令就打中断进来

不用指令级单步，而是用**软件-testbench 握手（mailbox）**，确定且与核模型无关：

1. .S 测试在 WFI 之前执行 bl tb_notify_ready，它往 TB_READY_ADDR(0x1000_0000)
   写 1（经 AXI）。
2. testbench 的 tb_mailbox_slave（挂在那个地址的 AXI-Lite 从）检测到这次写，
   拉一个 pe_ready 脉冲。
3. gic_injector 一直在等 pe_ready；收到脉冲就立即把 spi_int[spi_id] 拉有效
   （按 hold_cycles 保持，再 de-assert）。
4. 于是中断精确打在测试跑到 WFI 前的 notify 指令那一刻——因为测试自己用一条
   AXI 写明确告诉了 testbench我到注入点了。

这样不需要核内部 WFI 信号，也不依赖具体核模型；测试在哪条指令注入完全由 .S 控制。

## SV test case 怎么结束 + 判 pass/fail

1. .S 的 test_pass / test_fail 往 TB_RESULT_ADDR(0x1000_0004) 写 0(pass)/1(fail)，
   然后 WFE 自旋。
2. tb_mailbox_slave 检测到这次写，拉 test_done 脉冲 + 记录 test_result。
3. gic_scoreboard 看到 test_done：result==0 打印 PASS，否则 FAIL，然后 $finish。
4. 看门狗：若 TIMEOUT_CYC 内没收到结果（中断没送达/测试挂死），打印
   FAIL(timeout) 并 $finish。

## 组件

| 文件 | 作用 |
|------|------|
| gic_tb_pkg.sv | 共享常量（地址、N_SPI、超时） |
| gic_intv_if.sv | 中断注入接口（spi_int + 同步/结果信号） |
| tb_mailbox_slave.sv | AXI-Lite 从，解码 READY/RESULT 写 -> 脉冲 |
| gic_injector.sv | pe_ready 触发，按 hold_cycles 驱动 spi_int |
| gic_scoreboard.sv | 读结果判 pass/fail + 看门狗 + $finish |
| gic_tb_top.sv | 顶层：时钟/复位、接口、mailbox、注入器、计分板、DUT/A720 占位 |
| tb_files.f | 编译顺序 |

## 编译顺序
~~~
vcs -f tb_files.f   （或按 tb_files.f 顺序编译）
~~~

## 接真实环境
gic_tb_top 里有两处占位需替换：
- GIC-700 DUT：把 intv.spi_int 接到 GIC SPI Collator 输入；GIC AXI 从接到 A720 AXI
  主（这样 .S 能经 AXI 配 GICD/GICR）。
- A720：把 gic_tb_top 里的 A720 stub（initial 块模拟 mailbox 写）换成真实 A720 核
  模型，它执行 .S 测试、AXI 口驱动 mailbox slave（TB_READY/TB_RESULT 写）+ GIC。
  mailbox slave / 注入器 / 计分板 保持不变。

## .S 侧配合（已在 common/ 做好）
- common/gic_common.h：TB_READY_ADDR / TB_RESULT_ADDR。
- common/gic_common.S：tb_notify_ready()（写 TB_READY_ADDR）；test_pass/test_fail
  写 TB_RESULT_ADDR(0/1) 再 WFE 自旋。
- 所有测试 WFI 前已插入 bl tb_notify_ready。

## 自检
无 SV 仿真器时，用 tb/sv_check2.py 做括号/配对平衡自检（已通过：大括号/小括号/
方括号/begin-end/case-endcase/module-endmodule 全平衡）。接 VCS/Xcelium 后可直接
编译验证语法。
