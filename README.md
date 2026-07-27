# GIC-700 SoC Integration Verification Kit

GIC-700 中断验证用例（汇编，AArch64 GNU as），面向 SoC 集成验证（如 ZJ100
SYS_CPU：24x Cortex-A720，GIC-700 + 6x GCI + ITS）。基于 common/ 成熟 API，
每个用例 ~25 行。

## 结构
~~~
common/   gic_reg.h, gic_macros.h, gic_common.h, gic_common.S
          （成熟 GIC API：init/config/ack/eoi/default-handler/pass-fail）
ppi/      PPI 用例（testbench force 信号）
spi/      SPI 用例（testbench force 信号）
sgi/      SGI 用例（GICR_ISPENDR0 自注入；ICC_SGI1R 软件生成）
lpi/      LPI 用例（ITS：MAPD/MAPC/MAPI/INV/SYNC + GITS_TRANSLATER）
vlpi/     虚拟 LPI（GICv4）骨架
vsgi/     虚拟 SGI（GITS_SGIR）骨架
doc/      Architecture_Reference, Register_Reference, Verification_Flow,
          GIC_TestCase_Guide, SPI_Test_Flow_Walkthrough
examples/ example_makefile.md, porting_to_arm_delivery.md
~~~

## API（common/gic_common.S）
- Bring-up：gic_init_grp1ns / grp1s / grp0（一次调用：GICD+GICR+CPU 接口）
- 配置：ppi_config_ns/grp0/1s、spi_config_ns/grp0/1s（运行时算 bank/bit）
- 单字段：ppi/spi_set_group_*、set_prio、set_level/set_edge、enable、set_pend、
  route_self
- 应答：gic_ack_grp1/grp0、gic_eoi_grp1/grp0
- 默认 handler：gic_curr_el_spx_irq_vector_grp1/grp0（ack+eoi+校验+pass/fail）
- 结果：test_pass（end_test）/ test_fail（end_test）

## 典型用例（~25 行）
~~~
test_start:
        bl      gic_init_grp1ns
        ldr     x1,=gic_expected_intid
        mov     x2,#SPI_INTID
        str     x2,[x1]
        mov     x0,#SPI_INTID
        bl      spi_config_ns
        dsb     sy
        isb
        msr     daifclr,#2
wait_loop:
        wfi
        b       wait_loop
curr_el_spx_irq_vector:
        b       gic_curr_el_spx_irq_vector_grp1
~~~

## 编译检查
~~~
clang --target=aarch64-linux-gnu -c <file>.S -Icommon -o NUL
~~~
（或 aarch64-none-elf-gcc -c）。全 24 个 .S 编译通过（clang 18.1.8 验证）。

## TODO（上板前）
- common/gic_common.h 填 GICD_BASE / GICR_RD_BASE / GITS_BASE（ZJ100 地址表）
- PPI INTID 对齐 Cortex-A720 TRM（默认 CNTV=27）
- LPI 的 ITS 命令字节编码对照 IHI0069 ch5

## 参考
- Arm CoreLink GIC-700 TRM (101516_0400_12_en)
- GIC Architecture Spec (IHI0069) —— 见 doc/Architecture_Reference.md（项目长期记忆）
- doc/SPI_Test_Flow_Walkthrough.md（SPI 全 7 case 逐行讲解）
