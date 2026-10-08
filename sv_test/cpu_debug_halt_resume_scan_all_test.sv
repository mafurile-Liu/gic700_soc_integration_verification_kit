`ifndef CPU_DEBUG_HALT_RESUME_SCAN_ALL_TEST_SV
`define CPU_DEBUG_HALT_RESUME_SCAN_ALL_TEST_SV

class cpu_debug_halt_resume_scan_all_test extends cpu_debug_halt_resume_base_test;
    `uvm_component_utils(cpu_debug_halt_resume_scan_all_test)

    virtual task test_body();
        aw_seen = 1;
        for (int c = 0; c < N_CLST; c++) begin
            set_cluster_index(c);
            run_halt_resume();
        end
    endtask

endclass

`endif
