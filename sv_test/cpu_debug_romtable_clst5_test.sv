`ifndef CPU_DEBUG_ROMTABLE_CLST5_TEST_SV
`define CPU_DEBUG_ROMTABLE_CLST5_TEST_SV

//----------------------------------------------------------------------
// clst5 debugblock ROM table access test
//
// dbg_address_mapping.xlsx / apb_tree_cpu (m18):
//   clst5_debugblock_romtable  external view 0x4BC8_0000, 2.5M block
//   parent romtable_apbic entry 0x1A8_0003
// ROM table layout: see clst0 test header.
//----------------------------------------------------------------------

class cpu_debug_romtable_clst5_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_romtable_clst5_test)

    localparam bit [31:0] CLST_BASE = 32'h4BC8_0000;

    bit [31:0] rd_data;
    bit [31:0] entry_val;
    bit [31:0] entry0_val;
    bit [31:0] comp_base;
    int        n_entry;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        aw_seen = 1; // debug domain test, cpu does not need to run main.cpp
        `uvm_info("clst5_romtable", "begin", UVM_LOW)

        // ROM table CIDR signature
        DBG_GETREG32(CLST_BASE + 32'hFF0, temp_data);
        `uvm_info("clst5_romtable", $sformatf("CIDR0 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h0D)
            `uvm_error("clst5_romtable", $sformatf("CIDR0 = %h, expected x0D", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFF4, temp_data);
        `uvm_info("clst5_romtable", $sformatf("CIDR1 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h10)
            `uvm_error("clst5_romtable", $sformatf("CIDR1 = %h, expected x90", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFF8, temp_data);
        `uvm_info("clst5_romtable", $sformatf("CIDR2 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h05)
            `uvm_error("clst5_romtable", $sformatf("CIDR2 = %h, expected x05", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFFC, temp_data);
        `uvm_info("clst5_romtable", $sformatf("CIDR3 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'hB1)
            `uvm_error("clst5_romtable", $sformatf("CIDR3 = %h, expected xB1", temp_data))

        // PIDR / DEVID, log only
        DBG_GETREG32(CLST_BASE + 32'hFE0, temp_data);
        `uvm_info("clst5_romtable", $sformatf("PIDR0 = %h", temp_data), UVM_LOW)
        DBG_GETREG32(CLST_BASE + 32'hFE4, temp_data);
        `uvm_info("clst5_romtable", $sformatf("PIDR1 = %h", temp_data), UVM_LOW)
        DBG_GETREG32(CLST_BASE + 32'hFE8, temp_data);
        `uvm_info("clst5_romtable", $sformatf("PIDR2 = %h", temp_data), UVM_LOW)
        DBG_GETREG32(CLST_BASE + 32'hFEC, temp_data);
        `uvm_info("clst5_romtable", $sformatf("PIDR3 = %h", temp_data), UVM_LOW)
        DBG_GETREG32(CLST_BASE + 32'hFD0, temp_data);
        `uvm_info("clst5_romtable", $sformatf("PIDR4 = %h", temp_data), UVM_LOW)
        DBG_GETREG32(CLST_BASE + 32'hFC8, temp_data);
        `uvm_info("clst5_romtable", $sformatf("DEVID = %h", temp_data), UVM_LOW)

        // ROM table entries 0..11
        n_entry    = 0;
        entry0_val = 32'h0;
        for (int e = 0; e < 12; e++) begin
            rd_data = CLST_BASE + e * 4;
            DBG_GETREG32(rd_data, entry_val);
            if (entry_val == 32'h0) begin
                `uvm_info("clst5_romtable", $sformatf("entry[%0d] = end marker", e), UVM_LOW)
                break;
            end
            if (e == 0) entry0_val = entry_val;
            n_entry++;
            `uvm_info("clst5_romtable",
                      $sformatf("entry[%0d] = %08h -> component 0x%08h",
                                e, entry_val,
                                CLST_BASE + ({{12{entry_val[31]}}, entry_val[31:12]} << 12)), UVM_LOW)
            if (entry_val[1:0] != 2'b11)
                `uvm_error("clst5_romtable", $sformatf("entry[%0d] = %08h, PRESENT is not 0b11", e, entry_val))
        end
        `uvm_info("clst5_romtable", $sformatf("valid entries = %0d", n_entry), UVM_LOW)

        // follow entry0 to the first component of the cluster debugblock
        if (entry0_val[1:0] != 2'b11) begin
            `uvm_error("clst5_romtable", "entry0 not present, cluster debugblock path broken")
        end
        else begin
            comp_base = CLST_BASE + ({{12{entry0_val[31]}}, entry0_val[31:12]} << 12);
            DBG_GETREG32(comp_base + 32'hFF0, rd_data);
            `uvm_info("clst5_romtable", $sformatf("comp 0x%08h CIDR0 = %h", comp_base, rd_data), UVM_LOW)
            if (rd_data[7:0] != 8'h0D)
                `uvm_error("clst5_romtable", $sformatf("comp CIDR0 = %h, expected x0D", rd_data))

            DBG_GETREG32(comp_base + 32'hFF4, rd_data);
            `uvm_info("clst5_romtable",
                      $sformatf("comp CIDR1 = %h (class %h, 1=romtable 9=coresight)",
                                rd_data, rd_data[7:4]), UVM_LOW)
            if (rd_data[7:0] != 8'h90)
                `uvm_error("clst5_romtable", $sformatf("comp CIDR1 = %h, expected x90", rd_data))

            DBG_GETREG32(comp_base + 32'hFE0, rd_data);
            `uvm_info("clst5_romtable", $sformatf("comp PIDR0 = %h", rd_data), UVM_LOW)
        end

        `uvm_info("clst5_romtable", "done", UVM_LOW)
    endtask

endclass

`endif
