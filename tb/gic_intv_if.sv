// gic_intv_if: interrupt-injection interface. The injector drives spi_int into
// the GIC SPI Collator; the mailbox slave drives the sync/result signals.
interface gic_intv_if #(parameter int N_SPI = 32) (input logic clk, input logic rstn);
  logic [N_SPI-1:0] spi_int;     // SPI input wires to GIC (active-high)
  logic             pe_ready;    // pulse: PE wrote TB_READY_ADDR (ready for inject)
  logic             test_done;   // pulse: PE wrote TB_RESULT_ADDR
  logic [31:0]      test_result; // 0=pass, 1=fail
  modport inj (output spi_int, input pe_ready, input clk, input rstn);
  modport mb  (output pe_ready, output test_done, output test_result);
  modport sb  (input test_done, input test_result, input clk, input rstn);
endinterface
