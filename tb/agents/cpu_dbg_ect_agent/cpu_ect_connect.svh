`ifndef CPU_ECT_CONNECT_SVH
`define CPU_ECT_CONNECT_SVH

// ------------------------------------------------------------------
// Connect cpu_ect_if to sys_cpu_pwr_wrap using the signal paths from
// ECT_Event_Mapping.xlsx sheet sys_cpu.
//
// Usage: include this file inside tb_top AFTER cpu_ect_if is
// instantiated.  Source injection forces are enabled only with
// +CPU_ECT_ENABLE_SOURCE_FORCE.
// ------------------------------------------------------------------

// ---------------- CTI event_in: agent injection ----------------
initial begin
  if ($test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE")) begin
    force sys_cpu_pwr_wrap.cmn2cti_event_pulse =
      cpu_ect_if.cti_evt_in[0];

    force sys_cpu_pwr_wrap.pmu_m14_trig_out[1:0] =
      cpu_ect_if.cti_evt_in[2:1];

    force sys_cpu_pwr_wrap.pmu_m15_trig_out[1:0] =
      cpu_ect_if.cti_evt_in[4:3];

    force sys_cpu_pwr_wrap.pmu_m16_trig_out[1:0] =
      cpu_ect_if.cti_evt_in[6:5];

    force sys_cpu_pwr_wrap.pmu_m17_trig_out[1:0] =
      cpu_ect_if.cti_evt_in[8:7];

    force sys_cpu_pwr_wrap.gicd_pmu_int_event =
      cpu_ect_if.cti_evt_in[9];

    force sys_cpu_pwr_wrap.soc_tcu_pmusnapshot =
      cpu_ect_if.cti_evt_in[10];

    force sys_cpu_pwr_wrap.npu_tcu_pmusnapshot =
      cpu_ect_if.cti_evt_in[11];

    force sys_cpu_pwr_wrap.cti_channel_in[15:0] =
      cpu_ect_if.cti_channel_in;
  end
end

// ---------------- CTI event_out: observation ----------------
assign cpu_ect_if.cti_evt_out[0] =
  sys_cpu_pwr_wrap.cti2gicd_event_pulse;

assign cpu_ect_if.cti_evt_out[1] =
  sys_cpu_pwr_wrap.cti2cmn_event_pulse;

assign cpu_ect_if.cti_evt_out[5:2] =
  sys_cpu_pwr_wrap.pmu_m14_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[9:6] =
  sys_cpu_pwr_wrap.pmu_m15_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[13:10] =
  sys_cpu_pwr_wrap.pmu_m16_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[17:14] =
  sys_cpu_pwr_wrap.pmu_m17_trig_in[3:0];

assign cpu_ect_if.cti_evt_out[18] =
  sys_cpu_pwr_wrap.dbm_cfgbus_trig;

// ---------------- CTI channel views ----------------
assign cpu_ect_if.cti_channel_out =
  sys_cpu_pwr_wrap.cti_channel_out[15:0];

assign cpu_ect_if.cti_channel_in =
  sys_cpu_pwr_wrap.cti_channel_in[15:0];

// ---------------- CPU-cluster CTI channel views ----------------
assign cpu_ect_if.clst_cti_pulse_out[0] =
  sys_cpu_pwr_wrap.clst0_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[1] =
  sys_cpu_pwr_wrap.clst1_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[2] =
  sys_cpu_pwr_wrap.clst2_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[3] =
  sys_cpu_pwr_wrap.clst3_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[4] =
  sys_cpu_pwr_wrap.clst4_cti_pulse_out[3:0];
assign cpu_ect_if.clst_cti_pulse_out[5] =
  sys_cpu_pwr_wrap.clst5_cti_pulse_out[3:0];

assign cpu_ect_if.clst_cti_pulse_in[0] =
  sys_cpu_pwr_wrap.clst0_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[1] =
  sys_cpu_pwr_wrap.clst1_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[2] =
  sys_cpu_pwr_wrap.clst2_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[3] =
  sys_cpu_pwr_wrap.clst3_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[4] =
  sys_cpu_pwr_wrap.clst4_cti_pulse_in[3:0];
assign cpu_ect_if.clst_cti_pulse_in[5] =
  sys_cpu_pwr_wrap.clst5_cti_pulse_in[3:0];

// ---------------- CPU-cluster CTM input injection ----------------
// VCS resolves tb_top-local intermediates reliably in hierarchical forces.
logic [5:0][3:0] cpu_clst_cti_pulse_out_force;
logic [15:0] cpu_asyncbridge_2_ctm_force;
assign cpu_clst_cti_pulse_out_force = cpu_ect_if.clst_cti_pulse_out_drv;
assign cpu_asyncbridge_2_ctm_force = cpu_ect_if.asyncbridge_2_ctm_pulse_drv;

initial begin
  if ($test$plusargs("CPU_ECT_ENABLE_SOURCE_FORCE")) begin
    force sys_cpu_pwr_wrap.clst0_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[0];
    force sys_cpu_pwr_wrap.clst1_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[1];
    force sys_cpu_pwr_wrap.clst2_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[2];
    force sys_cpu_pwr_wrap.clst3_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[3];
    force sys_cpu_pwr_wrap.clst4_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[4];
    force sys_cpu_pwr_wrap.clst5_cti_pulse_out[3:0] = cpu_clst_cti_pulse_out_force[5];
    force sys_cpu_pwr_wrap.asyncbridge_2_ctm_pulse[15:0] = cpu_asyncbridge_2_ctm_force;
  end
end
// ---------------- CPU CTM async-bridge views ----------------
assign cpu_ect_if.asyncbridge_2_ctm_pulse =
  sys_cpu_pwr_wrap.asyncbridge_2_ctm_pulse[15:0];

assign cpu_ect_if.ctm_2_asyncbridge_pulse =
  sys_cpu_pwr_wrap.ctm_2_asyncbridge_pulse[15:0];

`endif
