# CPU Debug Tests

Tests for the 6 CPU cluster debugblock ROM tables on the ZJ100 debug APB
tree. Every test extends `cpu_debug_base_test` and follows its
`test_body` convention from the existing cpu debug tests:
`aw_seen = 1`, then `DBG_GETREG32` / `DBG_SETREG32` accesses with
`uvm_info` logging.

Address source: `dbg_address_mapping.xlsx`, sheet "Address Mapping",
`apbic_sys_dbg expander1` / `m18 apb_tree_cpu`.

## Address map (external debug view)

| item | base | size | parent rom_entry |
| --- | --- | --- | --- |
| clst0_debugblock_romtable | 0x4B00_0000 | 2.5M | 0xE0_0003 |
| clst1_debugblock_romtable | 0x4B28_0000 | 2.5M | 0x108_0003 |
| clst2_debugblock_romtable | 0x4B50_0000 | 2.5M | 0x130_0003 |
| clst3_debugblock_romtable | 0x4B78_0000 | 2.5M | 0x158_0003 |
| clst4_debugblock_romtable | 0x4BA0_0000 | 2.5M | 0x180_0003 |
| clst5_debugblock_romtable | 0x4BC8_0000 | 2.5M | 0x1A8_0003 |
| atb_funnel_128 | 0x4BF0_0000 | 4K | 0x1D0_0003 |
| atb_funnel_64 | 0x4BF0_1000 | 4K | 0x1D0_1003 |
| cti_pmu | 0x4BF0_2000 | 4K | 0x1D0_2003 |

Cluster stride is 0x28_0000; after clst5 the tree continues with the
gpu / npu0..5 / ddr0..8 / isp / pcie / dpu / mipi / ufs / usb_dp / vpu /
peri sub-trees (0x4BF0_4000..0x4BF2_D000), then STM (AXI, 0x4C00_0000)
and sys_dbg func_apb syscfg/dbm/iniu (0x4D00_0000..).

## ROM table page layout (4K at each block base)

| offset | register | note |
| --- | --- | --- |
| 0x000..0x7FC | entry0..entry511 | bit0 = present, 0x0 = end marker |
| 0xFC8 | DEVID | |
| 0xFD0 | PIDR4 | |
| 0xFE0..0xFEC | PIDR0..PIDR3 | |
| 0xFF0..0xFFC | CIDR0..CIDR3 | ROM table signature 0x0D 0x90 0x05 0xB1 |

Each valid entry points at a component inside the same 2.5M debugblock
(core debug units, CTI, PMU, ETM, ...). The tests log the resolved
component address of every entry, then follow entry0 and read that
component's own CIDR/PIDR0 to prove the ROM table path is live.

## Files

| file | what it does |
| --- | --- |
| cpu_debug_romtable_clst0_test.sv | full walk of clst0 ROM table + entry0 component |
| cpu_debug_romtable_clst1_test.sv | same for clst1 |
| cpu_debug_romtable_clst2_test.sv | same for clst2 |
| cpu_debug_romtable_clst3_test.sv | same for clst3 |
| cpu_debug_romtable_clst4_test.sv | same for clst4 |
| cpu_debug_romtable_clst5_test.sv | same for clst5 |
| cpu_debug_romtable_scan_all_test.sv | one pass over all 6 clusters + shared funnels/cti_pmu |
| cpu_debug_halt_resume_base_test.sv | shared ROM-walk/CTI halt-resume sequence |
| cpu_debug_halt_resume_clst0_test.sv | halt and resume one A720 core in clst0 |
| cpu_debug_halt_resume_clst1_test.sv | halt and resume one A720 core in clst1 |
| cpu_debug_halt_resume_clst2_test.sv | halt and resume one A720 core in clst2 |
| cpu_debug_halt_resume_clst3_test.sv | halt and resume one A720 core in clst3 |
| cpu_debug_halt_resume_clst4_test.sv | halt and resume one A720 core in clst4 |
| cpu_debug_halt_resume_clst5_test.sv | halt and resume one A720 core in clst5 |
| cpu_debug_halt_resume_scan_all_test.sv | halt and resume one A720 core in all 6 clusters |

## Usage

Copy the files next to `cpu_debug_base_test.sv` in the cpu tests
directory. To compile all tests at once, include the testlist from the
cpu test package (after the base tests):

```systemverilog
package cpu_test_pkg;
    import uvm_pkg::*;
    `include "cpu_base_test.sv"
    `include "cpu_debug_base_test.sv"
    `include "cpu_debug_romtable_testlist.svh"
endpackage
```

Select with the usual `+UVM_TESTNAME=cpu_debug_romtable_clst0_test`
or `+UVM_TESTNAME=cpu_debug_halt_resume_clst0_test` etc. Each test only
needs `cpu_debug_base_test` (temp_data), `aw_seen` from the base test,
and the `DBG_GETREG32` / `DBG_SETREG32` macros from the existing debug
env.

The halt/resume tests locate the first core debug component and first
core CTI through the cluster ROM table, configure CTI output triggers
0/1 to channel 0, and poll `EDPRSR.HALTED`.  They require the target
core to be powered and released from reset before starting.

If the DBG address window in the testbench maps the cluster blocks at a
different base than the external view above, only `CLST_BASE` (or
`CPU_TREE_BASE`) needs changing; all offsets stay the same.
