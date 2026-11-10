`ifndef CPU_ECT_TESTLIST_SVH
`define CPU_ECT_TESTLIST_SVH

import uvm_pkg::*;
import cpu_ect_agent_pkg::*;
import cpu_ect_seq_pkg::*;

// Include this list in the external CPU test package after
// cpu_base_test/cpu_debug_base_test are compiled.
`include "cpu_ect_base_test.sv"
`include "cpu_ect_eventin_test.sv"
`include "cpu_ect_evtout0_15_test.sv"
`include "cpu_ect_evtout18_dbm_test.sv"
`include "cpu_ect_clst0_chin_to_syscti_test.sv"
`include "cpu_ect_asyncbridge_chin_to_syscti_test.sv"

`endif
