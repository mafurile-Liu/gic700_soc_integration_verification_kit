# Bootcode Reference (bootcode.s)

bootcode.s 是 ARM A720 交付的验证环境 boot 代码，作为本项目的永久参考。

## Boot 流程
1. EL3 启动，初始化寄存器/栈/MMU/NEON/向量表(vbar_el3=vbar_el2=vbar_el1=vector_table)。
2. 调 `enable_fiq_intr`: DAIFClr #0xF + SCR_EL3.IRQ=1,FIQ=1,NS=0。所有中断路由到 EL3。
3. 从 tube(0x13000000+0x20) 读 exec_pe_var，选执行 PE。
4. 只有 EXEC_PE 跳 `test_start`，其余 WFI。

## Tube 地址映射 (0x13000000)
- 0x00: tube 数据输出（end_test 写消息）
- 0x08: trickbox 中断调度（wfi.s 用）
- 0x10: trickbox 中断清除
- 0x20: exec_pe_var（PE 选择）
- 0x30: powered PE count（core_synchronisation 读）
- 0x40: TB_READY_ADDR（我们的测试同步邮箱）
- 0x44: TB_RESULT_ADDR（scan 用逐 INTID 结果）

## 框架函数（bootcode 提供，全局 .global）
- `end_test`(x1=msg): 写消息到 tube + WFI spin。测试结束的唯一方式。
- `core_synchronisation`(x0=sync_var): 多 PE 同步。
- `exec_pe_var`: 全局变量，当前执行 PE 的 affinity。
- `enable_fiq_intr`(): DAIFClr #0xF + SCR_EL3 路由。

## 我们的测试如何对接
- test_pass/test_fail: 调 `bl end_test` 传 pass/fail 消息（不再用 x0+wfe）。
- handler: 开头调 `core_synchronisation`（和 wfi.s 一致）。
- TB_READY/TB_RESULT: 在 0x13000040/44（tube 区域内，slave VIP 可 backdoor poll）。
- daifclr: 冗余但保留（bootcode 已 DAIFClr，但防御性保留）。
