// ------------------------------------------------------------------
// CPU subsystem ECT verification interface.
//
// Signal map source: ECT_Event_Mapping.xlsx sheet sys_cpu.
// The vectors are flattened even when the RTL sources are packed fields.
// ------------------------------------------------------------------
interface cpu_ect_if(input logic clk, input logic rst_n);

  // CTI input triggers.  Index matches the sys_cpu mapping.
  // bit 9 is the only level-type input in the current map.
  logic [11:0] cti_evt_in = '0;

  // CTI output triggers.  Current mapping uses 0..18.
  logic [18:0] cti_evt_out;

  // css600_cti_com channel views.
  logic [15:0] cti_channel_out; // CTI -> CTM
  logic [15:0] cti_channel_in;      // CTM -> CTI observation
  logic [15:0] cti_channel_in_drv = '0; // agent injection

  // Six CPU-cluster CTI channel views (4 bits each).
  logic [5:0][3:0] clst_cti_pulse_out;
  logic [5:0][3:0] clst_cti_pulse_out_drv = '0;
  logic [5:0][3:0] clst_cti_pulse_in;

  // CPU CTM async-bridge views.
  logic [15:0] asyncbridge_2_ctm_pulse;
  logic [15:0] asyncbridge_2_ctm_pulse_drv = '0;
  logic [15:0] ctm_2_asyncbridge_pulse;

  modport drv_mp(
    input  clk,
    input  rst_n,
    output cti_evt_in,
    output cti_channel_in_drv,
    output clst_cti_pulse_out_drv,
    output asyncbridge_2_ctm_pulse_drv,
    input  cti_evt_out,
    input  cti_channel_out,
    input  clst_cti_pulse_out,
    input  clst_cti_pulse_in,
    input  asyncbridge_2_ctm_pulse,
    input  ctm_2_asyncbridge_pulse
  );

  modport mon_mp(
    input clk,
    input rst_n,
    input cti_evt_in,
    input cti_evt_out,
    input cti_channel_out,
    input cti_channel_in,
    input cti_channel_in_drv,
    input clst_cti_pulse_out,
    input clst_cti_pulse_out_drv,
    input clst_cti_pulse_in,
    input asyncbridge_2_ctm_pulse,
    input asyncbridge_2_ctm_pulse_drv,
    input ctm_2_asyncbridge_pulse
  );

endinterface
