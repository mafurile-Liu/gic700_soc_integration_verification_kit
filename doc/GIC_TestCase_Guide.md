# GIC Test Case Guide

| File | What it verifies |
|------|------------------|
| ppi/ppi_basic_group0.S | PPI delivery as Group 0 (FIQ), force-injected |
| ppi/ppi_basic_group1s.S | PPI as Secure Group 1 |
| ppi/ppi_basic_group1ns.S | PPI as Non-secure Group 1 (IRQ) |
| ppi/ppi_priority.S | PPI priority vs ICC_PMR mask |
| ppi/ppi_level.S | Level-sensitive PPI state machine |
| ppi/ppi_edge.S | Edge-triggered PPI |
| ppi/ppi_preempt.S | PPI preemption (low-prio preempted by high-prio) |
| spi/spi_basic_group0/1s/1ns.S | SPI delivery per group, routed to this PE |
| spi/spi_priority.S | SPI priority vs ICC_PMR |
| spi/spi_level.S / spi_edge.S | SPI level / edge |
| spi/spi_preempt.S | SPI preemption |
| sgi/sgi_basic_group0/1s/1ns.S | SGI delivery per group (GICR_ISPENDR0 inject) |
| sgi/sgi_broadcast.S | SGI broadcast concept (ICC_SGI1R IRM=1) |
| sgi/sgi_affinity.S | SGI affinity targeting concept |
| lpi/lpi_basic.S | LPI via ITS (MAPD/MAPC/MAPI/INV/SYNC + GITS_TRANSLATER) |
| lpi/lpi_priority.S | LPI priority (Property table byte) |
| vlpi/vlpi_basic.S | Virtual LPI (GICv4) skeleton |
| vsgi/vsgi_basic.S | vSGI direct injection (GITS_SGIR) |

Group conventions: Group 0 -> FIQ (ICC_IAR0/EOIR0, fiq vector, isr bit6);
Group 1 -> IRQ (ICC_IAR1/EOIR1, irq vector, isr bit7). Secure Group 1 must run at
a Secure EL. SPI/PPI/SGI are per-bank: SPI in GICD, PPI/SGI in the GICR SGI_base
frame (RD_base + 0x10000).
