`ifndef CPU_DEBUG_CORE_RESET_DBG_ACCESS_CLST0_TEST_SV
`define CPU_DEBUG_CORE_RESET_DBG_ACCESS_CLST0_TEST_SV

class cpu_debug_core_reset_dbg_access_clst0_test
    extends cpu_debug_core_reset_dbg_access_base_test;
    `uvm_component_utils(cpu_debug_core_reset_dbg_access_clst0_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(0);
    endfunction

    virtual task test_body();
        run_one_cluster();
    endtask

endclass

`endif
