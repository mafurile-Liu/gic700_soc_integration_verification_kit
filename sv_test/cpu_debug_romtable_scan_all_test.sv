`ifndef CPU_DEBUG_ROMTABLE_SCAN_ALL_TEST_SV
`define CPU_DEBUG_ROMTABLE_SCAN_ALL_TEST_SV

//----------------------------------------------------------------------
// Scan all 6 CPU cluster debugblock ROM tables in one test.
//
// dbg_address_mapping.xlsx / apb_tree_cpu (m18):
//   clst0..5_debugblock_romtable @ 0x4B00_0000 + n * 0x28_0000 (2.5M)
// Shared components behind the same tree (logged for reference):
//   atb_funnel_128 0x4BF0_0000, atb_funnel_64 0x4BF0_1000,
//   cti_pmu        0x4BF0_2000
//
// Per cluster: CIDR0..3 signature check + entry0 read.
//----------------------------------------------------------------------

class cpu_debug_romtable_scan_all_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_romtable_scan_all_test)

    localparam bit [31:0] CPU_TREE_BASE = 32'h4B00_0000;
    localparam bit [31:0] CLST_STRIDE   = 32'h0028_0000;
    localparam int        N_CLST        = 6;

    bit [31:0] clst_base;
    bit [31:0] rd_data;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        aw_seen = 1; // debug domain test, cpu does not need to run main.cpp
        `uvm_info("romtable_scan", "begin", UVM_LOW)

        for (int c = 0; c < N_CLST; c++) begin
            clst_base = CPU_TREE_BASE + c * CLST_STRIDE;

            DBG_GETREG32(clst_base + 32'hFF0, rd_data); // CIDR0
            `uvm_info("romtable_scan",
                      $sformatf("clst%0d @ %08h CIDR0 = %h", c, clst_base, rd_data), UVM_LOW)
            if (rd_data[7:0] != 8'h0D)
                `uvm_error("romtable_scan", $sformatf("clst%0d CIDR0 = %h, expected x0D", c, rd_data))

            DBG_GETREG32(clst_base + 32'hFF4, rd_data); // CIDR1
            `uvm_info("romtable_scan", $sformatf("clst%0d CIDR1 = %h", c, rd_data), UVM_LOW)
            if (rd_data[7:0] != 8'h10)
                `uvm_error("romtable_scan", $sformatf("clst%0d CIDR1 = %h, expected x10", c, rd_data))

            DBG_GETREG32(clst_base + 32'hFF8, rd_data); // CIDR2
            if (rd_data[7:0] != 8'h05)
                `uvm_error("romtable_scan", $sformatf("clst%0d CIDR2 = %h, expected x05", c, rd_data))

            DBG_GETREG32(clst_base + 32'hFFC, rd_data); // CIDR3
            if (rd_data[7:0] != 8'hB1)
                `uvm_error("romtable_scan", $sformatf("clst%0d CIDR3 = %h, expected xB1", c, rd_data))

            DBG_GETREG32(clst_base, rd_data); // entry0
            `uvm_info("romtable_scan",
                      $sformatf("clst%0d entry0 = %08h", c, rd_data), UVM_LOW)
            if (!rd_data[0])
                `uvm_error("romtable_scan", $sformatf("clst%0d entry0 not present", c))
        end

        // shared components of apb_tree_cpu, log only
        DBG_GETREG32(32'h4BF0_0000 + 32'hFF0, rd_data);
        `uvm_info("romtable_scan", $sformatf("atb_funnel_128 CIDR0 = %h", rd_data), UVM_LOW)
        DBG_GETREG32(32'h4BF0_1000 + 32'hFF0, rd_data);
        `uvm_info("romtable_scan", $sformatf("atb_funnel_64   CIDR0 = %h", rd_data), UVM_LOW)
        DBG_GETREG32(32'h4BF0_2000 + 32'hFF0, rd_data);
        `uvm_info("romtable_scan", $sformatf("cti_pmu         CIDR0 = %h", rd_data), UVM_LOW)

        `uvm_info("romtable_scan", "done", UVM_LOW)
    endtask

endclass

`endif
