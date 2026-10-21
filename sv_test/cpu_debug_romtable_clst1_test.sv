`ifndef CPU_DEBUG_ROMTABLE_CLST1_TEST_SV
`define CPU_DEBUG_ROMTABLE_CLST1_TEST_SV

//----------------------------------------------------------------------
// clst1 debugblock ROM table access test
//
// dbg_address_mapping.xlsx / apb_tree_cpu (m18):
//   clst1_debugblock_romtable  external view 0x4B28_0000, 2.5M block
//   parent romtable_apbic entry 0x108_0003
// ROM table layout: see clst0 test header.
//----------------------------------------------------------------------

class cpu_debug_romtable_clst1_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_romtable_clst1_test)

    localparam bit [31:0] CLST_BASE = 32'h4B28_0000;

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
        `uvm_info("clst1_romtable", "begin", UVM_LOW)
        bakdoor_set_svt_mem(); // Pre-load Trickbox + svt mem data
        cluster_crg_init(6'b000010);
        rvbar_init(6'b000010);
        cluster_crg_rst_init(6'b000010);
        wait(cpu_vif.debug_pwr_qacceptn[1] == 1);
        #0.5us;

        // ROM table CIDR signature
        DBG_GETREG32(CLST_BASE + 32'hFF0, temp_data);
        `uvm_info("clst1_romtable", $sformatf("CIDR0 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h0D)
            `uvm_error("clst1_romtable", $sformatf("CIDR0 = %h, expected x0D", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFF4, temp_data);
        `uvm_info("clst1_romtable", $sformatf("CIDR1 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h90)
            `uvm_error("clst1_romtable", $sformatf("CIDR1 = %h, expected x90", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFF8, temp_data);
        `uvm_info("clst1_romtable", $sformatf("CIDR2 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h05)
            `uvm_error("clst1_romtable", $sformatf("CIDR2 = %h, expected x05", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFFC, temp_data);
        `uvm_info("clst1_romtable", $sformatf("CIDR3 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'hB1)
            `uvm_error("clst1_romtable", $sformatf("CIDR3 = %h, expected xB1", temp_data))

        // DSU-120 r2p1 DebugBlock ROM table identity:
        //   full PID = 0x04003BB4E9, PART = 0x4E9, designer JEP106 = 0x3B.
        // The per-core ROM table of A720 TRM Table 17-2 differs
        // (PART 0xD81, PIDR 0x04200BBD81). REVISION / REVAND / CMOD /
        // SIZE are revision fields and are logged only.
        DBG_GETREG32(CLST_BASE + 32'hFE0, temp_data);
        `uvm_info("clst1_romtable", $sformatf("PIDR0 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'hE9)
            `uvm_error("clst1_romtable", $sformatf("PIDR0 = %h, expected xE9 (PART_0)", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFE4, temp_data);
        `uvm_info("clst1_romtable", $sformatf("PIDR1 = %h", temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'hB4)
            `uvm_error("clst1_romtable", $sformatf("PIDR1 = %h, expected xB4 (DES_0=B PART_1=4)", temp_data))

        DBG_GETREG32(CLST_BASE + 32'hFE8, temp_data);
        `uvm_info("clst1_romtable", $sformatf("PIDR2 = %h (REVISION %h)", temp_data, temp_data[7:4]), UVM_LOW)
        if (temp_data[7:0] != 8'h3B)
            `uvm_error("clst1_romtable", $sformatf("PIDR2[7:0] = %h, expected x3B (REVISION=3, JEDEC=1, DES_1=3)", temp_data[7:0]))

        DBG_GETREG32(CLST_BASE + 32'hFEC, temp_data);
        `uvm_info("clst1_romtable", $sformatf("PIDR3 = %h (REVAND %h, CMOD %h)", temp_data, temp_data[7:4], temp_data[3:0]), UVM_LOW)

        DBG_GETREG32(CLST_BASE + 32'hFD0, temp_data);
        `uvm_info("clst1_romtable", $sformatf("PIDR4 = %h (SIZE %h)", temp_data, temp_data[7:4]), UVM_LOW)
        if (temp_data[3:0] != 4'h4)
            `uvm_error("clst1_romtable", $sformatf("PIDR4[3:0] = %h, expected h4 (DES_2)", temp_data[3:0]))

        DBG_GETREG32(CLST_BASE + 32'hFC8, temp_data);
        `uvm_info("clst1_romtable",
                  $sformatf("DEVID = %h (PRR %h, SYSMEM %h, FORMAT %h)",
                            temp_data, temp_data[5], temp_data[4], temp_data[3:0]), UVM_LOW)
        if (temp_data[5:0] != 6'h20)
            `uvm_error("clst1_romtable",
                       $sformatf("DEVID[5:0] = %h, expected x20 (PRR=1, SYSMEM=0, FORMAT=0)",
                                 temp_data[5:0]))

        // ROM table entries 0..11
        n_entry    = 0;
        entry0_val = 32'h0;
        for (int e = 0; e < 12; e++) begin
            rd_data = CLST_BASE + e * 4;
            DBG_GETREG32(rd_data, entry_val);
            if (entry_val == 32'h0) begin
                `uvm_info("clst1_romtable", $sformatf("entry[%0d] = end marker", e), UVM_LOW)
                break;
            end
            if (e == 0) entry0_val = entry_val;
            n_entry++;
            `uvm_info("clst1_romtable",
                      $sformatf("entry[%0d] = %08h -> component 0x%08h",
                                e, entry_val,
                                CLST_BASE + ({{12{entry_val[31]}}, entry_val[31:12]} << 12)), UVM_LOW)
            if (entry_val[1:0] != 2'b11)
                `uvm_error("clst1_romtable", $sformatf("entry[%0d] = %08h, PRESENT is not 0b11", e, entry_val))
        end
        `uvm_info("clst1_romtable", $sformatf("valid entries = %0d", n_entry), UVM_LOW)

        // follow entry0 to the first component of the cluster debugblock
        if (entry0_val[1:0] != 2'b11) begin
            `uvm_error("clst1_romtable", "entry0 not present, cluster debugblock path broken")
        end
        else begin
            comp_base = CLST_BASE + ({{12{entry0_val[31]}}, entry0_val[31:12]} << 12);
            DBG_GETREG32(comp_base + 32'hFF0, rd_data);
            `uvm_info("clst1_romtable", $sformatf("comp 0x%08h CIDR0 = %h", comp_base, rd_data), UVM_LOW)
            if (rd_data[7:0] != 8'h0D)
                `uvm_error("clst1_romtable", $sformatf("comp CIDR0 = %h, expected x0D", rd_data))

            DBG_GETREG32(comp_base + 32'hFF4, rd_data);
            `uvm_info("clst1_romtable",
                      $sformatf("comp CIDR1 = %h (class %h, 1=romtable 9=coresight)",
                                rd_data, rd_data[7:4]), UVM_LOW)
            if (rd_data[7:0] != 8'h90)
                `uvm_error("clst1_romtable", $sformatf("comp CIDR1 = %h, expected x90", rd_data))

            DBG_GETREG32(comp_base + 32'hFE0, rd_data);
            `uvm_info("clst1_romtable", $sformatf("comp PIDR0 = %h", rd_data), UVM_LOW)
        end

        `uvm_info("clst1_romtable", "done", UVM_LOW)
    endtask

endclass

`endif
