`ifndef CPU_DEBUG_HALT_RESUME_CLST1_TEST_SV
`define CPU_DEBUG_HALT_RESUME_CLST1_TEST_SV

class cpu_debug_halt_resume_clst1_test extends cpu_debug_halt_resume_base_test;
    `uvm_component_utils(cpu_debug_halt_resume_clst1_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(1);
    endfunction

    virtual task test_body();
        aw_seen = 1; // debug-domain test; CPU main.cpp is not required.
        `uvm_info("clst1_pwrup", "begin", UVM_LOW)

        bakdoor_set_svt_mem(); // Pre-load Trickbox + svt mem data
        cluster_crg_init(6'b000010);
        rvbar_init(6'b000010);
        cluster_crg_rst_init(6'b000010);
        wait(cpu_vif.debug_pwr_qacceptn[1] == 1);
        #0.5us;

        `uvm_info("clst1_haltresume", "begin", UVM_LOW)
        run_halt_resume();
    endtask

endclass

`endif
