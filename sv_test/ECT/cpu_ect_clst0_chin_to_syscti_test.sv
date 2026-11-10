`ifndef CPU_ECT_CLST0_CHIN_TO_SYSCTI_TEST_SV
`define CPU_ECT_CLST0_CHIN_TO_SYSCTI_TEST_SV

//----------------------------------------------------------------------
// Cluster0 CTI channel-out -> CPU system CTM -> system CTI channel-in.
//
// This case does not require CTI register programming.  It injects the
// four cluster0 channels and checks that system CTI observes the lower
// four CTM channels.
//----------------------------------------------------------------------
class cpu_ect_clst0_chin_to_syscti_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_clst0_chin_to_syscti_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;
        int unsigned ch;

        aw_seen = 1;
        `uvm_info("cpu_ect_clst0_chin", "begin", UVM_LOW)

        for (ch = 0; ch < 4; ch++) begin
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CLST_CH_IN_DRV), .index(ch),
                .expected_value(1'b1), .timeout_cycles(1000));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CLST_CH_IN_DRV), .index(ch),
                .expected_value(1'b0), .timeout_cycles(1000));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                .expected_value(1'b1), .timeout_cycles(1000));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                .expected_value(1'b0), .timeout_cycles(1000));

            for (int unsigned other = 0; other < 4; other++) begin
                if (other != ch) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CLST_CH_IN_DRV), .index(other),
                        .forbidden_value(1'b1), .timeout_cycles(2000));
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CTI_CH_IN), .index(other),
                        .forbidden_value(1'b1), .timeout_cycles(2000));
                end
            end

            pulse_seq = cpu_ect_pulse_sequence::type_id::create("pulse_seq");
            if (!pulse_seq.randomize() with {
                    loc          == CPU_ECT_CLST_CH_IN_DRV;
                    index        == ch;
                    value        == 1'b1;
                    pulse_cycles == 2;
                })
                `uvm_error("cpu_ect_clst0_chin", "pulse randomize failed")
            pulse_seq.start(agent.sequencer);

            repeat (2200) @(posedge agent.cfg.vif.clk);
            `uvm_info("cpu_ect_clst0_chin",
                      $sformatf("cluster0 channel%0d -> system CTI completed", ch),
                      UVM_MEDIUM)
        end

        `uvm_info("cpu_ect_clst0_chin", "done", UVM_LOW)
    endtask
endclass

`endif