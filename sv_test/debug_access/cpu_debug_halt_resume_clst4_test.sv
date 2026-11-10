`ifndef CPU_DEBUG_HALT_RESUME_CLST4_TEST_SV
`define CPU_DEBUG_HALT_RESUME_CLST4_TEST_SV

class cpu_debug_halt_resume_clst4_test extends cpu_debug_halt_resume_base_test;
    `uvm_component_utils(cpu_debug_halt_resume_clst4_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(4);
    endfunction

    virtual task test_body();
        aw_seen = 1; // debug-domain test; CPU main.cpp is not required.
        `uvm_info("clst4_pwrup", "begin", UVM_LOW)

        open_clusters_pwr();
        bakdoor_set_svt_mem(); // Pre-load Trickbox + svt mem data
        cluster_crg_init(6'b010000);
        rvbar_init(6'b010000);
        cluster_crg_rst_init(6'b010000);
        wait(cpu_vif.debug_pwr_qacceptn[4] == 1);
        #0.5us;

        `uvm_info("clst4_haltresume", "begin", UVM_LOW)
        run_halt_resume();
    endtask

endclass

`endif
