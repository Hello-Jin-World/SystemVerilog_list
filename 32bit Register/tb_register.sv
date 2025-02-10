`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/19 09:41:44
// Design Name: 
// Module Name: tb_register
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

interface reg_interface;
    logic        clk;
    logic        reset;
    logic [31:0] d;
    logic [31:0] q;
endinterface  //reg_interface

class transaction;
    rand logic [31:0] data;
    logic      [31:0] out;

    task display(string name);  // check section
        $display("[%s] data: %x, out: %x", name, data, out);
    endtask  //automatic 
endclass  //transaction

class generator;
    transaction trans;

    mailbox #(transaction) gen2drv_mbox;  // create headler gen2drv_mbox
    event gen_next_event;  // event : default feature in system verilog

    function new(mailbox#(transaction) gen2drv_mbox_v,
                 event gen_next_event);  // create instance
        this.gen2drv_mbox = gen2drv_mbox_v;  // reference
        this.gen_next_event = gen_next_event;
        trans = new();
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            assert (trans.randomize())
            else $display("[GEN] trans.radomize() error \n");  //error_process
            gen2drv_mbox.put(trans);  // put : default feature in system verilog
            trans.display("GEN");
            @(gen_next_event);
        end
    endtask  //run int countor
endclass

class driver;
    transaction trans;
    virtual reg_interface reg_intf;

    mailbox #(transaction) gen2drv_mbox;  // create headler gen2drv_mbox

    function new(mailbox#(transaction) gen2drv_mbox_v,
                 virtual reg_interface reg_interf);
        this.gen2drv_mbox = gen2drv_mbox_v;  // reference
        this.reg_intf = reg_interf;
    endfunction  //new()

    task reset();
        reg_intf.d     <= 0;
        reg_intf.reset <= 1'b1;
        repeat (5) @(posedge reg_intf.clk);
        reg_intf.reset <= 1'b0;
        @(posedge reg_intf.clk);  // when appear clk edge, output data
    endtask  //reset

    task run();
        forever begin
            gen2drv_mbox.get(trans);  // get transaction address, put in trans
            // get -> blocking
            reg_intf.d = trans.data;
            trans.display("DRV");
            //@(posedge reg_intf.clk);  // when appear clk edge, output data
            // #1 trans.out = reg_intf.q;
            // trans.display("DRV_OUT");
            // if (trans.data == trans.out) $display("pass!!!");
            // else $display("fail...");
        end
    endtask  //run 
endclass  //driver

class monitor;
    virtual reg_interface reg_intf;
    mailbox #(transaction) mon2scb_mbox;
    transaction trans;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual reg_interface reg_intf);
        this.reg_intf = reg_intf;
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction  //new()

    task run();
        forever begin
            trans = new();
            #2 trans.data = reg_intf.d;
            @(posedge reg_intf.clk);
            #1 trans.out = reg_intf.q;
            mon2scb_mbox.put(trans);
            trans.display("MON");
        end

    endtask  //run
endclass  //monitor

class scoreboard;
    mailbox #(transaction) mon2scb_mbox;
    transaction trans;
    event gen_next_event;
    int total_cnt, pass_cnt, fail_cnt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
        total_cnt           = 0;
        pass_cnt            = 0;
        fail_cnt            = 0;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(trans);
            trans.display("SCB");
            if (trans.data == trans.out) begin
                $display("--> pass!!!! %x == %x", trans.data, trans.out);
                pass_cnt++;
            end else begin
                $display("--> fail.... %x == %x", trans.data, trans.out);
                fail_cnt++;
            end
            total_cnt++;
            ->gen_next_event;
        end
    endtask  //run  //scoreboard
endclass

class envirnment;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    event gen_next_event;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    function new(virtual reg_interface reg_intf);
        gen2drv_mbox = new();  // create mailbox instance
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, reg_intf);
        mon = new(mon2scb_mbox, reg_intf);
        scb = new(mon2scb_mbox, gen_next_event);
    endfunction  //new()

    task report();
        $display("====================================");
        $display("========    Final Report    ========");
        $display("====================================");
        $display("=======    Total Test : %d   =======", scb.total_cnt);
        $display("=======     Pass Test : %d   =======", scb.pass_cnt);
        $display("=======     Fail Test : %d   =======", scb.fail_cnt);
        $display("====================================");
        $display("====   Test Bench is finished   ====");
        $display("====================================");
    endtask

    task pre_run();
        drv.reset();
    endtask  //pre_run

    task run();
        fork
            gen.run(100);
            drv.run();
            mon.run();
            scb.run();
        join_any
        report();
        #10 $finish;
    endtask

    task run_test();
        pre_run();
        run();
    endtask  //run_test
endclass  //envirnment

module tb_register ();
    reg_interface reg_intf(); // When this moment, reg_interface be instantiation
    envirnment env;

    register dut (  // connect interface cable with dut
        .clk  (reg_intf.clk),
        .reset(reg_intf.reset),
        .d    (reg_intf.d),
        .q    (reg_intf.q)
    );

    always #5 reg_intf.clk = ~reg_intf.clk;  // clk (interface member) toggle

    initial begin
        reg_intf.clk = 0;
    end

    initial begin
        env = new(reg_intf);
        env.run_test();
    end

endmodule
