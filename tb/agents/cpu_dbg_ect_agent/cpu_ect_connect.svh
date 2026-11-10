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
logic [11:0] cpu_cti_evt_in_force;
logic [15:0] cpu_cti_channel_in_force;
assign cpu_cti_evt_in_force = cpu_ect_if.cti_evt_in;
assign cpu_cti_channel_in_force = cpu_ect_if.cti_channel_in_drv;

// ---------------- CTI event_in: agent injection ----------------
initial begin
  if ($test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE")) begin
    force `CPU_ECT_DUT_HIER.cmn2cti_event_pulse =
      cpu_cti_evt_in_force[0];

    force `CPU_ECT_DUT_HIER.pmu_m14_trig_out[1:0] =
      cpu_cti_evt_in_force[2:1];

    force `CPU_ECT_DUT_HIER.pmu_m15_trig_out[1:0] =
      cpu_cti_evt_in_force[4:3];

    force `CPU_ECT_DUT_HIER.pmu_m16_trig_out[1:0] =
      cpu_cti_evt_in_force[6:5];

    force `CPU_ECT_DUT_HIER.pmu_m17_trig_out[1:0] =
      cpu_cti_evt_in_force[8:7];

    force `CPU_ECT_DUT_HIER.gicd_pmu_int_event =
      cpu_cti_evt_in_force[9];

    force `CPU_ECT_DUT_HIER.soc_tcu_pmusnapshot =
      cpu_cti_evt_in_force[10];

    force `CPU_ECT_DUT_HIER.npu_tcu_pmusnapshot =
      cpu_cti_evt_in_force[11];

    force `CPU_ECT_DUT_HIER.cti_channel_in[15:0] =
      cpu_cti_channel_in_force;
  end
end

// ---------------- CTI event_out: observation ----------------
assign cpu_ect_if.cti_evt_out[0] =
  `CPU_ECT_DUT_HIER.cti2gicd_event_pulse;

assign cpu_ect_if.cti_evt_out[1] =
  `CPU_ECT_DUT_HIER.cti2cmn_event_pulse;

assign cpu_ect_if.cti_evt_out[5:2] =
  `CPU_ECT_DUT_HIER.pmu_m14_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[9:6] =
  `CPU_ECT_DUT_HIER.pmu_m15_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[13:10] =
  `CPU_ECT_DUT_HIER.pmu_m16_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[17:14] =
  `CPU_ECT_DUT_HIER.pmu_m17_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[18] =
  `CPU_ECT_DUT_HIER.dbm_cfgbus_trig;

// ---------------- CTI channel views ----------------
assign cpu_ect_if.cti_channel_out =
  `CPU_ECT_DUT_HIER.cti_channel_out[15:0];

assign cpu_ect_if.cti_channel_in =
  `CPU_ECT_DUT_HIER.cti_channel_in[15:0];

// ---------------- CPU-cluster CTI channel views ----------------
assign cpu_ect_if.clst_cti_pulse_out[0] =
  `CPU_ECT_DUT_HIER.clst0_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[1] =
  `CPU_ECT_DUT_HIER.clst1_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[2] =
  `CPU_ECT_DUT_HIER.clst2_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[3] =
  `CPU_ECT_DUT_HIER.clst3_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[4] =
  `CPU_ECT_DUT_HIER.clst4_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[5] =
  `CPU_ECT_DUT_HIER.clst5_cti_pulse_out[3:0];

assign cpu_ect_if.clst_cti_pulse_in[0] =
  `CPU_ECT_DUT_HIER.clst0_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[1] =
  `CPU_ECT_DUT_HIER.clst1_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[2] =
  `CPU_ECT_DUT_HIER.clst2_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[3] =
  `CPU_ECT_DUT_HIER.clst3_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[4] =
  `CPU_ECT_DUT_HIER.clst4_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[5] =
  `CPU_ECT_DUT_HIER.clst5_cti_pulse_in[3:0];

// ---------------- CPU-cluster CTM input injection ----------------
// VCS resolves tb_top-local intermediates reliably in hierarchical forces.
logic [5:0][3:0] cpu_clst_cti_pulse_out_force;
logic [15:0] cpu_asyncbridge_2_ctm_force;
assign cpu_clst_cti_pulse_out_force = cpu_ect_if.clst_cti_pulse_out_drv;
assign cpu_asyncbridge_2_ctm_force = cpu_ect_if.asyncbridge_2_ctm_pulse_drv;

initial begin
  if ($test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE")) begin
    force `CPU_ECT_DUT_HIER.clst0_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[0];
    force `CPU_ECT_DUT_HIER.clst1_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[1];
    force `CPU_ECT_DUT_HIER.clst2_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[2];
    force `CPU_ECT_DUT_HIER.clst3_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[3];
    force `CPU_ECT_DUT_HIER.clst4_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[4];
    force `CPU_ECT_DUT_HIER.clst5_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[5];
    force `CPU_ECT_DUT_HIER.asyncbridge_2_ctm_pulse[15:0] = cpu_asyncbridge_2_ctm_force;
  end
end
// ---------------- CPU CTM async-bridge views ----------------
assign cpu_ect_if.asyncbridge_2_ctm_pulse =
  `CPU_ECT_DUT_HIER.asyncbridge_2_ctm_pulse[15:0];

assign cpu_ect_if.ctm_2_asyncbridge_pulse =
  `CPU_ECT_DUT_HIER.ctm_2_asyncbridge_pulse[15:0];

`endif
