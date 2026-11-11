`ifndef CPU_ECT_CONNECT_SVH
`define CPU_ECT_CONNECT_SVH

// Hierarchical base of the CPU ECT wrapper.  Override this macro before
// including cpu_ect_connect.svh if the instance name is different.
// Default: tb_top.u_dut
`ifndef CPU_ECT_DUT_HIER
`define CPU_ECT_DUT_HIER tb_top.u_dut
`endif

// ------------------------------------------------------------------
// Connect cpu_ect_if to `CPU_ECT_DUT_HIER using the signal paths from
// ECT_Event_Mapping.xlsx sheet sys_cpu.
//
// Usage: include this file inside tb_top AFTER cpu_ect_if is
// instantiated.  Source injection forces are enabled only with
// +CPU_ECT_ENABLE_SOURCE_FORCE.
// ------------------------------------------------------------------

// tb_top-local copies used as force RHS.  Some VCS versions do not resolve
// interface variables directly in hierarchical force statements.
logic [9:0]  cpu_cti_evt_in_force;
logic [15:0] cpu_cti_channel_in_force;
logic [5:0][3:0] cpu_clst_ctichout_force;
logic [15:0] cpu_cp2cp_async_pulse_out_force;
assign cpu_cti_evt_in_force = cpu_ect_if.cti_evt_in;
assign cpu_cti_channel_in_force = cpu_ect_if.cti_channel_in_drv;
assign cpu_clst_ctichout_force = cpu_ect_if.clst_ctichout_drv;
assign cpu_cp2cp_async_pulse_out_force = cpu_ect_if.cp2cp_async_pulse_out_drv;

// ---------------- CTI event_in: agent injection ----------------
initial begin
  if ($test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE")) begin
    force `CPU_ECT_DUT_HIER.u_cmns3_wrapper.u_cmns3_12_1.DBGWATCHTRIGREQ_NID68 =
      cpu_cti_evt_in_force[0];

    force `CPU_ECT_DUT_HIER.u_pmu_m14.cti_trig_out[1:0] =
      cpu_cti_evt_in_force[2:1];

    force `CPU_ECT_DUT_HIER.u_pmu_m15.cti_trig_out[1:0] =
      cpu_cti_evt_in_force[4:3];

    force `CPU_ECT_DUT_HIER.u_pmu_m16.cti_trig_out[1:0] =
      cpu_cti_evt_in_force[6:5];

    force `CPU_ECT_DUT_HIER.u_pmu_m17.cti_trig_out[1:0] =
      cpu_cti_evt_in_force[8:7];

    force `CPU_ECT_DUT_HIER.u_gic700_gicd_wrap_zj100.pmu_int =
      cpu_cti_evt_in_force[9];

    force `CPU_ECT_DUT_HIER.cti_channel_in[15:0] =
      cpu_cti_channel_in_force;
  end
end

// ---------------- CTI event_in handshake ack: observation ----------------
assign cpu_ect_if.cti_evt_in_ack =
  `CPU_ECT_DUT_HIER.u_cmns3_wrapper.u_cmns3_12_1.DBGWATCHTRIGACK_NID68;

// ---------------- CTI event_out: observation ----------------
assign cpu_ect_if.cti_evt_out[0] =
  `CPU_ECT_DUT_HIER.u_gic700_gicd_wrap_zj100.sample_req;

assign cpu_ect_if.cti_evt_out0_ack =
  `CPU_ECT_DUT_HIER.u_gic700_gicd_wrap_zj100.sample_ack;

assign cpu_ect_if.cti_evt_out[1] =
  `CPU_ECT_DUT_HIER.u_cmns3_wrapper.u_cmns3_12_1.PMUSNAPSHOTREQ_NID68;

assign cpu_ect_if.cti_evt_out1_ack =
  `CPU_ECT_DUT_HIER.u_cmns3_wrapper.u_cmns3_12_1.PMUSNAPSHOTACK_NID68;

assign cpu_ect_if.cti_evt_out[5:2] =
  `CPU_ECT_DUT_HIER.u_pmu_m14.cti_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[9:6] =
  `CPU_ECT_DUT_HIER.u_pmu_m15.cti_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[13:10] =
  `CPU_ECT_DUT_HIER.u_pmu_m16.cti_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[17:14] =
  `CPU_ECT_DUT_HIER.u_pmu_m17.cti_trig_in[3:0];

// Mapping records output18 with cti_trig_in[3:0]; this agent uses bit0.
assign cpu_ect_if.cti_evt_out[18] =
  `CPU_ECT_DUT_HIER.u_pmu_m18.cti_trig_in[0];
assign cpu_ect_if.cti_evt_out[19] =
  `CPU_ECT_DUT_HIER.u_ep2e_soc_tcu_pmusnapshot.pulse_in[0];

assign cpu_ect_if.cti_evt_out[20] =
  `CPU_ECT_DUT_HIER.u_ep2e_npu_tcu_pmusnapshot.pulse_in[0];

// ---------------- CTI channel views ----------------
assign cpu_ect_if.cti_channel_out =
  `CPU_ECT_DUT_HIER.u_css600_ctm_com.channel_out[111:96];

assign cpu_ect_if.cti_channel_in =
  `CPU_ECT_DUT_HIER.u_css600_ctm_com.channel_in[111:96];

// ---------------- Cluster handshake channel views ----------------
assign cpu_ect_if.clst_ctichout[0] =
  `CPU_ECT_DUT_HIER.u_cluster0.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0];
