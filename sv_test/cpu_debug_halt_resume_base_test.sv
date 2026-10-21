`ifndef CPU_DEBUG_HALT_RESUME_BASE_TEST_SV
`define CPU_DEBUG_HALT_RESUME_BASE_TEST_SV

//----------------------------------------------------------------------
// Base test for A720 cluster halt/resume.
//
// Use the DSU-120 TRM fixed cluster offsets directly for the fast
// halt/resume path.  DSU-120 TRM Table 16-2 places core0 debug at
// +0x90000 and core0 CTI at +0xF0000.  Core debug registers are in the
// core power domain while CTIs are in the debug power domain, so request
// cluster then core power using the DSU Granular Power Requesters before
// accessing core debug.  The CTI channel-0 pulse is routed to CTI output
// trigger 0 (external debug request) and output trigger 1 (external
// restart request), matching Armv8-A run-control.
//
// A720 external-debug offsets:
//   EDSCR.HDE     bit 14, register 0x088
//   EDPRCR.CORENPDRQ bit 0, register 0x310
//   EDPRSR.HALTED bit 4, register 0x314
//----------------------------------------------------------------------

class cpu_debug_halt_resume_base_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_halt_resume_base_test)

    localparam bit [31:0] CPU_TREE_BASE = 32'h4B00_0000;
    localparam bit [31:0] CLST_STRIDE   = 32'h0028_0000;
    localparam int        N_CLST        = 6;
    // DSU-120 TRM Table 16-2: fixed offsets within a cluster DebugBlock.
    localparam bit [31:0] CLUSTER_ROM_OFFSET = 32'h0001_0000;
    localparam bit [31:0] CORE0_DEBUG_OFFSET = 32'h0009_0000;
    localparam bit [31:0] CORE0_CTI_OFFSET   = 32'h000F_0000;
    // DSU-120 Granular Power Requester offsets. Both ROM tables place
    // DBGPCR0 at +0xA00 and DBGPSR0 at +0xA80.
    localparam bit [31:0] GPR_DBGPCR0       = 32'h0000_0A00;
    localparam bit [31:0] GPR_DBGPSR0       = 32'h0000_0A80;
    localparam bit [31:0] GPR_POWER_REQUEST = 32'h0000_0002;
    localparam int        GPR_POWER_TIMEOUT = 100;

    // CoreSight CTI register offsets.
    localparam bit [31:0] CTI_CONTROL     = 32'h000;
    localparam bit [31:0] CTI_INTACK      = 32'h010;
    localparam bit [31:0] CTI_APPPULSE    = 32'h01C;
    localparam bit [31:0] CTI_OUTEN0      = 32'h0A0;
    localparam bit [31:0] CTI_OUTEN1      = 32'h0A4;
    localparam bit [31:0] CTI_GATE        = 32'h140;

    // A720 external debug registers and fields.
    localparam bit [31:0] EDDEVARCH       = 32'hFBC;
    localparam bit [31:0] EDDEVTYPE       = 32'hFCC;
    localparam bit [31:0] EDSCR           = 32'h088;
    localparam bit [31:0] EDPRCR          = 32'h310;
    localparam bit [31:0] EDPRSR          = 32'h314;
    localparam bit [31:0] DEBUG_DEVTYPE   = 32'h0000_0015;
    localparam bit [31:0] DEBUG_DEVARCH   = 32'h4770_9A15;
    localparam bit [31:0] CTI_DEVTYPE     = 32'h0000_0014;
    localparam bit [31:0] CTI_DEVARCH     = 32'h4770_1A14;
    localparam bit [31:0] EDSCR_HDE       = 32'h0000_4000;
    localparam bit [31:0] EDPRCR_CORENPDRQ = 32'h0000_0001;
    localparam int        EDPRSR_HALTED_BIT = 4;

    bit [31:0] cluster_base;
    bit [31:0] dbg_base;
    bit [31:0] cti_base;
    bit [31:0] cti_gate_restore;
    int        cluster_index;
    string     tag;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(0);
    endfunction

    virtual function void set_cluster_index(int idx);
        cluster_index = idx;
        cluster_base  = CPU_TREE_BASE + idx * CLST_STRIDE;
        tag           = $sformatf("halt_resume_clst%0d", idx);
    endfunction

    protected virtual task request_debug_power(output bit powered);
        int wait_count;

        powered = 0;

        // DSU-120 TRM 15.4: first power up PDCLUSTER via DBROM_DBGPCR0,
        // then power up PDCOMPLEX0 via CLUSTERROM_DBGPCR0.
        DBG_SETREG32(cluster_base + GPR_DBGPCR0, GPR_POWER_REQUEST);
        wait_count = 0;
        while (wait_count < GPR_POWER_TIMEOUT) begin
            DBG_GETREG32(cluster_base + GPR_DBGPSR0, temp_data);
            if (temp_data[0] == 1'b1)
                break;
            #100ns;
            wait_count++;
        end
        if (wait_count == GPR_POWER_TIMEOUT) begin
            `uvm_error(tag, "cluster debug power did not become active")
            return;
        end

        DBG_SETREG32(cluster_base + CLUSTER_ROM_OFFSET + GPR_DBGPCR0,
                     GPR_POWER_REQUEST);
        wait_count = 0;
        while (wait_count < GPR_POWER_TIMEOUT) begin
            DBG_GETREG32(cluster_base + CLUSTER_ROM_OFFSET + GPR_DBGPSR0,
                         temp_data);
            if (temp_data[0] == 1'b1)
                break;
            #100ns;
            wait_count++;
        end
        if (wait_count == GPR_POWER_TIMEOUT) begin
            `uvm_error(tag, "core0 debug power did not become active")
            return;
        end

        powered = 1;
        `uvm_info(tag, "cluster and core0 debug power active", UVM_LOW)
    endtask

    protected virtual task check_halt_resume_targets(output bit path_ok);
        path_ok = 1;
        `uvm_info(tag, $sformatf("begin target check @ %08h", cluster_base), UVM_LOW)

        request_debug_power(path_ok);
        if (!path_ok)
            return;

        // DSU-120 TRM Table 16-2 gives these offsets directly:
        //   core0 debug = +0x90000, core0 CTI = +0xF0000.
        // The separate cluster ROM table tests own the ROM walk coverage.
        dbg_base = cluster_base + CORE0_DEBUG_OFFSET;
        cti_base = cluster_base + CORE0_CTI_OFFSET;

        // Confirm the direct addresses before programming run-control.
        // A720 debug and CTI share Peripheral ID 0x04200BBD81, so use
        // DEVTYPE/DEVARCH to distinguish the two components.
        DBG_GETREG32(dbg_base + 32'hFE0, temp_data);
        `uvm_info(tag, $sformatf("debug @ %08h PIDR0 = %h", dbg_base, temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h81) begin
            `uvm_error(tag, $sformatf("debug PIDR0 = %h, expected x81", temp_data))
            path_ok = 0;
        end

        DBG_GETREG32(dbg_base + 32'hFE4, temp_data);
        `uvm_info(tag, $sformatf("debug @ %08h PIDR1 = %h", dbg_base, temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'hBD) begin
            `uvm_error(tag, $sformatf("debug PIDR1 = %h, expected xBD", temp_data))
            path_ok = 0;
        end

        DBG_GETREG32(dbg_base + EDDEVTYPE, temp_data);
        `uvm_info(tag, $sformatf("debug @ %08h DEVTYPE = %h", dbg_base, temp_data), UVM_LOW)
        if (temp_data[7:0] != DEBUG_DEVTYPE[7:0]) begin
            `uvm_error(tag, $sformatf("debug DEVTYPE = %h, expected x15", temp_data))
            path_ok = 0;
        end

        DBG_GETREG32(dbg_base + EDDEVARCH, temp_data);
        `uvm_info(tag, $sformatf("debug @ %08h DEVARCH = %h", dbg_base, temp_data), UVM_LOW)
        if (temp_data != DEBUG_DEVARCH) begin
            `uvm_error(tag, $sformatf("debug DEVARCH = %h, expected %08h",
                                      temp_data, DEBUG_DEVARCH))
            path_ok = 0;
        end

        DBG_GETREG32(cti_base + 32'hFE0, temp_data);
        `uvm_info(tag, $sformatf("CTI @ %08h PIDR0 = %h", cti_base, temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'h81) begin
            `uvm_error(tag, $sformatf("CTI PIDR0 = %h, expected x81", temp_data))
            path_ok = 0;
        end

        DBG_GETREG32(cti_base + 32'hFE4, temp_data);
        `uvm_info(tag, $sformatf("CTI @ %08h PIDR1 = %h", cti_base, temp_data), UVM_LOW)
        if (temp_data[7:0] != 8'hBD) begin
            `uvm_error(tag, $sformatf("CTI PIDR1 = %h, expected xBD", temp_data))
            path_ok = 0;
        end

        DBG_GETREG32(cti_base + 32'hFCC, temp_data);
        `uvm_info(tag, $sformatf("CTI @ %08h DEVTYPE = %h", cti_base, temp_data), UVM_LOW)
        if (temp_data[7:0] != CTI_DEVTYPE[7:0]) begin
            `uvm_error(tag, $sformatf("CTI DEVTYPE = %h, expected x14", temp_data))
            path_ok = 0;
        end

        DBG_GETREG32(cti_base + 32'hFBC, temp_data);
        `uvm_info(tag, $sformatf("CTI @ %08h DEVARCH = %h", cti_base, temp_data), UVM_LOW)
        if (temp_data != CTI_DEVARCH) begin
            `uvm_error(tag, $sformatf("CTI DEVARCH = %h, expected %08h",
                                      temp_data, CTI_DEVARCH))
            path_ok = 0;
        end
        if (!path_ok)
            return;

        `uvm_info(tag,
                  $sformatf("debug @ %08h, CTI @ %08h", dbg_base, cti_base), UVM_LOW)
    endtask

    protected virtual task wait_halted(bit want_halted, output bit reached);
        reached = 0;
        for (int i = 0; i < 200 && !reached; i++) begin
            DBG_GETREG32(dbg_base + EDPRSR, temp_data);
            reached = (temp_data[EDPRSR_HALTED_BIT] == want_halted);
            `uvm_info(tag,
                      $sformatf("EDPRSR = %08h, HALTED = %0d",
                                temp_data, temp_data[EDPRSR_HALTED_BIT]), UVM_HIGH)
            if (!reached)
                #100ns;
        end
    endtask

    protected virtual task configure_cti();
        DBG_GETREG32(cti_base + CTI_GATE, cti_gate_restore);
        // CTIGATE bit 1 enables channel propagation to the CTM.
        DBG_SETREG32(cti_base + CTI_GATE, cti_gate_restore | 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_INTACK, 32'h0000_0003);
        DBG_SETREG32(cti_base + CTI_OUTEN0, 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_CONTROL, 32'h0000_0001);
    endtask

    protected virtual task cleanup_cti();
        DBG_SETREG32(cti_base + CTI_OUTEN0, 32'h0000_0000);
        DBG_SETREG32(cti_base + CTI_OUTEN1, 32'h0000_0000);
        DBG_SETREG32(cti_base + CTI_CONTROL, 32'h0000_0000);
        DBG_SETREG32(cti_base + CTI_GATE, cti_gate_restore);
    endtask

    protected virtual task run_halt_resume();
        bit path_ok;
        bit halted;
        bit resumed;

        check_halt_resume_targets(path_ok);
        if (!path_ok)
            return;

        // Keep the core power domain available and enable halting debug.
        DBG_GETREG32(dbg_base + EDPRCR, temp_data);
        DBG_SETREG32(dbg_base + EDPRCR, temp_data | EDPRCR_CORENPDRQ);
        DBG_GETREG32(dbg_base + EDSCR, temp_data);
        DBG_SETREG32(dbg_base + EDSCR, temp_data | EDSCR_HDE);

        DBG_GETREG32(dbg_base + EDPRSR, temp_data);
        if (temp_data[EDPRSR_HALTED_BIT] == 1'b1)
            `uvm_error(tag, "core is already halted before the CTI halt request")

        configure_cti();
        DBG_SETREG32(cti_base + CTI_APPPULSE, 32'h0000_0001);
        wait_halted(1'b1, halted);
        if (!halted) begin
            `uvm_error(tag, "core did not enter Debug state after CTI halt request")
            cleanup_cti();
            return;
        end
        DBG_SETREG32(cti_base + CTI_INTACK, 32'h0000_0001);
        `uvm_info(tag, "core entered Debug state", UVM_LOW)

        // Enable only the restart trigger before pulsing channel 0 again.
        DBG_SETREG32(cti_base + CTI_OUTEN0, 32'h0000_0000);
        DBG_SETREG32(cti_base + CTI_OUTEN1, 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_APPPULSE, 32'h0000_0001);
        wait_halted(1'b0, resumed);
        DBG_SETREG32(cti_base + CTI_INTACK, 32'h0000_0003);
        if (!resumed)
            `uvm_error(tag, "core did not resume after CTI restart request")
        else
            `uvm_info(tag, "core resumed execution", UVM_LOW)

        cleanup_cti();
        `uvm_info(tag, "done", UVM_LOW)
    endtask

    virtual task test_body();
        aw_seen = 1; // debug-domain test; CPU main.cpp is not required.
        run_halt_resume();
    endtask

endclass

`endif
