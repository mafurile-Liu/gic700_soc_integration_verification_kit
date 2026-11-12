`ifndef CPU_DEBUG_CORE_RESET_DBG_ACCESS_BASE_TEST_SV
`define CPU_DEBUG_CORE_RESET_DBG_ACCESS_BASE_TEST_SV

//----------------------------------------------------------------------
// DebugBlock access while the selected cluster's cores stay in reset.
//
// The normal debug cases call cluster_crg_rst_init() to release the
// cores.  This base intentionally does not call that task.  Only the
// DebugBlock ROM table and core CTI (both in the debug power domain)
// are accessed.  The CTI register writes prove that the DebugBlock is
// not only readable but also writable while core reset is held.
//----------------------------------------------------------------------

class cpu_debug_core_reset_dbg_access_base_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_core_reset_dbg_access_base_test)

    localparam bit [31:0] CPU_TREE_BASE       = 32'h4B00_0000;
    localparam bit [31:0] CLST_STRIDE         = 32'h0028_0000;
    localparam int        N_CLST              = 6;
    localparam bit [31:0] CORE0_CTI_OFFSET    = 32'h000F_0000;
    localparam bit [31:0] DBROM_DBGPCR0       = 32'h0000_0A00;
    localparam bit [31:0] DBROM_DBGPSR0       = 32'h0000_0A80;
    localparam bit [31:0] DBROM_POWER_REQUEST = 32'h0000_0002;

    // CoreSight component IDs.
    localparam bit [31:0] CTI_CONTROL   = 32'h000;
    localparam bit [31:0] CTI_OUTEN0    = 32'h0A0;
    localparam bit [31:0] CTI_GATE      = 32'h140;
    localparam bit [31:0] CTI_DEVARCH   = 32'hFBC;
    localparam bit [31:0] CTI_DEVTYPE   = 32'hFCC;
    localparam bit [31:0] CTI_PIDR0     = 32'hFE0;
    localparam bit [31:0] CTI_PIDR1     = 32'hFE4;
    localparam bit [31:0] CTI_PIDR2     = 32'hFE8;
    localparam bit [31:0] CTI_PIDR3     = 32'hFEC;
    localparam bit [31:0] CTI_PIDR4     = 32'hFD0;
    localparam bit [31:0] CTI_DEVID     = 32'hFC8;
    localparam bit [31:0] CTI_CIDR0     = 32'hFF0;
    localparam bit [31:0] CTI_CIDR1     = 32'hFF4;
    localparam bit [31:0] CTI_CIDR2     = 32'hFF8;
    localparam bit [31:0] CTI_CIDR3     = 32'hFFC;

    // DSU-120 r2p1 DebugBlock ROM table identity.
    localparam bit [31:0] DBROM_PIDR0   = 32'hFE0;
    localparam bit [31:0] DBROM_PIDR1   = 32'hFE4;
    localparam bit [31:0] DBROM_PIDR2   = 32'hFE8;
    localparam bit [31:0] DBROM_PIDR3   = 32'hFEC;
    localparam bit [31:0] DBROM_PIDR4   = 32'hFD0;
    localparam bit [31:0] DBROM_DEVID   = 32'hFC8;
    localparam bit [31:0] DBROM_CIDR0   = 32'hFF0;
    localparam bit [31:0] DBROM_CIDR1   = 32'hFF4;
    localparam bit [31:0] DBROM_CIDR2   = 32'hFF8;
    localparam bit [31:0] DBROM_CIDR3   = 32'hFFC;

    localparam bit [31:0] CTI_DEVTYPE   = 32'h0000_0014;
    localparam bit [31:0] CTI_DEVARCH   = 32'h4770_1A14;
    // Do not score the DEVARCH revision nibble.
    localparam bit [31:0] DEVARCH_ID_MASK = 32'hFFF0_FFFF;

    bit [31:0] cluster_base;
    bit [5:0]  cluster_mask;
    bit [31:0] rd_data;
    int        cluster_index;
    string     tag;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(0);
    endfunction

    virtual function void set_cluster_index(int idx);
        cluster_index = idx;
        cluster_mask  = 6'b000001 << idx;
        cluster_base  = CPU_TREE_BASE + idx * CLST_STRIDE;
        tag           = $sformatf("core_reset_dbg_clst%0d", idx);
    endfunction

    protected task expect_reg(string name,
                              bit [31:0] addr,
                              bit [31:0] mask,
                              bit [31:0] expected);
        DBG_GETREG32(addr, rd_data);
        `uvm_info(tag, $sformatf("%s @ %08h = %08h", name, addr, rd_data), UVM_LOW)
        if ((rd_data & mask) != expected)
            `uvm_error(tag, $sformatf("%s = %08h, expected %08h",
                                      name, rd_data & mask, expected))
    endtask

    protected task read_reg(string name, bit [31:0] addr, output bit [31:0] value);
        DBG_GETREG32(addr, value);
        `uvm_info(tag, $sformatf("%s @ %08h = %08h", name, addr, value), UVM_LOW)
    endtask

    protected task write_readback(string name,
                                  bit [31:0] addr,
                                  bit [31:0] value);
        DBG_SETREG32(addr, value);
        DBG_GETREG32(addr, rd_data);
        `uvm_info(tag,
                  $sformatf("%s @ %08h write %08h, readback %08h",
                            name, addr, value, rd_data), UVM_LOW)
        if (rd_data != value)
            `uvm_error(tag, $sformatf("%s readback = %08h, expected %08h",
                                      name, rd_data, value))
    endtask

    protected virtual task check_debugblock(output bit path_ok);
        bit [31:0] cti_base;
        bit [31:0] control_restore;
        bit [31:0] outen0_restore;
        bit [31:0] gate_restore;
        int        wait_count;

        path_ok = 1;
        cti_base = cluster_base + CORE0_CTI_OFFSET;

        // Request DebugBlock power through the DSU Granular Power
        // Requester and confirm the status register is readable.
        DBG_SETREG32(cluster_base + DBROM_DBGPCR0, DBROM_POWER_REQUEST);
        wait_count = 0;
        do begin
            DBG_GETREG32(cluster_base + DBROM_DBGPSR0, rd_data);
            if (rd_data[0] == 1'b1)
                break;
            #100ns;
            wait_count++;
        end while (wait_count < 100);

        if (rd_data[0] != 1'b1) begin
            `uvm_error(tag, "DebugBlock power did not become active")
            path_ok = 0;
            return;
        end

        // DebugBlock ROM table identity.
        expect_reg("DBROM CIDR0", cluster_base + DBROM_CIDR0,
                   32'h0000_00FF, 32'h0000_000D);
        expect_reg("DBROM CIDR1", cluster_base + DBROM_CIDR1,
                   32'h0000_00FF, 32'h0000_0090);
        expect_reg("DBROM CIDR2", cluster_base + DBROM_CIDR2,
                   32'h0000_00FF, 32'h0000_0005);
        expect_reg("DBROM CIDR3", cluster_base + DBROM_CIDR3,
                   32'h0000_00FF, 32'h0000_00B1);
        expect_reg("DBROM PIDR0", cluster_base + DBROM_PIDR0,
                   32'h0000_00FF, 32'h0000_00E9);
        expect_reg("DBROM PIDR1", cluster_base + DBROM_PIDR1,
                   32'h0000_00FF, 32'h0000_00B4);
        expect_reg("DBROM PIDR2", cluster_base + DBROM_PIDR2,
                   32'h0000_00FF, 32'h0000_003B);
        expect_reg("DBROM PIDR4[3:0]", cluster_base + DBROM_PIDR4,
                   32'h0000_000F, 32'h0000_0004);
        expect_reg("DBROM DEVID[5:0]", cluster_base + DBROM_DEVID,
                   32'h0000_003F, 32'h0000_0020);
        read_reg("DBROM PIDR3", cluster_base + DBROM_PIDR3, rd_data);

        // Core0 CTI identity.  This CTI is in the DebugBlock, not the
        // core power domain.
        expect_reg("CTI PIDR0", cti_base + CTI_PIDR0,
                   32'h0000_00FF, 32'h0000_0081);
        expect_reg("CTI PIDR1", cti_base + CTI_PIDR1,
                   32'h0000_00FF, 32'h0000_00BD);
        expect_reg("CTI DEVTYPE", cti_base + CTI_DEVTYPE,
                   32'h0000_00FF, CTI_DEVTYPE);
        expect_reg("CTI DEVARCH", cti_base + CTI_DEVARCH,
                   DEVARCH_ID_MASK, CTI_DEVARCH & DEVARCH_ID_MASK);
        expect_reg("CTI CIDR0", cti_base + CTI_CIDR0,
                   32'h0000_00FF, 32'h0000_000D);
        expect_reg("CTI CIDR1", cti_base + CTI_CIDR1,
                   32'h0000_00FF, 32'h0000_0090);
        expect_reg("CTI CIDR2", cti_base + CTI_CIDR2,
                   32'h0000_00FF, 32'h0000_0005);
        expect_reg("CTI CIDR3", cti_base + CTI_CIDR3,
                   32'h0000_00FF, 32'h0000_00B1);
        read_reg("CTI PIDR2", cti_base + CTI_PIDR2, rd_data);
        read_reg("CTI PIDR3", cti_base + CTI_PIDR3, rd_data);
        read_reg("CTI PIDR4", cti_base + CTI_PIDR4, rd_data);
        read_reg("CTI DEVID", cti_base + CTI_DEVID, rd_data);

        // Prove DebugBlock registers are writable while core reset is
        // held.  Keep CTI disabled while changing OUTEN0.
        read_reg("CTI CONTROL before RW test", cti_base + CTI_CONTROL,
                 control_restore);
        DBG_SETREG32(cti_base + CTI_CONTROL, 32'h0000_0000);

        read_reg("CTI OUTEN0 before RW test", cti_base + CTI_OUTEN0,
                 outen0_restore);
        write_readback("CTI OUTEN0", cti_base + CTI_OUTEN0,
                       outen0_restore ^ 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_OUTEN0, outen0_restore);

        read_reg("CTI GATE before RW test", cti_base + CTI_GATE,
                 gate_restore);
        write_readback("CTI GATE", cti_base + CTI_GATE,
                       gate_restore ^ 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_GATE, gate_restore);

        write_readback("CTI CONTROL", cti_base + CTI_CONTROL,
                       control_restore ^ 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_CONTROL, control_restore);
    endtask

    protected virtual task run_one_cluster();
        bit path_ok;

        aw_seen = 1; // Debug-domain test; CPU main.cpp is not required.
        `uvm_info(tag, "begin; cores stay in reset", UVM_LOW)

        open_clusters_pwr();
        bakdoor_set_svt_mem();

        // Configure the selected cluster clocks, but do not call
        // cluster_crg_rst_init() or rvbar_init().  The core reset is
        // therefore held while the DebugBlock remains available.
        cluster_crg_init(cluster_mask);
        wait(cpu_vif.debug_pwr_qacceptn[cluster_index] == 1'b1);
        #0.5us;

        check_debugblock(path_ok);
        if (path_ok)
            `uvm_info(tag, "DebugBlock access passed with core reset held", UVM_LOW)
    endtask

    virtual task test_body();
        for (int c = 0; c < N_CLST; c++) begin
            set_cluster_index(c);
            run_one_cluster();
        end
    endtask

endclass

`endif
