typedef enum int unsigned {
  CPU_ECT_CTI_EVT_IN       = 0,
  CPU_ECT_CTI_EVT_IN_ACK   = 1,
  CPU_ECT_CTI_EVT_OUT      = 2,
  CPU_ECT_CTI_EVT_OUT_ACK  = 3,
  CPU_ECT_CTI_CH_IN        = 4,
  CPU_ECT_CTI_CH_IN_DRV    = 5,
  CPU_ECT_CTI_CH_OUT       = 6,
  CPU_ECT_CLST_CHOUT       = 7,
  CPU_ECT_CLST_CHOUT_ACK   = 8,
  CPU_ECT_CLST_CHINACK     = 9,
  CPU_ECT_CLST_CHOUT_DRV   = 10,
  CPU_ECT_ASYNC_CHOUT      = 11,
  CPU_ECT_ASYNC_CHIN       = 12,
  CPU_ECT_ASYNC_CHIN_DRV   = 13
} cpu_ect_loc_e;

function automatic int unsigned cpu_ect_loc_width(cpu_ect_loc_e loc);
  case (loc)
    CPU_ECT_CTI_EVT_IN      : return 10;
    CPU_ECT_CTI_EVT_IN_ACK  : return 1;
    CPU_ECT_CTI_EVT_OUT     : return 19;
    CPU_ECT_CTI_EVT_OUT_ACK : return 2;
    CPU_ECT_CTI_CH_IN       : return 16;
    CPU_ECT_CTI_CH_IN_DRV   : return 16;
    CPU_ECT_CTI_CH_OUT      : return 16;
    CPU_ECT_CLST_CHOUT      : return 24;
    CPU_ECT_CLST_CHOUT_ACK  : return 24;
    CPU_ECT_CLST_CHINACK    : return 24;
    CPU_ECT_CLST_CHOUT_DRV  : return 24;
    CPU_ECT_ASYNC_CHOUT     : return 16;
    CPU_ECT_ASYNC_CHIN      : return 16;
    CPU_ECT_ASYNC_CHIN_DRV  : return 16;
    default                 : return 0;
  endcase
endfunction

// Per latest ECT_Event_Mapping sheet sys_cpu.
function automatic bit cpu_ect_evt_in_is_handshake(int unsigned index);
  return (index == 0);
endfunction

function automatic bit cpu_ect_evt_in_is_level(int unsigned index);
  return (index == 9);
endfunction

function automatic bit cpu_ect_evt_out_is_handshake(int unsigned index);
  return (index == 0) || (index == 1);
endfunction

function automatic logic cpu_ect_sample_bit(
  virtual cpu_ect_if vif,
  cpu_ect_loc_e      loc,
  int unsigned       index
);
  case (loc)
    CPU_ECT_CTI_EVT_IN      : return vif.cti_evt_in[index];
    CPU_ECT_CTI_EVT_IN_ACK  : return vif.cti_evt_in_ack;
    CPU_ECT_CTI_EVT_OUT     : return vif.cti_evt_out[index];
    CPU_ECT_CTI_EVT_OUT_ACK : return index == 0 ?
                                  vif.cti_evt_out0_ack :
                                  vif.cti_evt_out1_ack;
    CPU_ECT_CTI_CH_IN       : return vif.cti_channel_in[index];
    CPU_ECT_CTI_CH_IN_DRV   : return vif.cti_channel_in_drv[index];
    CPU_ECT_CTI_CH_OUT      : return vif.cti_channel_out[index];
    CPU_ECT_CLST_CHOUT      : return vif.clst_ctichout[index/4][index%4];
    CPU_ECT_CLST_CHOUT_ACK  : return vif.clst_ctichoutack[index/4][index%4];
    CPU_ECT_CLST_CHINACK    : return vif.clst_ctichinack[index/4][index%4];
    CPU_ECT_CLST_CHOUT_DRV  : return vif.clst_ctichout_drv[index/4][index%4];
    CPU_ECT_ASYNC_CHOUT     : return vif.cp2cp_async_pulse_out[index];
    CPU_ECT_ASYNC_CHIN      : return vif.cp2cp_async_pulse_in[index];
    CPU_ECT_ASYNC_CHIN_DRV  : return vif.cp2cp_async_pulse_out_drv[index];
    default                 : return 1'bx;
  endcase
endfunction

function automatic bit cpu_ect_ack_exists(
  cpu_ect_loc_e loc,
  int unsigned  index
);
  case (loc)
    CPU_ECT_CTI_EVT_IN     : return index == 0;
    CPU_ECT_CLST_CHOUT_DRV : return 1'b1;
    default                : return 1'b0;
  endcase
endfunction

function automatic logic cpu_ect_sample_ack(
  virtual cpu_ect_if vif,
  cpu_ect_loc_e      loc,
  int unsigned       index
);
  case (loc)
    CPU_ECT_CTI_EVT_IN     : return vif.cti_evt_in_ack;
    CPU_ECT_CLST_CHOUT_DRV : return
      vif.clst_ctichoutack[index/4][index%4];
    default                : return 1'b0;
  endcase
endfunction

function automatic void cpu_ect_drive_bit(
  virtual cpu_ect_if vif,
  cpu_ect_loc_e      loc,
  int unsigned       index,
  logic              value
);
  case (loc)
    CPU_ECT_CTI_EVT_IN     : vif.cti_evt_in[index] = value;
    CPU_ECT_CTI_CH_IN_DRV  : vif.cti_channel_in_drv[index] = value;
    CPU_ECT_CLST_CHOUT_DRV : vif.clst_ctichout_drv[index/4][index%4] = value;
    CPU_ECT_ASYNC_CHIN_DRV : vif.cp2cp_async_pulse_out_drv[index] = value;
    default: `uvm_warning("CPU_ECT_DRV",
      $sformatf("Location %s is not an injection path", loc.name()))
  endcase
endfunction