# Porting to the ARM bare-metal delivery

This kit mirrors the structure of ARM's WFI example (wfi.s): 	est_start entry,
curr_el_spx_irq_vector / curr_el_spx_fiq_vector handlers, core_synchronisation,
end_test, and exec_pe_var. To port:

1. Vector table: ensure the delivery's vector table routes current-EL SPx IRQ/FIQ
   to the symbols defined in the tests (curr_el_spx_irq_vector / _fiq_vector).
2. Framework symbols: provide end_test(const char*), core_synchronisation(u32*),
   and exec_pe_var. (Same contract as wfi.s.)
3. Base addresses: set GICD_BASE / GICR_RD_BASE / GITS_BASE in common/gic_common.h
   or via -D on the compile line. Multi-PE: each PE uses its own GICR_RD_BASE.
4. SPI/PPI injection: the original wfi.s used the trickbox (0x13000000) to drive
   nFIQ directly. For PPI/SPI you instead force the GIC input signal from the
   testbench (the contract is documented at the top of each PPI/SPI test).
5. LPI: needs DDR table memory; assign LPI_PROP_BASE / LPI_PEND_BASE / ITS_*_BASE
   and verify ITS command encodings (IHI0069 ch5).
