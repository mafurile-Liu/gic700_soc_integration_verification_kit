// gic_macros.h - convenience macros for GIC-700 tests.
#ifndef GIC_MACROS_H
#define GIC_MACROS_H
#include "gic_reg.h"
#define LOAD_GICD(rd)      ldr rd, =GICD_BASE
#define LOAD_GICR(rd)      ldr rd, =GICR_RD_BASE
#define LOAD_GITS(rd)      ldr rd, =GITS_BASE
#define LOAD_GICR_SGI(rd)  ldr rd, =GICR_SGI_BASE
#define INTID_BIT(n)       (1 << (n))
#define ICFGR_PPI_SHIFT(n) (2 * ((n) - 16))
#define ICFGR_BANK_SHIFT(n)(2 * ((n) % 16))
#define ICFGR_LEVEL  0x0
#define ICFGR_EDGE   0x2
#define SPI_BANK(n)           ((n) / 32)
#define SPI_BIT(n)            (1 << ((n) % 32))
#define SPI_IGROUPR_OFF(n)    (GICD_IGROUPRn   + SPI_BANK(n)*4)
#define SPI_ISENABLER_OFF(n)  (GICD_ISENABLERn + SPI_BANK(n)*4)
#define SPI_ICENABLER_OFF(n)  (GICD_ICENABLERn + SPI_BANK(n)*4)
#define SPI_ISPENDR_OFF(n)    (GICD_ISPENDRn   + SPI_BANK(n)*4)
#define SPI_ICPENDR_OFF(n)    (GICD_ICPENDRn   + SPI_BANK(n)*4)
#define SPI_IPRIORITYR_OFF(n) (GICD_IPRIORITYRn + (n))
#define SPI_ICFGR_OFF(n)      (GICD_ICFGRn + ((n)/16)*4)
#define SPI_ICFGR_SHIFT(n)    (2 * ((n) % 16))
#define SPI_IROUTER_OFF(n)    (GICD_IROUTERn + (n)*8)
#define PRIO_DEFAULT  0x80
#endif
