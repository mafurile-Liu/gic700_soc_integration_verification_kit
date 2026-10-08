`ifndef CPU_DEBUG_HALT_RESUME_CLST1_TEST_SV
`define CPU_DEBUG_HALT_RESUME_CLST1_TEST_SV

class cpu_debug_halt_resume_clst1_test extends cpu_debug_halt_resume_base_test;
    `uvm_component_utils(cpu_debug_halt_resume_clst1_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(1);
    endfunction

endclass

`endif
