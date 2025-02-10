`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/20 16:39:07
// Design Name: 
// Module Name: tb_dual_port_ram
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

interface dp_ram_interface;
    logic       clk;
    logic [3:0] waddr;
    logic [3:0] raddr;
    logic [7:0] wdata;
    logic       write;
    logic [7:0] rdata;
endinterface  //dp_ram_interface

class transaction;
    rand logic [3:0] waddr;
    rand logic [3:0] raddr;
    rand logic [7:0] wdata;
    rand logic       write;
    logic      [7:0] rdata;

    constraint wdata_aaaa {waddr inside {[0 : 10]};}
    constraint wdata_bbbb {raddr inside {[0 : 10]};}
endclass  //transaction

class generator;
    transaction trans;
    event gen_next_event;

    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            trans = new();
            assert (trans.randomize())
            else $error("randomize error!!!!");
            gen2drv_mbox.put(trans);
            @(gen_next_event);
        end
    endtask  //run
endclass  //generator

class driver;
    transaction trans;
    event mon_next_event;
    virtual dp_ram_interface dp_ram_intf;

    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_event,
                 virtual dp_ram_interface dp_ram_intf);
        this.gen2drv_mbox = gen2drv_mbox;
        this.mon_next_event = mon_next_event;
        this.dp_ram_intf = dp_ram_intf;
    endfunction  //new()

    task reset();
        dp_ram_intf.clk   = 0;
        dp_ram_intf.write = 0;
        dp_ram_intf.waddr = 0;
        dp_ram_intf.raddr = 0;
        dp_ram_intf.wdata = 0;
        repeat (5) @(posedge dp_ram_intf.clk);

        for (
            int i = 0; i < 1024; i++
        ) begin  // memory reset all address contain 0
            dp_ram_intf.write = 1'b1;
            dp_ram_intf.wdata = 0;
            dp_ram_intf.waddr  = i;
            @(posedge dp_ram_intf.clk);
        end
    endtask  //reset

    task run();
        forever begin
            gen2drv_mbox.get(trans);
            dp_ram_intf.waddr = trans.waddr;
            dp_ram_intf.raddr = trans.raddr;
            dp_ram_intf.wdata = trans.wdata;
            dp_ram_intf.write = trans.write;
            #2;
            ->mon_next_event;
            @(posedge dp_ram_intf.clk);
        end
    endtask  //run
endclass  //driver

class monitor;
    transaction trans;
    virtual dp_ram_interface dp_ram_intf;
    event mon_next_event;

    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox, event mon_next_event,
                 virtual dp_ram_interface dp_ram_intf);
        this.mon2scb_mbox = mon2scb_mbox;
        this.mon_next_event = mon_next_event;
        this.dp_ram_intf = dp_ram_intf;
    endfunction  //new()

    task run();
        forever begin
            @(mon_next_event);
            trans = new();
            trans.waddr = dp_ram_intf.waddr;
            trans.raddr = dp_ram_intf.raddr;
            trans.wdata = dp_ram_intf.wdata;
            trans.write = dp_ram_intf.write;
            trans.rdata = dp_ram_intf.rdata;
            mon2scb_mbox.put(trans);
            @(posedge dp_ram_intf.clk);
        end
    endtask  //run
endclass  //monitor

class scoreboard;
    transaction trans;
    event gen_next_event;

    mailbox #(transaction) mon2scb_mbox;

    int total_cnt;
    int write_cnt;
    int pass_cnt;
    int fail_cnt;

    byte mem[0:15];
    byte rdata;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
        total_cnt = 0;
        write_cnt = 0;
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(trans);
            if (trans.write) begin
                mem[trans.waddr] = trans.wdata;
                write_cnt++;
            end
            rdata = mem[trans.raddr];
            if (rdata == trans.rdata) begin
                $display("rdata : %x == trans.rdata : %x PASS!!!!!!!!", rdata,
                         trans.rdata);
                pass_cnt++;
            end else begin
                $display("rdata : %x != trans.rdata : %x FAIL........", rdata,
                         trans.rdata);
                fail_cnt++;
            end
            total_cnt++;
            $display("trans.waddr: %x, trans.wdata: %x, trans.raddr: %x",
                     trans.waddr, trans.wdata, trans.raddr);
            ->gen_next_event;
        end
    endtask  //run

endclass  //scoreboard

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    event gen_next_event;
    event mon_next_event;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    function new(virtual dp_ram_interface dp_ram_intf);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, mon_next_event, dp_ram_intf);
        mon = new(mon2scb_mbox, mon_next_event, dp_ram_intf);
        scb = new(mon2scb_mbox, gen_next_event);
    endfunction  //new()

    task pre_run();
        drv.reset();
    endtask  //pre_run

    task run();
        fork
            gen.run(10000);
            drv.run();
            mon.run();
            scb.run();
        join_any
        report();
        #10 $finish;
    endtask  //run

    task report();
        $display("====================================");
        $display("========    Final Report    ========");
        $display("====================================");
        $display("Total Test : %d", scb.total_cnt);
        $display("Write Test : %d", scb.write_cnt);
        $display("========     Read Result    ========");
        $display(" Pass Test : %d ", scb.pass_cnt);
        $display(" Fail Test : %d ", scb.fail_cnt);
        $display("====================================");
        $display("====   Test Bench is finished   ====");
        $display("====================================");
    endtask

    task run_test();
        pre_run();
        run();
    endtask  //run_test
endclass  //environment

module tb_dual_port_ram ();
    environment env;

    dp_ram_interface dp_ram_intf ();

    dual_port_ram dut (
        .clk  (dp_ram_intf.clk),
        .waddr(dp_ram_intf.waddr),
        .raddr(dp_ram_intf.raddr),
        .wdata(dp_ram_intf.wdata),
        .write(dp_ram_intf.write),
        .rdata(dp_ram_intf.rdata)
    );

    always #5 dp_ram_intf.clk = ~dp_ram_intf.clk;

    initial begin
        env = new(dp_ram_intf);
        env.run_test();
    end

endmodule
