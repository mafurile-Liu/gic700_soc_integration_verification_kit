`ifndef CPU_ECT_EVENTIN_TEST_SV
`define CPU_ECT_EVENTIN_TEST_SV

//----------------------------------------------------------------------
// CPU CTI event_in -> channel direct-map traversal.
//
// CTI base: dbg_address_mapping / cti_pmu 0x4BF0_2000.
// The C/UVM debug path maps each input trigger to the same channel:
//   event_in[0..11] -> channel[0..11]
// event_in[9] is level type and is driven with a controlled level pair.
//----------------------------------------------------------------------
class cpu_ect_eventin_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_eventin_test)

    localparam bit [31:0] CTI_BASE  = 32'h4BF0_2000;
    localparam bit [31:0] CTI_CONTROL = 32'h000;
    localparam bit [31:0] CTI_GATE    = 32'h140;
    localparam int unsigned N_EVT_IN  = 12;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;
        cpu_ect_level_sequence level_seq;
        int unsigned idx;
        int unsigned ch;

        aw_seen = 1;
        `uvm_info("cpu_ect_eventin", "begin", UVM_LOW)

        // Enable only while the CTI is disabled.
        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0);
        for (int unsigned i = 0; i < N_EVT_IN; i++) begin
            ect_write32(CTI_BASE + 32'h020 + (i * 4), (32'h1 << i));
        end
        ect_write32(CTI_BASE + CTI_GATE, 32'h0000_0FFF);
        ect_write32(CTI_BASE + CTI_CONTROL, 32'h0000_0001);

        ect_expect32("CONTROL", CTI_BASE + CTI_CONTROL,
                     32'h0000_0001, 32'h0000_0001);
        ect_expect32("GATE", CTI_BASE + CTI_GATE,
                     32'h0000_0FFF, 32'h0000_0FFF);
        for (int unsigned i = 0; i < N_EVT_IN; i++) begin
            ect_expect32($sformatf("INEN%0d", i),
                         CTI_BASE + 32'h020 + (i * 4),
                         32'h0000_0FFF, (32'h1 << i));
        end

        for (idx = 0; idx < N_EVT_IN; idx++) begin
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_EVT_IN), .index(idx),
                .expected_value(1'b1), .timeout_cycles(1000));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_EVT_IN), .index(idx),
                .expected_value(1'b0), .timeout_cycles(2000));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_OUT), .index(idx),
                .expected_value(1'b1), .timeout_cycles(1000));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_OUT), .index(idx),
                .expected_value(1'b0), .timeout_cycles(2000));

            for (ch = 0; ch < 16; ch++) begin
                if (ch != idx) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CTI_CH_OUT), .index(ch),
                        .forbidden_value(1'b1), .timeout_cycles(2000));
                end
            end

            if (cpu_ect_evt_in_is_level(idx)) begin
                level_seq = cpu_ect_level_sequence::type_id::create("level_high");
                if (!level_seq.randomize() with {
                        loc         == CPU_ECT_CTI_EVT_IN;
                        index       == idx;
                        value       == 1'b1;
                        hold_cycles == 20;
                    })
                    `uvm_error("cpu_ect_eventin", "level-high randomize failed")
                level_seq.start(agent.sequencer);

                level_seq = cpu_ect_level_sequence::type_id::create("level_low");
                if (!level_seq.randomize() with {
                        loc         == CPU_ECT_CTI_EVT_IN;
                        index       == idx;
                        value       == 1'b0;
                        hold_cycles == 4;
                    })
                    `uvm_error("cpu_ect_eventin", "level-low randomize failed")
                level_seq.start(agent.sequencer);
            end
            else begin
                pulse_seq = cpu_ect_pulse_sequence::type_id::create("pulse_seq");
                if (!pulse_seq.randomize() with {
                        loc          == CPU_ECT_CTI_EVT_IN;
                        index        == idx;
                        value        == 1'b1;
                        pulse_cycles == 2;
                    })
                    `uvm_error("cpu_ect_eventin", "pulse randomize failed")
                pulse_seq.start(agent.sequencer);
            end

            repeat (2200) @(posedge agent.cfg.vif.clk);
            `uvm_info("cpu_ect_eventin",
                      $sformatf("event_in%0d route completed", idx), UVM_MEDIUM)
        end

        `uvm_info("cpu_ect_eventin", "done", UVM_LOW)
    endtask
endclass

`endif