assign cpu_ect_if.clst_ctichout[1] =
  `CPU_ECT_DUT_HIER.u_cluster1.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0];
assign cpu_ect_if.clst_ctichout[2] =
  `CPU_ECT_DUT_HIER.u_cluster2.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0];
assign cpu_ect_if.clst_ctichout[3] =
  `CPU_ECT_DUT_HIER.u_cluster3.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0];
assign cpu_ect_if.clst_ctichout[4] =
  `CPU_ECT_DUT_HIER.u_cluster4.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0];
assign cpu_ect_if.clst_ctichout[5] =
  `CPU_ECT_DUT_HIER.u_cluster5.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0];

assign cpu_ect_if.clst_ctichoutack[0] =
  `CPU_ECT_DUT_HIER.u_cluster0.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUTACK[3:0];
assign cpu_ect_if.clst_ctichoutack[1] =
  `CPU_ECT_DUT_HIER.u_cluster1.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUTACK[3:0];
assign cpu_ect_if.clst_ctichoutack[2] =
  `CPU_ECT_DUT_HIER.u_cluster2.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUTACK[3:0];
assign cpu_ect_if.clst_ctichoutack[3] =
  `CPU_ECT_DUT_HIER.u_cluster3.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUTACK[3:0];
assign cpu_ect_if.clst_ctichoutack[4] =
  `CPU_ECT_DUT_HIER.u_cluster4.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUTACK[3:0];
assign cpu_ect_if.clst_ctichoutack[5] =
  `CPU_ECT_DUT_HIER.u_cluster5.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUTACK[3:0];

assign cpu_ect_if.clst_ctichinack[0] =
  `CPU_ECT_DUT_HIER.u_cluster0.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHINACK[3:0];
assign cpu_ect_if.clst_ctichinack[1] =
  `CPU_ECT_DUT_HIER.u_cluster1.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHINACK[3:0];
assign cpu_ect_if.clst_ctichinack[2] =
  `CPU_ECT_DUT_HIER.u_cluster2.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHINACK[3:0];
assign cpu_ect_if.clst_ctichinack[3] =
  `CPU_ECT_DUT_HIER.u_cluster3.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHINACK[3:0];
assign cpu_ect_if.clst_ctichinack[4] =
  `CPU_ECT_DUT_HIER.u_cluster4.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHINACK[3:0];
assign cpu_ect_if.clst_ctichinack[5] =
  `CPU_ECT_DUT_HIER.u_cluster5.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHINACK[3:0];

// ---------------- Cluster handshake injection ----------------
initial begin
  if ($test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE")) begin
    force `CPU_ECT_DUT_HIER.u_cluster0.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0] =
      cpu_clst_ctichout_force[0];
    force `CPU_ECT_DUT_HIER.u_cluster1.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0] =
      cpu_clst_ctichout_force[1];
    force `CPU_ECT_DUT_HIER.u_cluster2.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0] =
      cpu_clst_ctichout_force[2];
    force `CPU_ECT_DUT_HIER.u_cluster3.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0] =
      cpu_clst_ctichout_force[3];
    force `CPU_ECT_DUT_HIER.u_cluster4.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0] =
      cpu_clst_ctichout_force[4];
    force `CPU_ECT_DUT_HIER.u_cluster5.u_cpu_cluster_cpu_pwr_domain.u_HUNTER4_DEBUG_BLOCK_wrapper.u_HUNTER4_DEBUG_BLOCK.CTICHOUT[3:0] =
      cpu_clst_ctichout_force[5];
  end
end

// ---------------- CPU CTM cp2cp async-bridge views ----------------
assign cpu_ect_if.cp2cp_async_pulse_out =
  `CPU_ECT_DUT_HIER.u_cp2cp_async_trans.pulse_out[15:0];

assign cpu_ect_if.cp2cp_async_pulse_in =
  `CPU_ECT_DUT_HIER.u_cp2cp_async_rec.pulse_in[15:0];

// ---------------- CPU CTM cp2cp async-bridge injection ----------------
initial begin
  if ($test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE")) begin
    force `CPU_ECT_DUT_HIER.u_cp2cp_async_trans.pulse_out[15:0] =
      cpu_cp2cp_async_pulse_out_force;
  end
end

`endif
