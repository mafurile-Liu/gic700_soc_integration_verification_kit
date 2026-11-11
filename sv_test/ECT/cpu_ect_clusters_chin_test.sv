`ifndef CPU_ECT_CLUSTERS_CHIN_TEST_SV
`define CPU_ECT_CLUSTERS_CHIN_TEST_SV

//----------------------------------------------------------------------
// All six cluster CTICHOUT -> CTM -> {system CTI channel-in, cp2cp
// pulse-in}.  The flattened cluster index is cluster*4 + channel.
//
// For every cluster/channel injection:
//   1. check the cluster-side CTICHOUT/CTICHOUTACK handshake;
//   2. check the corresponding system-CTI channel-in pulse;
//   3. check the corresponding cp2cp async-bridge pulse-in;
//   4. check cross-talk on all three sides.
//----------------------------------------------------------------------
class cpu_ect_clusters_chin_test extends cpu_ect_base_test;
    `uvm_component_utils(cpu_ect_clusters_chin_test)

    localparam int unsigned N_CLST = 6;
    localparam int unsigned N_CH   = 4;
    localparam int unsigned N_CLST_IDX = N_CLST * N_CH;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task test_body();
        cpu_ect_handshake_sequence handshake_seq;
        int unsigned clst;
        int unsigned ch;
        int unsigned flat_idx;
        int unsigned idx;

        aw_seen = 1;
        `uvm_info("cpu_ect_clusters_chin", "begin", UVM_LOW)

        for (clst = 0; clst < N_CLST; clst++) begin
            for (ch = 0; ch < N_CH; ch++) begin
                flat_idx = clst * N_CH + ch;

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHOUT_DRV), .index(flat_idx),
                    .expected_value(1'b1), .timeout_cycles(100));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHOUT_DRV), .index(flat_idx),
                    .expected_value(1'b0), .timeout_cycles(200));

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHOUT_ACK), .index(flat_idx),
                    .expected_value(1'b1), .timeout_cycles(100));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CLST_CHOUT_ACK), .index(flat_idx),
                    .expected_value(1'b0), .timeout_cycles(200));

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                    .expected_value(1'b1), .timeout_cycles(200));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_CTI_CH_IN), .index(ch),
                    .expected_value(1'b0), .timeout_cycles(200));

                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_ASYNC_CHIN), .index(ch),
                    .expected_value(1'b1), .timeout_cycles(200));
                agent.scoreboard.expect_event(
                    .loc(CPU_ECT_ASYNC_CHIN), .index(ch),
                    .expected_value(1'b0), .timeout_cycles(200));

                for (idx = 0; idx < N_CLST_IDX; idx++) begin
                    if (idx != flat_idx) begin
                        agent.scoreboard.expect_no_event(
                            .loc(CPU_ECT_CLST_CHOUT_DRV), .index(idx),
                            .forbidden_value(1'b1), .timeout_cycles(200));
                        agent.scoreboard.expect_no_event(
                            .loc(CPU_ECT_CLST_CHOUT_ACK), .index(idx),
                            .forbidden_value(1'b1), .timeout_cycles(200));
                    end
                end

                for (idx = 0; idx < 16; idx++) begin
                    if (idx != ch) begin
                        agent.scoreboard.expect_no_event(
                            .loc(CPU_ECT_CTI_CH_IN), .index(idx),
                            .forbidden_value(1'b1), .timeout_cycles(200));
                        agent.scoreboard.expect_no_event(
                            .loc(CPU_ECT_ASYNC_CHIN), .index(idx),
                            .forbidden_value(1'b1), .timeout_cycles(200));
                    end
                end

                handshake_seq = cpu_ect_handshake_sequence::type_id::create(
                    "handshake_seq");
                if (!handshake_seq.randomize() with {
                        loc            == CPU_ECT_CLST_CHOUT_DRV;
                        index          == flat_idx;
                        timeout_cycles == 100;
                    })
                    `uvm_error("cpu_ect_clusters_chin",
                               "handshake randomize failed")
                handshake_seq.start(agent.sequencer);

                repeat (300) @(posedge agent.cfg.vif.clk);
                `uvm_info("cpu_ect_clusters_chin",
                          $sformatf("cluster%0d CTICHOUT%0d -> CTI/cp2cp completed",
                                    clst, ch), UVM_MEDIUM)
            end
        end

        `uvm_info("cpu_ect_clusters_chin", "done", UVM_LOW)
    endtask
endclass

`endif
