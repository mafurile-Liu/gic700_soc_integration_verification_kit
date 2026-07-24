// gic_scoreboard: on test_done, print PASS/FAIL and finish. Watchdog on timeout.
module gic_scoreboard #(parameter int TIMEOUT = 100000) (
    input logic clk, rstn, input logic test_done, input logic [31:0] test_result
    );
    int cyc;
    always @(posedge clk) if (!rstn) cyc <= 0; else cyc <= cyc + 1;
    always @(posedge clk) begin
        if (rstn && test_done) begin
            if (test_result == 0) $display("[GIC_TB] PASS");
            else                  $display("[GIC_TB] FAIL (result=%0d)", test_result);
            $finish;
        end
        if (cyc > TIMEOUT) begin
            $display("[GIC_TB] FAIL (timeout)");
            $finish;
        end
    end
endmodule
