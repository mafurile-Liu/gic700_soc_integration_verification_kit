`ifndef CPU_ECT_TESTLIST_SVH
`define CPU_ECT_TESTLIST_SVH

// Include this list in the external CPU test package after
// cpu_base_test/cpu_debug_base_test are compiled.
`include "cpu_ect_base_test.sv"
`include "cpu_ect_eventin_test.sv"
`include "cpu_ect_evtout0_15_test.sv"
`include "cpu_ect_evtout18_dbm_test.sv"

`endif