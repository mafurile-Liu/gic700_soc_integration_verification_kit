//----------------------------------------------------------------------
// cpu_debug_romtable_testlist.svh
//
// Testlist for the 6 CPU cluster debugblock ROM table and
// halt/resume tests.
// Include this file from the cpu test package to compile all of them:
//
//   package cpu_test_pkg;
//       import uvm_pkg::*;
//       `include "cpu_base_test.sv"          // must come first
//       `include "cpu_debug_base_test.sv"    // must come before testlist
//       `include "cpu_debug_romtable_testlist.svh"
//   endpackage
//
// Requirements:
//   - +incdir must cover the directory holding these files
//   - cpu_base_test / cpu_debug_base_test (aw_seen, temp_data)
//     must be compiled before this list
//   - DBG_GETREG32 / DBG_SETREG32 macros visible (debug env)
//
// Every file below has its own `ifndef guard, so repeated inclusion
// is safe. Select a test with +UVM_TESTNAME=<class_name>.
//----------------------------------------------------------------------

`ifndef CPU_DEBUG_ROMTABLE_TESTLIST_SVH
`define CPU_DEBUG_ROMTABLE_TESTLIST_SVH

`include "cpu_debug_romtable_clst0_test.sv"
`include "cpu_debug_romtable_clst1_test.sv"
`include "cpu_debug_romtable_clst2_test.sv"
`include "cpu_debug_romtable_clst3_test.sv"
`include "cpu_debug_romtable_clst4_test.sv"
`include "cpu_debug_romtable_clst5_test.sv"
`include "cpu_debug_romtable_scan_all_test.sv"
`include "cpu_debug_halt_resume_base_test.sv"
`include "cpu_debug_halt_resume_clst0_test.sv"
`include "cpu_debug_halt_resume_clst1_test.sv"
`include "cpu_debug_halt_resume_clst2_test.sv"
`include "cpu_debug_halt_resume_clst3_test.sv"
`include "cpu_debug_halt_resume_clst4_test.sv"
`include "cpu_debug_halt_resume_clst5_test.sv"
`include "cpu_debug_halt_resume_scan_all_test.sv"

`endif
