// gic_injector: on pe_ready, drives spi_int[spi_id] active for hold_cycles,
// then de-asserts. level: hold_cycles>1; edge: hold_cycles=1.
module gic_injector #(parameter int N_SPI = 32) (
  input  logic             clk, rstn,
  input  logic             trigger,     // pe_ready pulse
  input  logic [15:0]      spi_id,
  input  logic [31:0]      hold_cycles,
  output logic [N_SPI-1:0] spi_int
);
  typedef enum logic [1:0] {WAIT, ASSERT, HOLD} st_t;
  st_t st;
  logic [31:0] cnt;
  always @(posedge clk) begin
    if (!rstn) begin st <= WAIT; spi_int <= 0; cnt <= 0; end
    else begin
      case (st)
        WAIT:   if (trigger) st <= ASSERT;
        ASSERT: begin spi_int[spi_id] <= 1'b1; cnt <= 0; st <= HOLD; end
        HOLD: begin
          if (cnt >= hold_cycles) begin spi_int[spi_id] <= 1'b0; st <= WAIT; end
          else cnt <= cnt + 1;
        end
      endcase
    end
  end
endmodule
