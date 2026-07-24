// gic_tb_pkg: shared constants for the GIC interrupt-injection testbench.
package gic_tb_pkg;
  parameter int          N_SPI          = 32;
  parameter logic [31:0] TB_READY_ADDR  = 32'h1000_0000;  // PE writes 1 here before WFI
  parameter logic [31:0] TB_RESULT_ADDR = 32'h1000_0004;  // PE writes 0(pass)/1(fail) here
  parameter int          TIMEOUT_CYC    = 100000;         // watchdog cycles
endpackage
