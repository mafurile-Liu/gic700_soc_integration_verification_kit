`ifndef CPU_DEBUG_CORE_RESET_DBG_ACCESS_BASE_TEST_SV
`define CPU_DEBUG_CORE_RESET_DBG_ACCESS_BASE_TEST_SV

//----------------------------------------------------------------------
// DebugBlock access after a debug-generated core reset.
//
// The normal CRG sequence powers up the cluster, programs RVBAR, and
// releases core reset.  Then the DebugBlock GPR DBGRSTRR register
// asserts cdbgrstreq to the reset controller.  After DBGRSTAR
// acknowledges the request, the request is deasserted.  The DebugBlock
// remains in the debug power domain and is accessed afterwards.
//----------------------------------------------------------------------

class cpu_debug_core_reset_dbg_access_base_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_core_reset_dbg_access_base_test)

    localparam bit [31:0] CPU_TREE_BASE       = 32'h4B00_0000;
    localparam bit [31:0] CLST_STRIDE         = 32'h0028_0000;
    localparam int        N_CLST              = 6;
    localparam bit [31:0] CORE0_CTI_OFFSET    = 32'h000F_0000;
    localparam bit [31:0] DBROM_PRIDR0        = 32'h0000_0C00;
    localparam bit [31:0] DBROM_DBGRSTRR      = 32'h0000_0C10;
    localparam bit [31:0] DBROM_DBGRSTAR      = 32'h0000_0C14;
    localparam int        GPR_RESET_TIMEOUT   = 100;

    // CoreSight component IDs.
    localparam bit [31:0] CTI_GATE      = 32'h140;
    localparam bit [31:0] CTI_DEVTYPE_OFFSET = 32'hFCC;

    // DSU-120 r2p1 DebugBlock ROM table identity.
    localparam bit [31:0] DBROM_CIDR1   = 32'hFF4;

    localparam bit [31:0] CTI_DEVTYPE_EXP   = 32'h0000_0014;

    bit [31:0] cluster_base;
    bit [5:0]  cluster_mask;
    bit [31:0] rd_data;
    int        cluster_index;
    string     tag;

    protected task wait_gpr_bit(string name,
                                bit [31:0] addr,
                                int bit_index,
                                bit want,
                                output bit reached);
        int wait_count;

        reached = 0;
        while (wait_count < GPR_RESET_TIMEOUT && !reached) begin
            DBG_GETREG32(addr, rd_data);
            reached = (rd_data[bit_index] == want);
            `uvm_info(tag,
                      $sformatf("%s @ %08h = %08h, bit[%0d] = %0d",
                                name, addr, rd_data, bit_index,
                                rd_data[bit_index]), UVM_LOW)
            if (!reached)
                #100ns;
            wait_count++;
        end
    endtask

    protected virtual task request_core_reset_from_debug(output bit ok);
        bit reached;

        ok = 0;

        // GPR.PRIDR0.DBGRR indicates that DBGRSTRR/DBGRSTAR are
        // implemented.  Do not write an unimplemented reset-request
        // register.
        DBG_GETREG32(cluster_base + DBROM_PRIDR0, rd_data);
        `uvm_info(tag,
                  $sformatf("DBROM PRIDR0 = %08h, DBGRR = %0d",
                            rd_data, rd_data[4]), UVM_LOW)
        if (rd_data[4] != 1'b1) begin
            `uvm_error(tag, "DebugBlock GPR debug reset request is not implemented")
            return;
        end

        // Assert cdbgrstreq through the debug-domain GPR and wait for
        // the external reset controller to acknowledge it.
        DBG_SETREG32(cluster_base + DBROM_DBGRSTRR, 32'h0000_0001);
        wait_gpr_bit("DBGRSTAR", cluster_base + DBROM_DBGRSTAR,
                     0, 1'b1, reached);
        if (!reached) begin
            `uvm_error(tag, "debug reset request was not acknowledged")
            DBG_SETREG32(cluster_base + DBROM_DBGRSTRR, 32'h0000_0000);
            return;
        end

        // Hold the requested reset briefly, then deassert cdbgrstreq.
        #0.5us;
        DBG_SETREG32(cluster_base + DBROM_DBGRSTRR, 32'h0000_0000);
        wait_gpr_bit("DBGRSTAR", cluster_base + DBROM_DBGRSTAR,
                     0, 1'b0, reached);
        if (!reached) begin
            `uvm_error(tag, "debug reset acknowledge did not deassert")
            return;
        end

        #0.5us;
        `uvm_info(tag, "core reset requested and released through debug GPR", UVM_LOW)
        ok = 1;
    endtask

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

    protected task read_reg(string name, bit [31:0] addr, output bit [31:0] value);
        DBG_GETREG32(addr, value);
        `uvm_info(tag, $sformatf("%s @ %08h = %08h", name, addr, value), UVM_LOW)
    endtask

    protected virtual task check_debugblock(output bit path_ok);
        bit [31:0] cti_base;
        bit [31:0] gate_restore;

        path_ok = 1;
        cti_base = cluster_base + CORE0_CTI_OFFSET;

        // A compact check is sufficient for this reset-state case:
        // DBROM is alive, the core CTI is alive, and one CTI RW register
        // accepts a write while the core is in reset.
        expect_reg("DBROM CIDR1", cluster_base + DBROM_CIDR1,
                   32'h0000_00FF, 32'h0000_0090);
        expect_reg("CTI DEVTYPE", cti_base + CTI_DEVTYPE_OFFSET,
                   32'h0000_00FF, CTI_DEVTYPE_EXP);

        // Toggle GATE bit0 and restore it.  This proves writability
        // without enabling any trigger routing.
        read_reg("CTI GATE before RW test", cti_base + CTI_GATE,
                 gate_restore);
        write_readback("CTI GATE", cti_base + CTI_GATE,
                       gate_restore ^ 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_GATE, gate_restore);
    endtask

    protected virtual task run_one_cluster();
        bit path_ok;
        bit reset_ok;

        aw_seen = 1; // Debug-domain test; CPU main.cpp is not required.
        `uvm_info(tag, "begin normal power-up", UVM_LOW)

        open_clusters_pwr();
        bakdoor_set_svt_mem();

        // Normal CRG power-up/reset-release sequence.
        cluster_crg_init(cluster_mask);
        rvbar_init(cluster_mask);
        cluster_crg_rst_init(cluster_mask);
        wait(cpu_vif.debug_pwr_qacceptn[cluster_index] == 1'b1);
        #0.5us;

        request_core_reset_from_debug(reset_ok);
        if (!reset_ok)
            return;

        check_debugblock(path_ok);
        if (path_ok)
            `uvm_info(tag, "DebugBlock access passed after debug-generated core reset", UVM_LOW)
    endtask

    virtual task test_body();
        for (int c = 0; c < N_CLST; c++) begin
            set_cluster_index(c);
            run_one_cluster();
        end
    endtask

endclass

`endif
