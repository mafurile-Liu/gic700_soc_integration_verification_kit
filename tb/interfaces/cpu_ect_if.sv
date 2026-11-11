// ------------------------------------------------------------------
// CPU subsystem ECT verification interface.
//
// Signal map source: ECT_Event_Mapping.xlsx sheet sys_cpu.
// Vectors are flattened even when the RTL sources are packed fields.
// Handshake req/ack are exposed separately.
// ------------------------------------------------------------------
interface cpu_ect_if(input logic clk, input logic rst_n);

  // CTI input triggers.  Index matches sys_cpu.
  // Index0 is handshake.  Index9 is level.
  logic [9:0]  cti_evt_in     = '0;
  logic        cti_evt_in_ack;

  // CTI output triggers.  Index matches sys_cpu.
  // Index0/1 are handshake; other mapped outputs are pulse.
  logic [20:0] cti_evt_out;
  logic        cti_evt_out0_ack;
  logic        cti_evt_out1_ack;

  // css600_cti_com channel views.
  logic [15:0] cti_channel_out; // CTI -> CTM
  logic [15:0] cti_channel_in;  // CTM -> CTI observation
  logic [15:0] cti_channel_in_drv = '0; // CTM -> CTI injection

  // Six CPU-cluster debug-block handshake channel views (4 bits each).
  logic [5:0][3:0] clst_ctichout;
  logic [5:0][3:0] clst_ctichoutack;
  logic [5:0][3:0] clst_ctichinack;
  logic [5:0][3:0] clst_ctichout_drv = '0;

  // CPU CTM cp2cp async-bridge views.
  logic [15:0] cp2cp_async_pulse_out;
  logic [15:0] cp2cp_async_pulse_in;
  logic [15:0] cp2cp_async_pulse_out_drv = '0;

  modport drv_mp(
    input  clk,
    input  rst_n,
    output cti_evt_in,
    output cti_channel_in_drv,
    output clst_ctichout_drv,
    output cp2cp_async_pulse_out_drv,
    input  cti_evt_in_ack,
    input  cti_evt_out,
    input  cti_evt_out0_ack,
    input  cti_evt_out1_ack,
    input  cti_channel_out,
    input  cti_channel_in,
    input  clst_ctichout,
    input  clst_ctichoutack,
    input  clst_ctichinack,
    input  cp2cp_async_pulse_out,
    input  cp2cp_async_pulse_in
  );

  modport mon_mp(
    input clk,
    input rst_n,
    input cti_evt_in,
    input cti_evt_in_ack,
    input cti_evt_out,
    input cti_evt_out0_ack,
    input cti_evt_out1_ack,
    input cti_channel_out,
    input cti_channel_in,
    input cti_channel_in_drv,
    input clst_ctichout,
    input clst_ctichoutack,
    input clst_ctichinack,
    input clst_ctichout_drv,
    input cp2cp_async_pulse_out,
    input cp2cp_async_pulse_in,
    input cp2cp_async_pulse_out_drv
  );

endinterface