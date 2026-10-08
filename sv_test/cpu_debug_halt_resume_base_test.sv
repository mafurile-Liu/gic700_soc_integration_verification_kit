`ifndef CPU_DEBUG_HALT_RESUME_BASE_TEST_SV
`define CPU_DEBUG_HALT_RESUME_BASE_TEST_SV

//----------------------------------------------------------------------
// Base test for A720 cluster halt/resume.
//
// The cluster ROM table is walked to locate the first core debug
// component and the first core CTI.  The CTI channel-0 pulse is routed
// to CTI output trigger 0 (external debug request) and output trigger
// 1 (external restart request), matching the Armv8-A run-control use.
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
    localparam int        MAX_ROM_ENTRY = 12;

    // CoreSight CTI register offsets.
    localparam bit [31:0] CTI_CONTROL     = 32'h000;
    localparam bit [31:0] CTI_INTACK      = 32'h010;
    localparam bit [31:0] CTI_APPPULSE    = 32'h01C;
    localparam bit [31:0] CTI_OUTEN0      = 32'h0A0;
    localparam bit [31:0] CTI_OUTEN1      = 32'h0A4;
    localparam bit [31:0] CTI_GATE        = 32'h140;

    // A720 external debug registers and fields.
    localparam bit [31:0] EDSCR           = 32'h088;
    localparam bit [31:0] EDPRCR          = 32'h310;
    localparam bit [31:0] EDPRSR          = 32'h314;
    localparam bit [31:0] EDSCR_HDE       = 32'h0000_4000;
    localparam bit [31:0] EDPRCR_CORENPDRQ = 32'h0000_0001;
    localparam int        EDPRSR_HALTED_BIT = 4;

    bit [31:0] cluster_base;
    bit [31:0] dbg_base;
    bit [31:0] cti_base;
    bit [31:0] entry_val;
    bit [31:0] comp_base;
    bit [31:0] rd_data;
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

    protected function automatic bit [31:0] resolve_rom_entry(bit [31:0] entry);
        bit [31:0] offset;

        // OFFSET is a signed, 4K-granular offset relative to the ROM table.
        offset = {{12{entry[31]}}, entry[31:12]};
        return cluster_base + (offset << 12);
    endfunction

    protected task expect_reg(string name,
                              bit [31:0] addr,
                              bit [31:0] mask,
                              bit [31:0] expected);
        DBG_GETREG32(addr, temp_data);
        `uvm_info(tag, $sformatf("%s = %h", name, temp_data), UVM_LOW)
        if ((temp_data & mask) != expected)
            `uvm_error(tag, $sformatf("%s = %h, expected %08h",
                                      name, temp_data & mask, expected))
    endtask

    protected virtual task check_cluster_rom(output bit path_ok);
        path_ok = 1;
        `uvm_info(tag, $sformatf("begin cluster ROM check @ %08h", cluster_base), UVM_LOW)

        expect_reg("ROM CIDR0", cluster_base + 32'hFF0, 32'h0000_00FF, 32'h0000_000D);
        expect_reg("ROM CIDR1", cluster_base + 32'hFF4, 32'h0000_00FF, 32'h0000_0090);
        expect_reg("ROM CIDR2", cluster_base + 32'hFF8, 32'h0000_00FF, 32'h0000_0005);
        expect_reg("ROM CIDR3", cluster_base + 32'hFFC, 32'h0000_00FF, 32'h0000_00B1);

        dbg_base = 32'h0;
        cti_base = 32'h0;

        for (int e = 0; e < MAX_ROM_ENTRY; e++) begin
            bit [31:0] pid0;
            bit [31:0] pid1;

            DBG_GETREG32(cluster_base + e * 4, entry_val);
            `uvm_info(tag, $sformatf("ROM entry[%0d] = %08h", e, entry_val), UVM_LOW)

            if (entry_val == 32'h0)
                break;
            if (entry_val[1:0] != 2'b11) begin
                `uvm_error(tag, $sformatf("ROM entry[%0d] = %08h, PRESENT is not 0b11",
                                          e, entry_val))
                continue;
            end

            comp_base = resolve_rom_entry(entry_val);
            DBG_GETREG32(comp_base + 32'hFE0, pid0);
            DBG_GETREG32(comp_base + 32'hFE4, pid1);
            `uvm_info(tag,
                      $sformatf("component %08h PIDR1:PIDR0 = %02h%02h",
                                comp_base, pid1[7:0], pid0[7:0]), UVM_LOW)

            // A720 core debug peripheral ID is 0x47709A15.
            if (dbg_base == 32'h0 &&
                pid0[7:0] == 8'h15 && pid1[7:0] == 8'h9A)
                dbg_base = comp_base;

            // A720 core CTI peripheral ID has DES_0=0xB, PART_1=0xD, PART_0=0x81.
            if (cti_base == 32'h0 &&
                pid0[7:0] == 8'h81 && pid1[7:0] == 8'hBD)
                cti_base = comp_base;

            if (dbg_base != 32'h0 && cti_base != 32'h0)
                break;
        end

        if (dbg_base == 32'h0) begin
            `uvm_error(tag, "A720 core debug component not found through ROM table")
            path_ok = 0;
        end
        if (cti_base == 32'h0) begin
            `uvm_error(tag, "A720 core CTI component not found through ROM table")
            path_ok = 0;
        end
        if (!path_ok)
            return;

        `uvm_info(tag,
                  $sformatf("debug @ %08h, CTI @ %08h", dbg_base, cti_base), UVM_LOW)
        expect_reg("debug CIDR1", dbg_base + 32'hFF4, 32'h0000_00FF, 32'h0000_0090);
        expect_reg("debug PIDR0", dbg_base + 32'hFE0, 32'h0000_00FF, 32'h0000_0015);
        expect_reg("debug PIDR1", dbg_base + 32'hFE4, 32'h0000_00FF, 32'h0000_009A);
        expect_reg("debug PIDR2", dbg_base + 32'hFE8, 32'h0000_00FF, 32'h0000_0070);
        expect_reg("debug PIDR3", dbg_base + 32'hFEC, 32'h0000_00FF, 32'h0000_0047);

        expect_reg("CTI CIDR1", cti_base + 32'hFF4, 32'h0000_00FF, 32'h0000_0090);
        expect_reg("CTI PIDR0", cti_base + 32'hFE0, 32'h0000_00FF, 32'h0000_0081);
        expect_reg("CTI PIDR1", cti_base + 32'hFE4, 32'h0000_00FF, 32'h0000_00BD);
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

        check_cluster_rom(path_ok);
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
