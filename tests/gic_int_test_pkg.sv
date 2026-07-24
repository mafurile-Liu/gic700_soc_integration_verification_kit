// GIC interrupt test package. Includes all test cases.
package gic_int_test_pkg;
    import uvm_pkg::*;
    import gic_int_agent_pkg::*;
    import gic_int_seq_pkg::*;

    `include "gic_int_base_test.svh"
    `include "gic_spi_basic_test.svh"
    `include "gic_spi_scan_test.svh"
    `include "gic_ppi_basic_test.svh"
    `include "gic_sgi_basic_test.svh"
    `include "gic_lpi_basic_test.svh"
endpackage
