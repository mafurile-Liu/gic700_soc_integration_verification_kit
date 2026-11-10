// CPU subsystem ECT agent package.
package cpu_ect_agent_pkg;
  import uvm_pkg::*;

  typedef uvm_sequencer #(cpu_ect_item) cpu_ect_sequencer;

  `include "uvm_macros.svh"
  `include "cpu_ect_types.svh"
  `include "cpu_ect_cfg.svh"
  `include "cpu_ect_item.sv"
  `include "cpu_ect_driver.svh"
  `include "cpu_ect_monitor.svh"
  `include "cpu_ect_expectation.svh"
  `include "cpu_ect_scoreboard.svh"
  `include "cpu_ect_agent.svh"
endpackage