// GIC interrupt driver. Waits pe_ready (frontdoor poll, with timeout),
// then drives spi_int_in or ppi_int.
//
// Level-triggered handshake:
//   1. Assert level high
//   2. Poll TB_INT_ASSERT_ADDR until PE sets flag (interrupt acknowledged)
//   3. De-assert level low (safe: PE has acked, no re-pending)
//   4. Clear flag (signals PE to proceed with EOI)
//
// Edge-triggered:
//   1. Pulse signal high for 1 cycle
//   2. De-assert immediately (edge latched by GIC)
//   3. Poll flag (optional: confirms PE received it)
//   4. Clear flag
class gic_int_driver extends uvm_driver #(gic_int_item);
    `uvm_component_utils(gic_int_driver)

    virtual gic_int_if vif;
    int ready_timeout = 10000;
    int ack_timeout = 10000;

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
        bit [31:0] flag;
        if (req.direction == gic_int_item::DIR_OUTPUT) return;
        wait_pe_ready();

        // Assert interrupt signal
        if (req.int_type == gic_int_item::SPI)
            vif.spi_int_in[req.intid] = 1'b1;
        else
            vif.ppi_int[req.pe_id][req.intid] = 1'b1;

        if (req.trig == gic_int_item::TRIG_EDGE) begin
            // Edge: pulse 1 cycle, then de-assert immediately
            @(posedge vif.clk);
            if (req.int_type == gic_int_item::SPI)
                vif.spi_int_in[req.intid] = 1'b0;
            else
                vif.ppi_int[req.pe_id][req.intid] = 1'b0;
        end

        // Wait for PE to acknowledge (flag set by tb_notify_int_taken)
        wait_int_ack();

        if (req.trig == gic_int_item::TRIG_LEVEL) begin
            // Level: de-assert now that PE has acked
            if (req.int_type == gic_int_item::SPI)
                vif.spi_int_in[req.intid] = 1'b0;
            else
                vif.ppi_int[req.pe_id][req.intid] = 1'b0;
        end

        // Clear flag: signals PE to proceed with EOI
        frontdoor_write32(`TB_INT_ASSERT_ADDR, 32'h0);
    endtask

    task wait_pe_ready();
        bit [31:0] val;
        int cyc = 0;
        forever begin
            @(posedge vif.clk);
            frontdoor_read32(`TB_READY_ADDR, val);
            if (val != 0) break;
            cyc++;
            if (cyc > ready_timeout) begin
                `uvm_fatal("TIMEOUT",
                    $sformatf("wait_pe_ready: PE not ready within %0d cycles", ready_timeout))
                return;
            end
        end
    endtask

    task wait_int_ack();
        bit [31:0] flag;
        int cyc = 0;
        forever begin
            @(posedge vif.clk);
            frontdoor_read32(`TB_INT_ASSERT_ADDR, flag);
            if (flag != 0) break;
            cyc++;
            if (cyc > ack_timeout) begin
                `uvm_fatal("TIMEOUT",
                    $sformatf("wait_int_ack: PE did not ack within %0d cycles", ack_timeout))
                return;
            end
        end
    endtask

    //==============================================================
    // Frontdoor AXI read/write -- YOU FILL THESE IN
    //==============================================================
    virtual task frontdoor_read32(
        input  bit [31:0] addr,
        output bit [31:0] data
    );
        `uvm_fatal("UNIMPL",
            $sformatf("frontdoor_read32: connect to AXI VIP, addr=0x%08x", addr))
        data = 32'h0;
    endtask

    virtual task frontdoor_write32(
        input  bit [31:0] addr,
        input  bit [31:0] data
    );
        `uvm_fatal("UNIMPL",
            $sformatf("frontdoor_write32: connect to AXI VIP, addr=0x%08x", addr))
    endtask
endclass
