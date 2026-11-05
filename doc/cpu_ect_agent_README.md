# CPU subsystem ECT agent

This is the CPU-subsystem equivalent of the AON ECT agent.  It follows the
signal map in `ECT_Event_Mapping.xlsx`, sheet `sys_cpu`.

## Scope

- System-level `css600_cti_com`
  - CTI base: `0x4BF0_2000`
  - input triggers 0..11
  - output triggers 0..18
- System `css600_ctm_com`
  - channel 0..15
- CPU-cluster CTI channel views (clusters 0..5, 4 bits each)
- CPU CTM async bridge views

The current `sys_cpu` mapping has no handshake event.  Input trigger 9 is the
only level-type input.  All mapped output triggers are pulse type.

## Files

| file | purpose |
| --- | --- |
| `tb/interfaces/cpu_ect_if.sv` | flattened injection/observation interface |
| `tb/agents/cpu_dbg_ect_agent/cpu_ect_connect.svh` | DUT hierarchy assigns and plusarg-gated forces |
| `tb/agents/cpu_dbg_ect_agent/cpu_ect_agent_pkg.sv` | UVM agent, monitor, driver, scoreboard |
| `tb/sequences/cpu_ect_seq_pkg.sv` | pulse and level sequences |
| `sv_test/cpu_ect_testlist.svh` | CPU ECT regression test list |
| `sv_test/cpu_ect_eventin_test.sv` | input trigger 0..11 -> channel traversal |
| `sv_test/cpu_ect_evtout0_15_test.sv` | channel -> output 0..15 traversal |
| `sv_test/cpu_ect_evtout18_dbm_test.sv` | channel0 -> DBM output18 |

## TB integration

Instantiate the interface inside `tb_top` and set the virtual interface to the
agent created by `cpu_ect_base_test`:

~~~systemverilog
cpu_ect_if cpu_ect_if(.clk(cpu_clk), .rst_n(tb_rst_n));

initial begin
    uvm_config_db#(virtual cpu_ect_if)::set(
        null, "uvm_test_top.agent", "vif", cpu_ect_if);
end
~~~

Include the connect file inside `tb_top` after the interface instance:

~~~systemverilog
`include "cpu_ect_connect.svh"
~~~

For injection runs add:

~~~text
+CPU_ECT_ENABLE_SOURCE_FORCE
~~~

## Test package integration

Include the testlist from the external CPU test package after the normal
CPU debug base classes are available:

~~~systemverilog
package cpu_test_pkg;
    import uvm_pkg::*;
    `include "cpu_base_test.sv"
    `include "cpu_debug_base_test.sv"
    `include "cpu_ect_testlist.svh"
endpackage
~~~

## Current cases

| test | route |
| --- | --- |
| `cpu_ect_eventin_test` | CTI input trigger 0..11 -> channel 0..11 |
| `cpu_ect_evtout0_15_test` | channel 0..15 -> CTI output trigger 0..15 |
| `cpu_ect_evtout18_dbm_test` | channel0 -> CTI output trigger18 / DBM |
| `cpu_ect_clst0_chin_to_syscti_test` | cluster0 channel0..3 -> system CTI channel0..3 |
| `cpu_ect_asyncbridge_chin_to_syscti_test` | async bridge channel0..15 -> system CTI channel0..15 |

The cluster case assumes the 4-bit cluster CTM port maps to system CTI
channels 0..3.  If the SoC integration uses a different channel translation,
update that test to the actual mapping.

## Mapping notes

`sys_cpu` rows 42/43 currently repeat the GPU hierarchy names.  They are not
used by this CPU ECT agent.  The authoritative system CTI channel paths are
rows 12 and 20.
