`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/21 13:14:13
// Design Name: 
// Module Name: tb_fifo
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

interface fifo_interface;
    logic       clk;
    logic       reset;
    logic [7:0] wdata;
    logic       wr_en;
    logic       rd_en;
    logic [7:0] rdata;
    logic       full;
    logic       empty;
endinterface  //fifo_interface

class transaction;
    rand logic       operation;
    rand logic [7:0] wdata;
    logic            wr_en;
    logic            rd_en;
    logic      [7:0] rdata;
    logic            full;
    logic            empty;

    task display(string name);
        $display(
            "[%s] op: %x, wdata: %d, wr_en: %d, full: %d, rdata: %d, rd_en: %d, empty: %d",
            name, operation, wdata, wr_en, full, rdata, rd_en, empty);
    endtask  //display

    constraint oper_cntl {
        operation dist {
            0 :/ 70,
            1 :/ 30
        };
    }
endclass  //transaction


class generator;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_event;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            trans = new();
            assert (trans.randomize())
            else $error("randomize error!!!!!");
            gen2drv_mbox.put(trans);
            trans.display("GEN");
            @(gen_next_event);
        end
    endtask  //run
endclass  //className

class driver;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    event mon_next_event;

    virtual fifo_interface fifo_intf;

    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_event,
                 virtual fifo_interface fifo_intf);
        this.gen2drv_mbox = gen2drv_mbox;
        this.mon_next_event = mon_next_event;
        this.fifo_intf = fifo_intf;
    endfunction  //new()

    task reset();
        fifo_intf.clk   <= 1'b0;
        fifo_intf.reset <= 1'b1;
        fifo_intf.rd_en <= 1'b0;
        fifo_intf.wr_en <= 1'b0;
        fifo_intf.wdata <= 0;
        repeat (5) @(posedge fifo_intf.clk);
        fifo_intf.reset <= 1'b0;
        repeat (5) @(posedge fifo_intf.clk);
        $display("[DRV] DUT Reset Done!");
        $display("---------------------");
    endtask  //reset

    task push();
        fifo_intf.wr_en <= 1'b1;
        fifo_intf.rd_en <= 1'b0;
        fifo_intf.wdata <= trans.wdata;
        #2;
        ->mon_next_event;
        trans.display("DRV");
        @(posedge fifo_intf.clk);
        fifo_intf.wr_en <= 1'b0;
    endtask  //write

    task pop();
        fifo_intf.wr_en <= 1'b0;
        fifo_intf.rd_en <= 1'b1;
        #2;
        ->mon_next_event;
        trans.display("DRV");
        @(posedge fifo_intf.clk);
        fifo_intf.rd_en <= 1'b0;
    endtask  //read

    task run();
        forever begin
            gen2drv_mbox.get(trans);
            if (trans.operation == 1'b1) begin  // push data
                push();
            end else begin  // pop data
                pop();
            end
        end
    endtask  //run
endclass  //className

class monitor;
    transaction trans;
    mailbox #(transaction) mon2scb_mbox;
    event mon_next_event;

    virtual fifo_interface fifo_intf;

    function new(mailbox#(transaction) mon2scb_mbox, event mon_next_event,
                 virtual fifo_interface fifo_intf);
        this.mon2scb_mbox = mon2scb_mbox;
        this.mon_next_event = mon_next_event;
        this.fifo_intf = fifo_intf;
    endfunction  //new()

    task run();
        forever begin
            trans = new();
            @(mon_next_event);
            trans.wr_en = fifo_intf.wr_en;
            trans.rd_en = fifo_intf.rd_en;
            trans.wdata = fifo_intf.wdata;
            trans.rdata = fifo_intf.rdata;
            trans.full  = fifo_intf.full;
            trans.empty = fifo_intf.empty;
            @(posedge fifo_intf.clk);
            mon2scb_mbox.put(trans);
            trans.display("MON");
        end
    endtask  //run
endclass  //className

class scoreboard;
    transaction trans;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_event;

    logic [7:0] fifo_queue[$:15];

    reg [7:0] temp_data;

    int total_cnt, push_cnt, pass_cnt, fail_cnt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(trans);
            trans.display("SCB");
            if (trans.wr_en) begin
                if (trans.full == 1'b0) begin
                    fifo_queue.push_front(trans.wdata);
                    $display("[SCB] data stored in queue : %d", trans.wdata);
                    push_cnt++;
                end else begin
                    $display("[SCB] queue is full");
                end
            end
            if (trans.rd_en) begin
                if (trans.empty == 1'b0) begin
                    temp_data = fifo_queue.pop_back();
                    $display("[SCB] data read in queue : %d", trans.rdata);
                    if (trans.rdata == temp_data) begin
                        $display("PASS!!!!");
                        pass_cnt++;
                    end else begin
                        $display("FAIL....");
                        fail_cnt++;
                    end
                end else begin
                    $display("[SCB] queue is empty");
                end
            end
            total_cnt++;
            $display("%p", fifo_queue);
            $display("--------------------");
            ->gen_next_event;
        end
    endtask  //run
endclass  //className

class environment;

    transaction trans;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event gen_next_event;
    event mon_next_event;

    function new(virtual fifo_interface fifo_intf);
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, mon_next_event, fifo_intf);
        mon = new(mon2scb_mbox, mon_next_event, fifo_intf);
        scb = new(mon2scb_mbox, gen_next_event);
    endfunction  //new()


    task report();
        $display("====================================");
        $display("========    Final Report    ========");
        $display("====================================");
        $display("Total Test : %d", scb.total_cnt);
        $display(" Push Test : %d", scb.push_cnt);
        $display("========     Read Result    ========");
        $display(" Pass Test : %d ", scb.pass_cnt);
        $display(" Fail Test : %d ", scb.fail_cnt);
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
    endtask  //run

    task run_test();
        pre_run();
        run();
    endtask  //run_test
endclass  //environment

module tb_fifo ();

    environment env;
    fifo_interface fifo_intf ();

    fifo dut (
        .clk  (fifo_intf.clk),
        .reset(fifo_intf.reset),
        .wdata(fifo_intf.wdata),
        .wr_en(fifo_intf.wr_en),
        .rd_en(fifo_intf.rd_en),
        .rdata(fifo_intf.rdata),
        .full (fifo_intf.full),
        .empty(fifo_intf.empty)
    );

    always #5 fifo_intf.clk = ~fifo_intf.clk;

    initial begin
        env = new(fifo_intf);
        env.run_test();
    end

endmodule
