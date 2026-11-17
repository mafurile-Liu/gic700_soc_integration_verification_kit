`ifndef CPU_DEBUG_CTI_PMU_TEST_SV
`define CPU_DEBUG_CTI_PMU_TEST_SV

//----------------------------------------------------------------------
// cti_pmu access test
//
// dbg_address_mapping.xlsx / apb_tree_cpu (m18):
//   cti_pmu external view 0x4BF0_2000, 4K
//   parent romtable_apbic entry 0x1D0_2003
//
// The component is a CoreSight SoC-600 css600_cti.  Check its identity
// registers and basic RW registers without issuing CTIAPPSET or
// CTIAPPPULSE.
//----------------------------------------------------------------------

class cpu_debug_cti_pmu_test extends cpu_debug_base_test;
    `uvm_component_utils(cpu_debug_cti_pmu_test)

    localparam bit [31:0] CTI_PMU_BASE = 32'h4BF0_2000;

    localparam bit [31:0] CTI_CONTROL   = 32'h000;
    localparam bit [31:0] CTI_OUTEN0    = 32'h0A0;
    localparam bit [31:0] CTI_GATE      = 32'h140;
    localparam bit [31:0] CTI_TRIGINSTATUS  = 32'h130;
    localparam bit [31:0] CTI_TRIGOUTSTATUS = 32'h134;
    localparam bit [31:0] CTI_CHINSTATUS    = 32'h138;
    localparam bit [31:0] CTI_CHOUTSTATUS   = 32'h13C;
    localparam bit [31:0] CTI_DEVARCH   = 32'hFBC;
    localparam bit [31:0] CTI_DEVID     = 32'hFC8;
    localparam bit [31:0] CTI_DEVTYPE   = 32'hFCC;
    localparam bit [31:0] CTI_PIDR4     = 32'hFD0;
    localparam bit [31:0] CTI_PIDR0     = 32'hFE0;
    localparam bit [31:0] CTI_PIDR1     = 32'hFE4;
    localparam bit [31:0] CTI_PIDR2     = 32'hFE8;
    localparam bit [31:0] CTI_PIDR3     = 32'hFEC;
    localparam bit [31:0] CTI_CIDR0     = 32'hFF0;
    localparam bit [31:0] CTI_CIDR1     = 32'hFF4;
    localparam bit [31:0] CTI_CIDR2     = 32'hFF8;
    localparam bit [31:0] CTI_CIDR3     = 32'hFFC;

    bit [31:0] rd_data;
    bit [31:0] control_restore;
    bit [31:0] outen0_restore;
    bit [31:0] gate_restore;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    protected task expect_reg(string name,
                              bit [31:0] addr,
                              bit [31:0] mask,
                              bit [31:0] expected);
        DBG_GETREG32(addr, temp_data);
        `uvm_info("cti_pmu", $sformatf("%s = %h", name, temp_data), UVM_LOW)
        if ((temp_data & mask) != expected)
            `uvm_error("cti_pmu", $sformatf("%s = %h, expected %08h",
                                            name, temp_data & mask, expected))
    endtask

    protected task read_reg(string name, bit [31:0] addr, output bit [31:0] value);
        DBG_GETREG32(addr, value);
        `uvm_info("cti_pmu", $sformatf("%s = %h", name, value), UVM_LOW)
    endtask

    protected task write_readback(string name,
                                  bit [31:0] addr,
                                  bit [31:0] value);
        DBG_SETREG32(addr, value);
        DBG_GETREG32(addr, rd_data);
        `uvm_info("cti_pmu",
                  $sformatf("%s write %08h, readback %08h", name, value, rd_data), UVM_LOW)
        if (rd_data != value)
            `uvm_error("cti_pmu", $sformatf("%s readback = %08h, expected %08h",
                                            name, rd_data, value))
    endtask

    virtual task test_body();
        aw_seen = 1; // debug domain test, cpu does not need to run main.cpp
        `uvm_info("cti_pmu", "begin", UVM_LOW)

        // CoreSight SoC-600 css600_cti component identity.
        expect_reg("CIDR0", CTI_PMU_BASE + CTI_CIDR0, 32'h0000_00FF, 32'h0000_000D);
        expect_reg("CIDR1", CTI_PMU_BASE + CTI_CIDR1, 32'h0000_00FF, 32'h0000_0090);
        expect_reg("CIDR2", CTI_PMU_BASE + CTI_CIDR2, 32'h0000_00FF, 32'h0000_0005);
        expect_reg("CIDR3", CTI_PMU_BASE + CTI_CIDR3, 32'h0000_00FF, 32'h0000_00B1);

        expect_reg("PIDR0", CTI_PMU_BASE + CTI_PIDR0, 32'h0000_00FF, 32'h0000_00ED);
        expect_reg("PIDR1", CTI_PMU_BASE + CTI_PIDR1, 32'h0000_00FF, 32'h0000_00B9);
        expect_reg("PIDR2", CTI_PMU_BASE + CTI_PIDR2, 32'h0000_000F, 32'h0000_000B);
        expect_reg("PIDR3", CTI_PMU_BASE + CTI_PIDR3, 32'h0000_000F, 32'h0000_0000);
        expect_reg("PIDR4", CTI_PMU_BASE + CTI_PIDR4, 32'h0000_000F, 32'h0000_0004);

        expect_reg("DEVARCH", CTI_PMU_BASE + CTI_DEVARCH, 32'hFFFF_FFFF,
                   32'h4770_1A14);
        expect_reg("DEVTYPE", CTI_PMU_BASE + CTI_DEVTYPE, 32'h0000_00FF,
                   32'h0000_0014);

        read_reg("DEVID", CTI_PMU_BASE + CTI_DEVID, rd_data);
        if (rd_data[24] != 1'b1)
            `uvm_error("cti_pmu", $sformatf("DEVID.INOUT = %0d, expected 1",
                                            rd_data[24]))

        // Status registers are read-only; log them to make the waveform
        // check easy without changing the cross-trigger state.
        read_reg("TRIGINSTATUS", CTI_PMU_BASE + CTI_TRIGINSTATUS, rd_data);
        read_reg("TRIGOUTSTATUS", CTI_PMU_BASE + CTI_TRIGOUTSTATUS, rd_data);
        read_reg("CHINSTATUS", CTI_PMU_BASE + CTI_CHINSTATUS, rd_data);
        read_reg("CHOUTSTATUS", CTI_PMU_BASE + CTI_CHOUTSTATUS, rd_data);

        // Put the CTI in a quiescent state before checking RW registers.
        read_reg("CONTROL before RW test", CTI_PMU_BASE + CTI_CONTROL,
                 control_restore);
        DBG_SETREG32(CTI_PMU_BASE + CTI_CONTROL, 32'h0000_0000);

        read_reg("OUTEN0 before RW test", CTI_PMU_BASE + CTI_OUTEN0,
                 outen0_restore);
        write_readback("OUTEN0", CTI_PMU_BASE + CTI_OUTEN0, 32'h0000_0001);
        DBG_SETREG32(CTI_PMU_BASE + CTI_OUTEN0, 32'h0000_0000);

        read_reg("GATE before RW test", CTI_PMU_BASE + CTI_GATE, gate_restore);
        write_readback("GATE", CTI_PMU_BASE + CTI_GATE,
                       gate_restore ^ 32'h0000_0001);
        DBG_SETREG32(CTI_PMU_BASE + CTI_GATE, gate_restore);
        expect_reg("GATE restore", CTI_PMU_BASE + CTI_GATE, 32'hFFFF_FFFF,
                   gate_restore);

        // No output trigger is enabled during the CONTROL write test.
        write_readback("CONTROL", CTI_PMU_BASE + CTI_CONTROL, 32'h0000_0001);
        DBG_SETREG32(CTI_PMU_BASE + CTI_OUTEN0, outen0_restore);
        expect_reg("OUTEN0 restore", CTI_PMU_BASE + CTI_OUTEN0, 32'hFFFF_FFFF,
                   outen0_restore);
        DBG_SETREG32(CTI_PMU_BASE + CTI_CONTROL, control_restore);
        expect_reg("CONTROL restore", CTI_PMU_BASE + CTI_CONTROL, 32'hFFFF_FFFF,
                   control_restore);

        `uvm_info("cti_pmu", "done", UVM_LOW)
    endtask

endclass

`endif
