// GIC interrupt injection/monitor interface.
// SPI: bidirectional - spi_int_in (TB injects into GIC), spi_int_out (CPU subsystem
//   produces, TB monitors). PPI: per-PE, TB injects.
interface gic_int_if #(
  parameter int N_SPI = 960,
  parameter int N_PPI = 48,
  parameter int N_PE  = 1
) (input logic clk, input logic rstn);
  logic [N_SPI-1:0] spi_int_in;    // external -> GIC (injection direction)
  logic [N_SPI-1:0] spi_int_out;   // GIC/CPU -> external (output direction, monitor only)
  logic [N_PE-1:0][N_PPI-1:0] ppi_int;  // per-PE PPI (injection)
  modport drv (output spi_int_in, output ppi_int, input clk, input rstn);
  modport mon (input spi_int_in, input spi_int_out, input ppi_int, input clk, input rstn);
endinterface
