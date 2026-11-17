`ifndef CPU_DEBUG_LP_ACCESS_OFF_EMU_CORE_TEST_SV
`define CPU_DEBUG_LP_ACCESS_OFF_EMU_CORE_TEST_SV

class cpu_debug_lp_access_off_emu_core_test
    extends cpu_debug_lp_access_base_test;
    `uvm_component_utils(cpu_debug_lp_access_off_emu_core_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        state_name  = "OFF_EMU";
        target_name = "core";
        set_cluster_index(0);
    endfunction

endclass

`endif
