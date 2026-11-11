`ifndef CPU_ECT_CLUSTERS_CHOUT_TEST_SV
`define CPU_ECT_CLUSTERS_CHOUT_TEST_SV

//----------------------------------------------------------------------
// cp2cp pulse-out -> CTM -> {all cluster CTICHIN, system CTI channel-in,
// cp2cp pulse-in}.  This case does not force the system CTI channel-out.
//
// The cp2cp channel n is assumed to drive channel n at the system CTI and
// channel n of all six cluster CTICHIN ports.  The flattened cluster index
// is cluster*4 + channel.
//----------------------------------------------------------------------
class cpu_ect_clusters_chout_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_clusters_chout_test)

    localparam int unsigned N_CLST = 6;
    localparam int unsigned N_CH   = 4;
    localparam int unsigned N_CLST_IDX = N_CLST * N_CH;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        cpu_ect_pulse_sequence pulse_seq;
        int unsigned ch;
        int unsigned clst;
        int unsigned flat_idx;
        int unsigned idx;

        aw_seen = 1;
        `uvm_info("cpu_ect_clusters_chout", "begin", UVM_LOW)

        for (ch = 0; ch < N_CH; ch++) begin
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(ch),
                .expected_value(1'b1), .timeout_cycles(100));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(ch),
                .expected_value(1'b0), .timeout_cycles(200));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN), .index(ch),
                .expected_value(1'b1), .timeout_cycles(200));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_ASYNC_CHIN), .index(ch),
                .expected_value(1'b0), .timeout_cycles(200));

            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                .expected_value(1'b1), .timeout_cycles(200));
            agent.scoreboard.expect_event(
                .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                .expected_value(1'b0), .timeout_cycles(200));

            for (clst = 0; clst < N_CLST; clst++) begin
                flat_idx = clst * N_CH + ch;

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHIN), .index(flat_idx),
                    .expected_value(1'b1), .timeout_cycles(200));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHIN), .index(flat_idx),
                    .expected_value(1'b0), .timeout_cycles(200));

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHINACK), .index(flat_idx),
                    .expected_value(1'b1), .timeout_cycles(200));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHINACK), .index(flat_idx),
                    .expected_value(1'b0), .timeout_cycles(200));
            end

            for (idx = 0; idx < 16; idx++) begin
                if (idx != ch) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_ASYNC_CHIN_DRV), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_ASYNC_CHIN), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CTI_CH_IN), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                end
            end

            for (idx = 0; idx < N_CLST_IDX; idx++) begin
                if ((idx % N_CH) != ch) begin
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CLST_CHIN), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                    agent.scoreboard.expect_no_event(
                        .loc(CPU_ECT_CLST_CHINACK), .index(idx),
                        .forbidden_value(1'b1), .timeout_cycles(200));
                end
            end

            pulse_seq = cpu_ect_pulse_sequence::type_id::create("pulse_seq");
            if (!pulse_seq.randomize() with {
                    loc          == CPU_ECT_ASYNC_CHIN_DRV;
                    index        == ch;
                    value        == 1'b1;
                    pulse_cycles == 2;
                })
                `uvm_error("cpu_ect_clusters_chout", "pulse randomize failed")
            pulse_seq.start(agent.sequencer);

            repeat (300) @(posedge agent.cfg.vif.clk);
            `uvm_info("cpu_ect_clusters_chout",
                      $sformatf("cp2cp channel%0d -> all cluster CTICHIN completed", ch),
                      UVM_MEDIUM)
        end

        `uvm_info("cpu_ect_clusters_chout", "done", UVM_LOW)
    endtask
endclass

`endif
