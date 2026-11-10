typedef enum int unsigned {
  CPU_ECT_CTI_EVT_IN   = 0,
  CPU_ECT_CTI_EVT_OUT  = 1,
  CPU_ECT_CTI_CH_IN    = 2,
  CPU_ECT_CTI_CH_OUT   = 3,
  CPU_ECT_CLST_CH_IN   = 4,
  CPU_ECT_CLST_CH_OUT  = 5,
  CPU_ECT_ASYNC_CH_IN  = 6,
  CPU_ECT_ASYNC_CH_OUT = 7,
  CPU_ECT_CLST_CH_IN_DRV  = 8,
  CPU_ECT_ASYNC_CH_IN_DRV = 9,
  CPU_ECT_CTI_CH_IN_DRV   = 10
} cpu_ect_loc_e;

function automatic int unsigned cpu_ect_loc_width(cpu_ect_loc_e loc);
  case (loc)
    CPU_ECT_CTI_EVT_IN   : return 12;
    CPU_ECT_CTI_EVT_OUT  : return 19;
    CPU_ECT_CTI_CH_IN    : return 16;
    CPU_ECT_CTI_CH_IN_DRV : return 16;
    CPU_ECT_CTI_CH_OUT   : return 16;
    CPU_ECT_CLST_CH_IN   : return 24;
    CPU_ECT_CLST_CH_OUT  : return 24;
    CPU_ECT_CLST_CH_IN_DRV  : return 24;
    CPU_ECT_ASYNC_CH_IN_DRV : return 16;
    CPU_ECT_ASYNC_CH_IN  : return 16;
    CPU_ECT_ASYNC_CH_OUT : return 16;
    default              : return 0;
  endcase
endfunction

// Per ECT_Event_Mapping sheet sys_cpu.  Only GICD PMU event is level type.
function automatic bit cpu_ect_evt_in_is_level(int unsigned index);
  return (index == 9);
endfunction

function automatic logic cpu_ect_sample_bit(
  virtual cpu_ect_if vif,
  cpu_ect_loc_e      loc,
  int unsigned       index
);
  case (loc)
    CPU_ECT_CTI_EVT_IN   : return vif.cti_evt_in[index];
    CPU_ECT_CTI_EVT_OUT  : return vif.cti_evt_out[index];
    CPU_ECT_CTI_CH_IN    : return vif.cti_channel_in[index];
    CPU_ECT_CTI_CH_IN_DRV : return vif.cti_channel_in_drv[index];
    CPU_ECT_CTI_CH_OUT   : return vif.cti_channel_out[index];
    CPU_ECT_CLST_CH_IN   : return vif.clst_cti_pulse_in[index/4][index%4];
    CPU_ECT_CLST_CH_IN_DRV  : return vif.clst_cti_pulse_out_drv[index/4][index%4];
    CPU_ECT_ASYNC_CH_IN_DRV : return vif.asyncbridge_2_ctm_pulse_drv[index];
    CPU_ECT_CLST_CH_OUT  : return vif.clst_cti_pulse_out[index/4][index%4];
    CPU_ECT_ASYNC_CH_IN  : return vif.asyncbridge_2_ctm_pulse[index];
    CPU_ECT_ASYNC_CH_OUT : return vif.ctm_2_asyncbridge_pulse[index];
    default              : return 1'bx;
  endcase
endfunction

function automatic void cpu_ect_drive_bit(
  virtual cpu_ect_if vif,
  cpu_ect_loc_e      loc,
  int unsigned       index,
  logic              value
);
  case (loc)
    CPU_ECT_CTI_EVT_IN : vif.cti_evt_in[index]    = value;
    CPU_ECT_CTI_CH_IN_DRV : vif.cti_channel_in_drv[index] = value;
    CPU_ECT_CLST_CH_IN_DRV  : vif.clst_cti_pulse_out_drv[index/4][index%4] = value;
    CPU_ECT_ASYNC_CH_IN_DRV : vif.asyncbridge_2_ctm_pulse_drv[index] = value;
    default: `uvm_warning("CPU_ECT_DRV",
      $sformatf("Location %s is not an injection path", loc.name()))
  endcase
endfunction
