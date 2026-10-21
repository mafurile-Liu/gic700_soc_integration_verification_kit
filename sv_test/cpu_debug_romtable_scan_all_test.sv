`ifndef CPU_DEBUG_ROMTABLE_SCAN_ALL_TEST_SV
`define CPU_DEBUG_ROMTABLE_SCAN_ALL_TEST_SV

//----------------------------------------------------------------------
// Dedicated scan for high-address decode in all CPU clusters.
//
// The independent clst0..5 ROM table tests already check each DebugBlock
// ROM table CIDR/entry.  This test only exercises the upper cluster-
// internal address range: DSU-120 TRM Table 16-2/16-3 places PE3 CTI at
// +0x270000, the highest CTI page in a four-core cluster block.
//----------------------------------------------------------------------

class cpu_debug_romtable_scan_all_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_romtable_scan_all_test)

    localparam bit [31:0] CPU_TREE_BASE = 32'h4B00_0000;
    localparam bit [31:0] CLST_STRIDE   = 32'h0028_0000;
    localparam int        N_CLST        = 6;
    // DSU-120 TRM Table 16-2/16-3: PE3 CTI is at the high end of a
    // four-core cluster debugblock. PIDR0/PIDR1 are at +0xFE0/+0xFE4.
    localparam bit [31:0] PE3_CTI_OFFSET = 32'h0027_0000;

    bit [31:0] clst_base;
    bit [31:0] rd_data;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        aw_seen = 1; // debug domain test, cpu does not need to run main.cpp
        `uvm_info("romtable_scan", "begin high-address decode scan", UVM_LOW)

        for (int c = 0; c < N_CLST; c++) begin
            clst_base = CPU_TREE_BASE + c * CLST_STRIDE;

            // Exercise the high-address decode inside the cluster block.
            DBG_GETREG32(clst_base + PE3_CTI_OFFSET + 32'hFE0, rd_data);
            `uvm_info("romtable_scan",
                      $sformatf("clst%0d PE3 CTI @ %08h PIDR0 = %h",
                                c, clst_base + PE3_CTI_OFFSET, rd_data), UVM_LOW)
            if (rd_data[7:0] != 8'h81)
                `uvm_error("romtable_scan",
                           $sformatf("clst%0d PE3 CTI PIDR0 = %h, expected x81",
                                     c, rd_data))

            DBG_GETREG32(clst_base + PE3_CTI_OFFSET + 32'hFE4, rd_data);
            `uvm_info("romtable_scan",
                      $sformatf("clst%0d PE3 CTI @ %08h PIDR1 = %h",
                                c, clst_base + PE3_CTI_OFFSET, rd_data), UVM_LOW)
            if (rd_data[7:0] != 8'hBD)
                `uvm_error("romtable_scan",
                           $sformatf("clst%0d PE3 CTI PIDR1 = %h, expected xBD",
                                     c, rd_data))
        end

        `uvm_info("romtable_scan", "done high-address decode scan", UVM_LOW)
    endtask

endclass

`endif
