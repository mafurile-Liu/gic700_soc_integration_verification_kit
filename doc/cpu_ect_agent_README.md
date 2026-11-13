# CPU subsystem ECT agent

This is the CPU-subsystem equivalent of the AON ECT agent.  It follows the
signal map in `ECT_Event_Mapping.xlsx`, sheet `sys_cpu`.

## Scope

- System-level `css600_cti_com`
  - CTI base: `0x4BF0_2000`
  - input triggers 0..9
  - output triggers 0..20
- System `css600_ctm_com`
  - channel 0..15
- CPU-cluster CTI channel views (clusters 0..5, 4 bits each)
- CPU CTM async bridge views

Latest `sys_cpu` mapping has handshake at input trigger 0 and output
triggers 0/1.  Input trigger 9 is level type.  The other mapped triggers are
pulse type.

## Files

| file | purpose |
| --- | --- |
| `tb/interfaces/cpu_ect_if.sv` | flattened injection/observation interface |
| `tb/agents/cpu_dbg_ect_agent/cpu_ect_connect.svh` | DUT hierarchy assigns and plusarg-gated forces |
| `tb/agents/cpu_dbg_ect_agent/cpu_ect_agent_pkg.sv` | UVM agent, monitor, driver, scoreboard |
| `tb/sequences/cpu_ect_seq_pkg.sv` | pulse and level sequences |
| `sv_test/ECT/cpu_ect_testlist.svh` | CPU ECT regression test list |
| `sv_test/ECT/cpu_ect_eventin_test.sv` | input trigger 0 handshake, 1..8 pulse, 9 level -> channel traversal |
| `sv_test/ECT/cpu_ect_evtout0_15_test.sv` | channel -> output 0..15 traversal |
| `sv_test/ECT/cpu_ect_evtout16_20_test.sv` | channel0..4 -> CTI output16..20 |

## TB integration

Instantiate the interface inside `tb_top` and set the virtual interface to the
agent created by `cpu_ect_base_test`:

~~~systemverilog
cpu_ect_if cpu_ect_if(.clk(cpu_clk), .clk_evt_axi(axi_mon_clk), .rst_n(tb_rst_n));

initial begin
    uvm_config_db#(virtual cpu_ect_if)::set(
        null, "*", "ect_vif", cpu_ect_if);
end
~~~

Include the connect file inside `tb_top` after the interface instance.
The DUT hierarchy is controlled by `` `CPU_ECT_DUT_HIER ``.  The default is
`tb_top.u_dut`; define a different hierarchy before the include if needed.

~~~systemverilog
// `define CPU_ECT_DUT_HIER tb_top.u_dut_soc_cpu
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
    `include "sv_test/ECT/cpu_ect_testlist.svh"
endpackage
~~~

## Current cases

| test | route |
| --- | --- |
| `cpu_ect_eventin_test` | CTI input trigger 0..9 -> channel 0..9 |
| `cpu_ect_evtout0_15_test` | cp2cp 0..15 -> system CTI channel 0..15 -> CTI output trigger 0..15 |
| `cpu_ect_evtout16_20_test` | cp2cp 0..4 -> system CTI channel 0..4 -> CTI output trigger 16..20 |
| `cpu_ect_clusters_chin_test` | all 6 clusters CTICHOUT channel0..3 -> system CTI channel-in and cp2cp pulse-in |
| `cpu_ect_clusters_chout_ch0_test` to `cpu_ect_clusters_chout_ch3_test` | one case per cp2cp channel 0..3 -> all 6 clusters CTICHIN/CTICHINACK and system CTI channel-in |
The clusters case assumes a cluster channel n is visible as system-CTI channel n and cp2cp channel n.  If the SoC integration uses a different channel translation, update that test to the actual mapping.

## Mapping notes

Latest system CTI channel paths are `u_css600_cti_com.event_out[15:0]` (CTI -> CTM)
and `u_css600_cti_com.event_in[15:0]` (CTM -> CTI).
