// GIC interrupt driver. Waits pe_ready (backdoor poll, with timeout),
// then drives spi_int_in or ppi_int.
class gic_int_driver extends uvm_driver #(gic_int_item);
    `uvm_component_utils(gic_int_driver)

    virtual gic_int_if vif;
    int ready_timeout = 10000;  // cycles before giving up

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual gic_int_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "gic_int_driver: vif not set")
    endfunction

    task run_phase(uvm_phase phase);
        gic_int_item req;
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_item(gic_int_item req);
        if (req.direction == gic_int_item::DIR_OUTPUT) return;
        wait_pe_ready();
        if (req.int_type == gic_int_item::SPI)
            vif.spi_int_in[req.intid] = 1'b1;
        else
            vif.ppi_int[req.pe_id][req.intid] = 1'b1;
        repeat (req.hold_cycles) @(posedge vif.clk);
        if (req.int_type == gic_int_item::SPI)
            vif.spi_int_in[req.intid] = 1'b0;
        else
            vif.ppi_int[req.pe_id][req.intid] = 1'b0;
    endtask

    task wait_pe_ready();
        // Backdoor poll TB_READY_ADDR until non-zero, with timeout.
        int cyc = 0;
        forever begin
            @(posedge vif.clk);
            // TODO: replace stub with RAL backdoor peek of 0x1000_0000
            if (backdoor_ready()) break;
            cyc++;
            if (cyc > ready_timeout) begin
                `uvm_fatal("TIMEOUT",
                    `sformatf("wait_pe_ready: PE not ready within %0d cycles", ready_timeout))
                return;
            end
        end
    endtask

    function bit backdoor_ready();
        // TODO: RAL backdoor read TB_READY_ADDR (slave VIP memory peek).
        return 1'b1;  // stub
    endfunction
endclass
