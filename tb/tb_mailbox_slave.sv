// tb_mailbox_slave: a minimal AXI4-Lite write slave that decodes writes to
// TB_READY_ADDR / TB_RESULT_ADDR and pulses pe_ready / test_done(+result).
// The PE (running the .S test) writes these addresses over AXI.
module tb_mailbox_slave (
    input  logic        clk, rstn,
    input  logic [31:0] awaddr,  input logic awvalid, output logic awready,
    input  logic [31:0] wdata,   input logic wvalid,  output logic wready,
    output logic [1:0]  bresp,   output logic bvalid, input  logic bready,
    output logic        pe_ready, output logic test_done, output logic [31:0] test_result
    );
    import gic_tb_pkg::*;
    typedef enum logic [1:0] {IDLE, RESP} st_t;
    st_t st;
    always @(posedge clk) begin
        if (!rstn) begin
            st <= IDLE; awready <= 1; wready <= 1; bvalid <= 0; bresp <= 0;
            pe_ready <= 0; test_done <= 0; test_result <= 32'hxxxx_xxxx;
        end else begin
            pe_ready  <= 0;// single-cycle pulse
            test_done <= 0;// single-cycle pulse
            case (st)
                IDLE: begin
                    awready <= 1; wready <= 1;
                    if (awvalid && wvalid) begin
                        awready <= 0; wready <= 0; bvalid <= 1; bresp <= 2'b00; st <= RESP;
                        if      (awaddr == TB_READY_ADDR)  pe_ready <= 1;
                        else if (awaddr == TB_RESULT_ADDR) begin test_done <= 1; test_result <= wdata; end
                    end
                end
                RESP: if (bready) begin bvalid <= 0; st <= IDLE; end
            endcase
        end
    end
endmodule
