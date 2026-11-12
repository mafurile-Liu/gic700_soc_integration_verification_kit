`ifndef CPU_DEBUG_CORE_RESET_DBG_ACCESS_SCAN_ALL_TEST_SV
`define CPU_DEBUG_CORE_RESET_DBG_ACCESS_SCAN_ALL_TEST_SV

class cpu_debug_core_reset_dbg_access_scan_all_test
    extends cpu_debug_core_reset_dbg_access_base_test;
    `uvm_component_utils(cpu_debug_core_reset_dbg_access_scan_all_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass

`endif
