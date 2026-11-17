`ifndef CPU_DEBUG_LP_ACCESS_DBG_RECOV_CORE_TEST_SV
`define CPU_DEBUG_LP_ACCESS_DBG_RECOV_CORE_TEST_SV

class cpu_debug_lp_access_dbg_recov_core_test
    extends cpu_debug_lp_access_base_test;
    `uvm_component_utils(cpu_debug_lp_access_dbg_recov_core_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        state_name  = "DBG_RECOV";
        target_name = "core";
        set_cluster_index(0);
    endfunction

endclass

`endif
