`ifndef CPU_ECT_CLUSTERS_CHOUT_CH3_TEST_SV
`define CPU_ECT_CLUSTERS_CHOUT_CH3_TEST_SV

//----------------------------------------------------------------------
// cp2cp pulse -> all cluster CTICHIN, channel 3 only.
//----------------------------------------------------------------------
class cpu_ect_clusters_chout_ch3_test extends
    cpu_ect_clusters_chout_base_test;
    `uvm_component_utils(cpu_ect_clusters_chout_ch3_test)

    localparam int unsigned CHANNEL = 3;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function int unsigned channel_id();
        return CHANNEL;
    endfunction
endclass

`endif
