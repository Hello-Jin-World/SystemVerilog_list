`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/26 18:35:11
// Design Name: 
// Module Name: DHT11_SV
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

interface dht11_interface;
    logic        clk;
    logic        reset;
    wire         ioport;
    logic        mode;
    logic [ 7:0] hum_int;
    logic [ 7:0] hum_dec;
    logic [ 7:0] tem_int;
    logic [ 7:0] tem_dec;
    logic [ 7:0] checksum;
    logic        out_data;
    // logic [6:0] rand_hum_tem[0:39];
    logic [39:0] sw_40bit;

    assign ioport = mode ? out_data : 1'bz;
endinterface  //dht11_interface

class transaction;
    logic      [ 7:0] hum_int;
    logic      [ 7:0] hum_dec;
    logic      [ 7:0] tem_int;
    logic      [ 7:0] tem_dec;
    logic      [ 7:0] checksum;
    logic             out_data;
    logic             mode;
    rand logic [ 6:0] set_up_time;
    logic      [39:0] sw_40bit;

    constraint range {
    set_up_time dist {
    26 :/ 80,
    70 :/ 20
    };
    }

    //constraint value_c {set_up_time inside {26, 70};}

    task display(string name);
        $display("[%s] humidity : %d.%d,  temperature : %d.%d", name, hum_int,
                 hum_dec, tem_int, tem_dec);
    endtask  //display
endclass  //transaction

class generator;
    transaction            trans;
    mailbox #(transaction) gen2drv_mbox;
    event                  gen_next_event;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            trans = new();
            assert (trans.randomize())
            else $error("randomize errer!!!!!!");
            gen2drv_mbox.put(trans);
            trans.display("GEN");
            @(gen_next_event);
        end
    endtask  //run
endclass  //generator

class driver;
    transaction             trans;

    mailbox #(transaction)  gen2drv_mbox;
    event                   mon_next_event;
    virtual dht11_interface dht11_intf;

    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_event,
                 virtual dht11_interface dht11_intf);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.mon_next_event = mon_next_event;
        this.dht11_intf     = dht11_intf;
    endfunction  //new()

    task reset();
        dht11_intf.reset    <= 1'b1;
        dht11_intf.clk      <= 1'b0;
        dht11_intf.mode     <= 1'b1;
        dht11_intf.hum_int  <= 0;
        dht11_intf.hum_dec  <= 0;
        dht11_intf.tem_int  <= 0;
        dht11_intf.tem_dec  <= 0;
        dht11_intf.checksum <= 0;
        dht11_intf.out_data <= 0;
        dht11_intf.sw_40bit <= 0;
        // dht11_intf.tem <= 0;
        repeat (5) @(posedge dht11_intf.clk);
        dht11_intf.reset <= 1'b0;
        repeat (5) @(posedge dht11_intf.clk);
        $display("[DRV] DUT Reset Done!");
        $display("---------------------");
    endtask

    task tick(int count);  // count * 1us tick
        repeat (count) begin
            repeat (100) @(posedge dht11_intf.clk);
        end
    endtask  //tick

    task start_dht11();
        dht11_intf.mode = 1'b0;
        wait (dht11_intf.ioport == 0);  // 18ms    LOW
        $display("READ 18ms LOW");
        wait (dht11_intf.ioport == 1);  // 20~40us HIGH
        $display("READ 20~40us HIGH");
        tick(25);
        dht11_intf.mode = 1'b1;

        dht11_intf.out_data = 1'b0;
        tick(60);
        dht11_intf.out_data = 1'b1;
        tick(75);

        //////////////////////////////////////////////////////////// humidity int
        dht11_intf.out_data = 1'b0;
        tick(50);
        dht11_intf.out_data = 1'b1;
        tick(26);
        trans.sw_40bit = {trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]};

        for (int i = 0; i < 7; i++) begin
            trans.randomize();
            dht11_intf.out_data = 1'b0;
            tick(50);
            dht11_intf.out_data = 1'b1;
            tick(trans.set_up_time);
            // #2;
            if (trans.set_up_time > 40) begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b1, trans.sw_40bit[7:0]
                };
            end else begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]
                };
            end

            $display("%d", trans.set_up_time);
        end
        //////////////////////////////////////////////////////////// humidity dec
        dht11_intf.out_data = 1'b0;
        tick(50);
        dht11_intf.out_data = 1'b1;
        tick(26);
        trans.sw_40bit = {trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]};

        for (int i = 0; i < 7; i++) begin
            trans.randomize();
            dht11_intf.out_data = 1'b0;
            tick(50);
            dht11_intf.out_data = 1'b1;
            tick(trans.set_up_time);
            // #2;
            if (trans.set_up_time > 40) begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b1, trans.sw_40bit[7:0]
                };
            end else begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]
                };
            end

            $display("%d", trans.set_up_time);
        end
        //////////////////////////////////////////////////////////// temperature int
        dht11_intf.out_data = 1'b0;
        tick(50);
        dht11_intf.out_data = 1'b1;
        tick(26);
        trans.sw_40bit = {trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]};

        for (int i = 0; i < 7; i++) begin
            trans.randomize();
            dht11_intf.out_data = 1'b0;
            tick(50);
            dht11_intf.out_data = 1'b1;
            tick(trans.set_up_time);
            // #2;
            if (trans.set_up_time > 40) begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b1, trans.sw_40bit[7:0]
                };
            end else begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]
                };
            end

            $display("%d", trans.set_up_time);
        end
        //////////////////////////////////////////////////////////// temperature dec
        dht11_intf.out_data = 1'b0;
        tick(50);
        dht11_intf.out_data = 1'b1;
        tick(26);
        trans.sw_40bit = {trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]};

        for (int i = 0; i < 7; i++) begin
            trans.randomize();
            dht11_intf.out_data = 1'b0;
            tick(50);
            dht11_intf.out_data = 1'b1;
            tick(trans.set_up_time);
            // #2;
            if (trans.set_up_time > 40) begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b1, trans.sw_40bit[7:0]
                };
            end else begin
                trans.sw_40bit = {
                    trans.sw_40bit[38:8], 1'b0, trans.sw_40bit[7:0]
                };
            end

            $display("%d", trans.set_up_time);
        end
        /////////////////////////////////////////////////////////// check sum
        trans.sw_40bit[7:0] = trans.sw_40bit[39:32] + trans.sw_40bit[31:24] + trans.sw_40bit[23:16] + trans.sw_40bit[15:8];
        for (int i = 0; i < 8; i++) begin
            if (trans.sw_40bit[7-i] == 1) begin
                dht11_intf.out_data = 1'b0;
                tick(50);
                dht11_intf.out_data = 1'b1;
                tick(70);
            end else begin
                dht11_intf.out_data = 1'b0;
                tick(50);
                dht11_intf.out_data = 1'b1;
                tick(27);
            end
        end


        dht11_intf.out_data = 1'b0;
        tick(50);
        dht11_intf.out_data = 1'b1;
        tick(27);

        // for (int i = 41; i > 0; i--) begin
        //     trans.randomize();
        //     dht11_intf.out_data = 1'b0;
        //     tick(50);
        //     dht11_intf.out_data = 1'b1;
        //     tick(trans.set_up_time);
        //     #1;
        //     if (i > 1) begin
        //         if (trans.set_up_time > 40) begin
        //             trans.sw_40bit = {trans.sw_40bit[38:0], 1'b1};
        //         end else begin
        //             trans.sw_40bit = {trans.sw_40bit[38:0], 1'b0};
        //         end
        //     end
        //     #2;
        //     // dht11_intf.rand_hum_tem[i-2] = trans.set_up_time;
        //     $display("%d", trans.set_up_time);
        // end
        // tick(60);
    endtask  //start_dht11

    task run();
        forever begin
            gen2drv_mbox.get(trans);
            dht11_intf.hum_int  = trans.hum_int;
            dht11_intf.hum_dec  = trans.hum_dec;
            dht11_intf.tem_int  = trans.tem_int;
            dht11_intf.tem_dec  = trans.tem_dec;
            dht11_intf.checksum = trans.checksum;
            #1;
            // dht11_intf.rand_hum_tem = trans.rand_hum_tem;
            trans.display("DRV");
            // dht11_trigger();
            // send_start_signal_high();
            start_dht11();
            #1;
            dht11_intf.sw_40bit = trans.sw_40bit;
            #1;
            ->mon_next_event;
            @(posedge dht11_intf.clk);
        end
    endtask  //run
endclass  //driver

class monitor;
    transaction             trans;

    mailbox #(transaction)  mon2scb_mbox;
    event                   mon_next_event;
    virtual dht11_interface dht11_intf;
    event                   scb_next_event;


    function new(mailbox#(transaction) mon2scb_mbox, event mon_next_event,
                 virtual dht11_interface dht11_intf, event scb_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.mon_next_event = mon_next_event;
        this.dht11_intf     = dht11_intf;
        this.scb_next_event = scb_next_event;
    endfunction  //new()

    task run();
        forever begin
            trans = new();
            @(mon_next_event);
            repeat (5) @(posedge dht11_intf.clk);
            trans.hum_int  = dht11_intf.hum_int;
            trans.hum_dec  = dht11_intf.hum_dec;
            trans.tem_int  = dht11_intf.tem_int;
            trans.tem_dec  = dht11_intf.tem_dec;
            trans.checksum = dht11_intf.checksum;
            trans.sw_40bit = dht11_intf.sw_40bit;
            // trans.rand_hum_tem = dht11_intf.rand_hum_tem;
            @(posedge dht11_intf.clk);
            mon2scb_mbox.put(trans);
            trans.display("MON");
            #2;
            ->scb_next_event;
        end
    endtask  //run
endclass  //monitor

class scoreboard;
    transaction                  trans;

    mailbox #(transaction)       mon2scb_mbox;
    event                        gen_next_event;
    event                        scb_next_event;

    // reg                    [39:0] sw_result;
    reg                    [7:0] sw_hum_int;
    reg                    [7:0] sw_hum_dec;
    reg                    [7:0] sw_tem_int;
    reg                    [7:0] sw_tem_dec;
    reg                    [7:0] sw_checksum;

    int                          total_cnt,      pass_cnt, fail_cnt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event,
                 event scb_next_event);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
        this.scb_next_event = scb_next_event;
        // sw_result           = 0;
        sw_hum_int          = 0;
        sw_hum_dec          = 0;
        sw_tem_int          = 0;
        sw_tem_dec          = 0;
        sw_checksum         = 0;
        total_cnt           = 0;
        pass_cnt            = 0;
        fail_cnt            = 0;
    endfunction  //new()

    task run();
        forever begin
            @(scb_next_event);
            mon2scb_mbox.get(trans);
            $display("PASS1");
            sw_hum_int  = trans.sw_40bit[39:32];
            sw_hum_dec  = trans.sw_40bit[31:24];
            sw_tem_int  = trans.sw_40bit[23:16];
            sw_tem_dec  = trans.sw_40bit[15:8];
            sw_checksum = trans.sw_40bit[7:0];
            #5;
            if (sw_hum_int == trans.hum_int && sw_hum_dec == trans.hum_dec && sw_tem_int == trans.tem_int && sw_tem_dec == trans.tem_dec) begin
                $display("PASS!!!!");
                pass_cnt++;
            end else begin
                $display("FAIL....");
                fail_cnt++;
            end
            total_cnt++;
            $display("hardware : %d,    software : %d", trans.hum_int,
                     sw_hum_int);
            $display("hardware : %d,    software : %d", trans.hum_dec,
                     sw_hum_dec);
            $display("hardware : %d,    software : %d", trans.tem_int,
                     sw_tem_int);
            $display("hardware : %d,    software : %d", trans.tem_dec,
                     sw_tem_dec);
            $display("hardware : %d,    software : %d", trans.checksum,
                     sw_checksum);
            trans.display("SCB");
            ->gen_next_event;
        end
    endtask  //run

endclass  //scoreboard

class environment;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;
    transaction            trans;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_event;
    event                  mon_next_event;
    event                  scb_next_event;

    function new(virtual dht11_interface dht11_intf);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, mon_next_event, dht11_intf);
        mon = new(mon2scb_mbox, mon_next_event, dht11_intf, scb_next_event);
        scb = new(mon2scb_mbox, gen_next_event, scb_next_event);
    endfunction  //new()

    task report();
        $display("====================================");
        $display("========    Final Report    ========");
        $display("====================================");
        $display("Total Test : %d", scb.total_cnt);
        $display("========     Read Result    ========");
        $display(" Pass Test : %d ", scb.pass_cnt);
        $display(" Fail Test : %d ", scb.fail_cnt);
        $display("====================================");
        $display("====   Test Bench is finished   ====");
        $display("====================================");
    endtask

    task pre_run();
        drv.reset();
    endtask  //run

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

    task run_test();
        pre_run();
        run();
    endtask  //run_test
endclass  //environment

module DHT11_SV ();

    dht11_interface dht11_intf ();

    environment env;

    DHT11_control dut (
        .clk     (dht11_intf.clk),
        .reset   (dht11_intf.reset),
        .ioport  (dht11_intf.ioport),
        .hum_int (dht11_intf.hum_int),
        .hum_dec (dht11_intf.hum_dec),
        .tem_int (dht11_intf.tem_int),
        .tem_dec (dht11_intf.tem_dec),
        .checksum(dht11_intf.checksum)
    );

    always #5 dht11_intf.clk = ~dht11_intf.clk;

    initial begin
        env = new(dht11_intf);
        env.run_test();
    end

endmodule
