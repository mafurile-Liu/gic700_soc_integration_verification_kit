`ifndef CPU_DEBUG_HALT_RESUME_CLST4_TEST_SV
`define CPU_DEBUG_HALT_RESUME_CLST4_TEST_SV

class cpu_debug_halt_resume_clst4_test extends cpu_debug_halt_resume_base_test;
    `uvm_component_utils(cpu_debug_halt_resume_clst4_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(4);
    endfunction

endclass

`endif
