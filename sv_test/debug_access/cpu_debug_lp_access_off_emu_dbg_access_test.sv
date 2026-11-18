`ifndef CPU_DEBUG_LP_ACCESS_OFF_EMU_DBG_ACCESS_TEST_SV
`define CPU_DEBUG_LP_ACCESS_OFF_EMU_DBG_ACCESS_TEST_SV

//----------------------------------------------------------------------
// Minimal debug-APB access while dsu_off_emu_dbg_access_test holds the
// design in OFF_EMU.
//
// Cache RAM contents are not accessed here.  A720/DSU cache debug is
// exposed through core system registers (RAMINDEX/CLUSTERCDBG), not the
// external debug APB interface.
//----------------------------------------------------------------------

class cpu_debug_lp_access_off_emu_dbg_access_test
    extends dsu_off_emu_dbg_access_test;
    `uvm_component_utils(cpu_debug_lp_access_off_emu_dbg_access_test)

    localparam bit [31:0] CPU_TREE_BASE       = 32'h4B00_0000;
    localparam bit [31:0] CLST_STRIDE         = 32'h0028_0000;
    localparam bit [31:0] CLUSTER_ROM_OFFSET  = 32'h0001_0000;
    localparam bit [31:0] CORE0_DEBUG_OFFSET  = 32'h0009_0000;
    localparam bit [31:0] CORE0_CTI_OFFSET    = 32'h000F_0000;
    localparam bit [31:0] CLUSTER_CTI_OFFSET  = 32'h0004_0000;

    localparam bit [31:0] ROM_CIDR1           = `APB_ROM_TABLE_BLOCK_CIDR1_OFFSET;
    localparam bit [31:0] ED_MIDR_EL1         = `APB_DEBUG_BLOCK_MIDR_EL1_OFFSET;
    localparam bit [31:0] ED_DEVTYPE          = `APB_DEBUG_BLOCK_EDDEVTYPE_OFFSET;
    localparam bit [31:0] ED_PRSR             = `APB_DEBUG_BLOCK_EDPRSR_OFFSET;

    // CTI does not have designer offset macros yet.
    localparam bit [31:0] CTI_GATE            = 32'h140;
    localparam bit [31:0] CTI_DEVTYPE         = 32'hFCC;

    localparam bit [31:0] DBROM_CIDR1_EXP     = 32'h0000_0090;
    localparam bit [31:0] ED_MIDR_EL1_EXP     = 32'h410F_D812;
    localparam bit [31:0] ED_DEVTYPE_EXP      = 32'h0000_0015;
    localparam bit [31:0] CTI_DEVTYPE_EXP     = 32'h0000_0014;

    bit [31:0] rd_data;
    bit [31:0] cluster_base;
    int        cluster_index;
    string     tag;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_cluster_index(0);
        tag = "cpu_debug_lp_access_off_emu";
    endfunction

    virtual function void set_cluster_index(int idx);
        cluster_index = idx;
        cluster_base  = CPU_TREE_BASE + idx * CLST_STRIDE;
    endfunction

    protected task read_reg(string name,
                            bit [31:0] addr,
                            output bit [31:0] value);
        DBG_GETREG32(addr, value);
        `uvm_info(tag, $sformatf("%s @ %08h = %08h", name, addr, value), UVM_LOW)
    endtask

    protected task check_reg(string name,
                             bit [31:0] addr,
                             bit [31:0] mask,
                             bit [31:0] expected,
                             output bit ok);
        bit [31:0] value;

        read_reg(name, addr, value);
        ok = ((value & mask) == expected);
        if (!ok)
            `uvm_error(tag, $sformatf("%s = %08h, expected %08h",
                                      name, value & mask, expected))
    endtask

    protected task write_readback(string name,
                                  bit [31:0] addr,
                                  bit [31:0] value);
        bit [31:0] value_read;

        DBG_SETREG32(addr, value);
        DBG_GETREG32(addr, value_read);
        `uvm_info(tag,
                  $sformatf("%s @ %08h write %08h, readback %08h",
                            name, addr, value, value_read), UVM_LOW)
        if (value_read != value)
            `uvm_error(tag, $sformatf("%s readback = %08h, expected %08h",
                                      name, value_read, value))
    endtask

    protected virtual task run_dbg_access();
        bit [31:0] cti_base;
        bit [31:0] gate_restore;
        bit        dbrom_ok;
        bit        cluster_rom_ok;
        bit        midr_ok;
        bit        ed_devtype_ok;
        bit        core_cti_ok;
        bit        cluster_cti_ok;
        bit        path_ok;

        cti_base = cluster_base + CORE0_CTI_OFFSET;
        path_ok  = 1;

        `uvm_info(tag, "begin OFF_EMU debug APB access", UVM_LOW)

        check_reg("DBROM CIDR1", cluster_base + ROM_CIDR1,
                  32'h0000_00FF, DBROM_CIDR1_EXP, dbrom_ok);
        check_reg("Cluster ROM CIDR1",
                  cluster_base + CLUSTER_ROM_OFFSET + ROM_CIDR1,
                  32'h0000_00FF, DBROM_CIDR1_EXP, cluster_rom_ok);
        path_ok &= dbrom_ok;
        path_ok &= cluster_rom_ok;

        check_reg("Core debug MIDR_EL1",
                  cluster_base + CORE0_DEBUG_OFFSET + ED_MIDR_EL1,
                  32'hFFFF_FFFF, ED_MIDR_EL1_EXP, midr_ok);
        check_reg("Core debug DEVTYPE",
                  cluster_base + CORE0_DEBUG_OFFSET + ED_DEVTYPE,
                  32'h0000_00FF, ED_DEVTYPE_EXP, ed_devtype_ok);
        path_ok &= midr_ok;
        path_ok &= ed_devtype_ok;

        check_reg("Core0 CTI DEVTYPE", cti_base + CTI_DEVTYPE,
                  32'h0000_00FF, CTI_DEVTYPE_EXP, core_cti_ok);
        check_reg("Cluster CTI DEVTYPE",
                  cluster_base + CLUSTER_CTI_OFFSET + CTI_DEVTYPE,
                  32'h0000_00FF, CTI_DEVTYPE_EXP, cluster_cti_ok);
        path_ok &= core_cti_ok;
        path_ok &= cluster_cti_ok;

        // Toggle CTIGATE bit0 and restore it.  This proves a DebugBlock
        // register is writable without enabling any trigger routing.
        read_reg("Core0 CTI GATE before RW test", cti_base + CTI_GATE,
                 gate_restore);
        write_readback("Core0 CTI GATE", cti_base + CTI_GATE,
                       gate_restore ^ 32'h0000_0001);
        DBG_SETREG32(cti_base + CTI_GATE, gate_restore);

        // State-dependent status register: log only.  Its reset/state
        // fields can differ while the design-side scenario is active.
        read_reg("Core debug EDPRSR",
                 cluster_base + CORE0_DEBUG_OFFSET + ED_PRSR, rd_data);

        if (path_ok)
            `uvm_info(tag, "OFF_EMU debug APB access passed", UVM_LOW)
    endtask

    virtual task off_emu_access_body();
        run_dbg_access();
    endtask

endclass

`endif
