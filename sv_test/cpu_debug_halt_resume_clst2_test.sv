`ifndef CPU_DEBUG_HALT_RESUME_CLST2_TEST_SV
`define CPU_DEBUG_HALT_RESUME_CLST2_TEST_SV

class cpu_debug_halt_resume_clst2_test extends cpu_debug_halt_resume_base_test;
    `uvm_component_utils(cpu_debug_halt_resume_clst2_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(2);
    endfunction

    virtual task test_body();
        aw_seen = 1; // debug-domain test; CPU main.cpp is not required.
        `uvm_info("clst2_pwrup", "begin", UVM_LOW)

        bakdoor_set_svt_mem(); // Pre-load Trickbox + svt mem data
        cluster_crg_init(6'b000100);
        rvbar_init(6'b000100);
        cluster_crg_rst_init(6'b000100);
        wait(cpu_vif.debug_pwr_qacceptn[2] == 1);
        #0.5us;

        `uvm_info("clst2_haltresume", "begin", UVM_LOW)
        run_halt_resume();
    endtask

endclass

`endif
