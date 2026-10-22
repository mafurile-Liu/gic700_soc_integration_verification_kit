`ifndef TIMESTAMP_SOURCE_IF_SV
`define TIMESTAMP_SOURCE_IF_SV

//----------------------------------------------------------------------
// Gray-code timestamp source.
//
// SYS_AON models the 31.25 MHz generic-counter tick.  Only the Gray
// output is intended for RTL; binary_count is the TB reference value
// used for waveform debug and SVA checking.
//----------------------------------------------------------------------
interface timestamp_source_if #(
    parameter int  WIDTH     = 64,
    parameter real FREQ_MHZ  = 31.25
) (
    input logic rst_n
);
    // 31.25 MHz => 32 ns period.
    localparam real CLK_PERIOD_NS = 1000.0 / FREQ_MHZ;

    logic                      timestamp_clk;
    logic                      source_valid;
    logic [WIDTH-1:0]          binary_count = '0;
    logic [WIDTH-1:0]          timestamp_gray;

    function automatic logic [WIDTH-1:0] gray_to_binary(
        input logic [WIDTH-1:0] gray
    );
        logic [WIDTH-1:0] binary;

        binary[WIDTH-1] = gray[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--)
            binary[i] = binary[i+1] ^ gray[i];
        return binary;
    endfunction

    initial begin
        timestamp_clk = 1'b0;
        source_valid  = 1'b0;

        if (rst_n !== 1'b1)
            @(posedge rst_n);
        source_valid = 1'b1;

        forever begin
            #(CLK_PERIOD_NS / 2.0);
            timestamp_clk = ~timestamp_clk;
        end
    end

    always_ff @(posedge timestamp_clk or negedge rst_n) begin
        if (!rst_n)
            binary_count <= '0;
        else if (source_valid)
            binary_count <= binary_count + 1'b1;
    end

    assign timestamp_gray = binary_count ^ (binary_count >> 1);

endinterface

`endif
