# GIC Test Case Guide

所有用例基于 common/gic_common.S（核心）+ gic_its.S（ITS/LPI）的成熟 API。basic 用例 ~25 行。

| File | What it verifies |
|------|------------------|
| ppi/ppi_basic_group0.S | PPI Group0 (FIQ), ppi_config_grp0 |
| ppi/ppi_basic_group1s.S | PPI Secure Group1, ppi_config_1s |
| ppi/ppi_basic_group1ns.S | PPI NS Group1 (IRQ), ppi_config_ns |
| ppi/ppi_priority.S | PPI 优先级覆盖 (ppi_set_prio) |
| ppi/ppi_level.S | PPI 电平（默认），testbench IAR 后 de-assert |
| ppi/ppi_edge.S | PPI 边沿 (ppi_set_edge) |
| ppi/ppi_preempt.S | PPI 抢占（双优先级，嵌套 handler+eret） |
| spi/spi_basic_group0.S | SPI Group0 (FIQ), spi_config_grp0 |
| spi/spi_basic_group1s.S | SPI Secure Group1, spi_config_1s |
| spi/spi_basic_group1ns.S | SPI NS Group1 (IRQ), spi_config_ns |
| spi/spi_priority.S | SPI 优先级覆盖 (spi_set_prio) |
| spi/spi_level.S | SPI 电平 |
| spi/spi_edge.S | SPI 边沿 (spi_set_edge) |
| spi/spi_preempt.S | SPI 抢占 |
| sgi/sgi_basic_group0/1s/1ns.S | SGI 各组（GICR_ISPENDR0 自注入） |
| sgi/sgi_broadcast.S | SGI 广播 (ICC_SGI1R IRM=1，多核) |
| sgi/sgi_affinity.S | SGI 亲和定向 (ICC_SGI1R IRM=0 打给自己) |
| lpi/lpi_basic.S | LPI via ITS 全流程：MAPD/MAPC/MAPTI/SYNC + LPI config + INV + INT 命令触发，LPI 专用 FIQ handler（IAR0 1020 -> IAR1） |
| lpi/lpi_priority.S | LPI 优先级：config 表 byte = (prio & 0xFC) | enable，priority=0x40 |
| lpi/lpi_basic.S | LPI via ITS 全流程：MAPD/MAPC/MAPTI/SYNC + LPI config + INV + INT 命令触发，LPI 专用 FIQ handler（IAR0 1020 -> IAR1） |
| vsgi/vsgi_basic.S | vSGI (GICv4.1)：VMAPP/VSYNC + VSGI 命令配置 + GITS_SGIR 注入 |

组约定：Group0->FIQ（IAR0/EOIR0, curr_el_spx_fiq_vector, daifclr#1）；Group1->IRQ
（IAR1/EOIR1, curr_el_spx_irq_vector, daifclr#2）。SPI 在 GICD 配；PPI/SGI 在 GICR SGI_base
帧（RD_base+0x10000）；API 内部运行时算 bank/bit，测试只传 INTID。

详细 SPI 流程见 doc/SPI_Test_Flow_Walkthrough.md（全 7 case 逐行讲解）。
