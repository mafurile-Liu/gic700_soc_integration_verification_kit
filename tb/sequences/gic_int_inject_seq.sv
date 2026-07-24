// Inject one interrupt (SPI or PPI).
class gic_int_inject_seq extends uvm_sequence #(gic_int_item);
    `uvm_object_utils(gic_int_inject_seq)
    rand gic_int_item::int_type_e int_type = gic_int_item::SPI;
    rand int intid = 32;
    rand int pe_id = 0;
    rand gic_int_item::trig_e trig = gic_int_item::TRIG_LEVEL;
    rand int hold = 100;

    function new(string name = "gic_int_inject_seq");
        super.new(name);
    endfunction

    task body();
        gic_int_item req;
        req = gic_int_item::type_id::create("req");
        start_item(req);
        req.int_type = int_type;
        req.intid = intid;
        req.pe_id = pe_id;
        req.trig = trig;
        req.hold_cycles = hold;
        if (!req.randomize()) `uvm_error("RAND", "randomize failed")
        finish_item(req);
    endtask
endclass
