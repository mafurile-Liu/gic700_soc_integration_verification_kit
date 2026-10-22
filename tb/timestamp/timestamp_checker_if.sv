`ifndef TIMESTAMP_CHECKER_IF_SV
`define TIMESTAMP_CHECKER_IF_SV

//----------------------------------------------------------------------
// Destination-side timestamp checks.
//
// Instantiate one checker per destination clock.  rtl_binary_timestamp
// must be the RTL Gray-to-binary result.  rtl_shifted_timestamp must be
// that binary value shifted left by SHIFT bits (32x for SHIFT=5).
//
// The source Gray value is held stable for SETTLE_CYCLES before each
// check so that the RTL synchronizer/CDC latency does not cause false
// failures while the source is changing.
//----------------------------------------------------------------------
interface timestamp_checker_if #(
    parameter int WIDTH         = 64,
    parameter int SHIFT         = 5,
    parameter int SETTLE_CYCLES = 4
) (
    input logic dest_clk,
    input logic dest_rst_n,
    input logic check_enable,
    input logic [WIDTH-1:0] rtl_binary_timestamp,
    input logic [WIDTH-1:0] rtl_shifted_timestamp,
    input logic source_valid,
    input logic [WIDTH-1:0] source_gray
);

    function automatic logic [WIDTH-1:0] gray_to_binary(
        input logic [WIDTH-1:0] gray
    );
        logic [WIDTH-1:0] binary;

        binary[WIDTH-1] = gray[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--)
            binary[i] = binary[i+1] ^ gray[i];
        return binary;
    endfunction

    sequence s_source_gray_stable;
        (source_valid && check_enable && $stable(source_gray))
            [*SETTLE_CYCLES];
    endsequence

    property p_timestamp_match(signal, expected);
        @(posedge dest_clk) disable iff (!dest_rst_n)
        s_source_gray_stable |-> (signal == expected);
    endproperty

    // Check RTL that consumes the decoded binary timestamp directly.
    TIMESTAMP_BINARY_CHECK: assert property (
        p_timestamp_match(rtl_binary_timestamp,
                          gray_to_binary(source_gray))
    ) else begin
        $error("timestamp binary mismatch: rtl=%0h expected=%0h gray=%0h",
               rtl_binary_timestamp,
               gray_to_binary(source_gray),
               source_gray);
    end

    // Check RTL that consumes the 1-GHz-equivalent value (31.25 MHz * 32).
    TIMESTAMP_SHIFTED_CHECK: assert property (
        p_timestamp_match(rtl_shifted_timestamp,
                          gray_to_binary(source_gray) << SHIFT)
    ) else begin
        $error("timestamp shifted mismatch: rtl=%0h expected=%0h gray=%0h",
               rtl_shifted_timestamp,
               gray_to_binary(source_gray) << SHIFT,
               source_gray);
    end

endinterface

`endif
