`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/26 16:33:42
// Design Name: 
// Module Name: DHT11_control
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


module DHT11_control (
    input        clk,
    input        reset,
    inout        ioport,
    output       wr_en,
    output [7:0] hum_int,
    output [7:0] hum_dec,
    output [7:0] tem_int,
    output [7:0] tem_dec,
    output [7:0] checksum
);

    wire io_mode;
    wire signal;
    reg  receive_dht11_data;
    wire tick;
    wire start_dht11;


    clock_divider U_clock_divider (
        .clk      (clk),
        .reset    (reset),
        .tick_1Mhz(tick)
    );

    count_5sec U_count_5sec (
        .clk        (clk),
        .reset      (reset),
        .tick       (tick),
        .start_dht11(start_dht11)
    );


    start_signal U_start_signal (
        .clk        (clk),
        .reset      (reset),
        .tick       (tick),
        .start_dht11(start_dht11),
        .dht11_data (receive_dht11_data),
        .wr_en      (wr_en),
        .signal     (signal),
        .mode       (io_mode),
        .hum_int    (hum_int),
        .hum_dec    (hum_dec),
        .tem_int    (tem_int),
        .tem_dec    (tem_dec),
        .checksum   (checksum)
    );

    assign ioport = io_mode ? signal : 1'bz;  // If you want to send(out) "HIGH"

    always @(*) begin  // Read Data (INPUT MODE)
        if (!io_mode) begin
            receive_dht11_data <= ioport;
        end
    end
endmodule

module count_5sec (
    input  clk,
    input  reset,
    input  tick,
    output start_dht11
);

    reg [$clog2(5_000_000) - 1:0] counter_reg, counter_next;
    // reg [$clog2(30_000) - 1:0] counter_reg, counter_next;
    reg start_dht11_reg, start_dht11_next;

    assign start_dht11 = start_dht11_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg     <= 0;
            start_dht11_reg <= 0;
        end else begin
            counter_reg     <= counter_next;
            start_dht11_reg <= start_dht11_next;
        end
    end

    always @(*) begin
        counter_next     = counter_reg;
        start_dht11_next = start_dht11_next;
        if (tick) begin
            if (counter_reg == 5_000_000 - 1) begin
                // if (counter_reg == 30_000 - 1) begin
                counter_next     = 0;
                start_dht11_next = 1;
            end else begin
                start_dht11_next = 0;
                counter_next     = counter_reg + 1;
            end
        end
    end

endmodule

module clock_divider (
    input  clk,
    input  reset,
    output tick_1Mhz
);

    reg [$clog2(100)-1 : 0] r_counter;
    reg r_tick;

    assign tick_1Mhz = r_tick;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            r_tick    <= 1'b0;
        end else begin
            if (r_counter == 100 - 1) begin
                r_counter <= 0;
                r_tick    <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_tick    <= 1'b0;
            end
        end
    end
endmodule

module start_signal (
    input        clk,
    input        reset,
    input        tick,
    input        start_dht11,
    input        wr_en,
    input        dht11_data,
    output       signal,
    output       mode,
    output [7:0] hum_int,
    output [7:0] hum_dec,
    output [7:0] tem_int,
    output [7:0] tem_dec,
    output [7:0] checksum
);


    reg signal_reg, signal_next;
    reg [$clog2(18_000) - 1:0] counter_reg, counter_next;
    reg mode_reg, mode_next;
    reg start_receive_data_reg, start_receive_data_next;
    reg [2:0] state_reg, state_next;
    reg [39:0] tem_hum_data_reg, tem_hum_data_next;
    reg [$clog2(40) - 1 : 0] i_reg, i_next;
    reg wr_en_reg, wr_en_next;

    reg [7:0] hum_int_reg, hum_int_next;
    reg [7:0] hum_dec_reg, hum_dec_next;
    reg [7:0] tem_int_reg, tem_int_next;
    reg [7:0] tem_dec_reg, tem_dec_next;
    reg [7:0] checksum_reg, checksum_next;

    assign hum_int  = hum_int_reg;
    assign hum_dec  = hum_dec_reg;
    assign tem_int  = tem_int_reg;
    assign tem_dec  = tem_dec_reg;
    assign checksum = checksum_reg;

    localparam IDLE = 4'b0000, START_L = 4'b0001, START_H = 4'b0010, WAIT_H = 4'b0011, WAIT_L = 4'b0100, READ_LOW = 4'b0101, READ_HIGH = 4'b0110, DATA_DIST = 4'b0111;

    assign signal = signal_reg;
    assign mode   = mode_reg;
    assign wr_en  = wr_en_reg;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            signal_reg       <= 1'b1;
            counter_reg      <= 0;
            mode_reg         <= 1'b1;
            state_reg        <= 0;
            tem_hum_data_reg <= 0;
            i_reg            <= 0;
            hum_int_reg      <= 0;
            hum_dec_reg      <= 0;
            tem_int_reg      <= 0;
            tem_dec_reg      <= 0;
            checksum_reg     <= 0;
            wr_en_reg        <= 0;
        end else begin
            signal_reg       <= signal_next;
            counter_reg      <= counter_next;
            mode_reg         <= mode_next;
            state_reg        <= state_next;
            tem_hum_data_reg <= tem_hum_data_next;
            i_reg            <= i_next;
            hum_int_reg      <= hum_int_next;
            hum_dec_reg      <= hum_dec_next;
            tem_int_reg      <= tem_int_next;
            tem_dec_reg      <= tem_dec_next;
            checksum_reg     <= checksum_next;
            wr_en_reg        <= wr_en_next;
        end
    end

    always @(*) begin
        state_next        = state_reg;
        tem_hum_data_next = tem_hum_data_reg;
        counter_next      = counter_reg;
        i_next            = i_reg;
        signal_next       = signal_reg;
        mode_next         = mode_reg;
        hum_int_next      = hum_int_reg;
        hum_dec_next      = hum_dec_reg;
        tem_int_next      = tem_int_reg;
        tem_dec_next      = tem_dec_reg;
        checksum_next     = checksum_reg;
        wr_en_next        = wr_en_reg;
        case (state_reg)
            IDLE: begin
                if (start_dht11) begin
                    state_next   = START_L;
                    counter_next = 0;
                end else begin
                    wr_en_next  = 1'b0;
                    signal_next = 1'b1;
                    mode_next   = 1'b1;
                end
            end
            START_L: begin
                if (tick) begin
                    counter_next = counter_reg + 1;
                end
                if (counter_reg == 18000 - 1) begin
                    state_next   = START_H;
                    counter_next = 0;
                end else begin
                    signal_next = 1'b0;
                end
            end
            START_H: begin
                signal_next = 1'b1;
                if (tick) begin
                    counter_next = counter_reg + 1;
                    if (counter_reg == 25 - 1) begin
                        mode_next = 1'b0;
                        state_next = WAIT_H;
                        counter_next = 0;
                    end
                end
            end
            WAIT_H: begin
                if (tick) begin
                    if (dht11_data) begin
                        state_next   = WAIT_L;
                        counter_next = 0;
                    end
                end
            end
            WAIT_L: begin
                if (tick) begin
                    if (!dht11_data) begin
                        state_next = READ_LOW;
                        i_next = 0;
                    end
                end
            end
            READ_LOW: begin
                if (tick) begin
                    if (i_reg == 40) begin
                        counter_next = 0;
                        state_next = DATA_DIST;
                        i_next = 0;
                    end else begin
                        if (dht11_data) begin
                            state_next   = READ_HIGH;
                            counter_next = 0;
                        end
                    end
                end
            end
            READ_HIGH: begin
                if (tick) begin
                    counter_next = counter_reg + 1;
                    if (dht11_data == 1'b0) begin
                        counter_next = 0;
                        if (counter_reg > 40) begin
                            tem_hum_data_next = {tem_hum_data_reg[38:0], 1'b1};
                            state_next = READ_LOW;
                            i_next = i_reg + 1;
                        end else if (counter_reg > 10) begin
                            tem_hum_data_next = {tem_hum_data_reg[38:0], 1'b0};
                            state_next = READ_LOW;
                            i_next = i_reg + 1;
                        end
                    end
                end
            end
            DATA_DIST: begin
                if (tick) begin
                    hum_int_next  = 255;
                    hum_dec_next  = 255;
                    tem_int_next  = 255;
                    tem_dec_next  = 255;
                    checksum_next = 255;
                    counter_next  = counter_reg + 1;
                    if (counter_reg == 50 - 1) begin
                        if (tem_hum_data_reg[7:0] == (tem_hum_data_reg[39:32] + tem_hum_data_reg[31:24]
                                                      + tem_hum_data_reg[23:16] + tem_hum_data_reg[15:8])) begin
                            hum_int_next  = tem_hum_data_reg[39:32];
                            hum_dec_next  = tem_hum_data_reg[31:24];
                            tem_int_next  = tem_hum_data_reg[23:16];
                            tem_dec_next  = tem_hum_data_reg[15:8];
                            checksum_next = tem_hum_data_reg[7:0];
                            counter_next  = 0;
                            i_next        = 0;
                            wr_en_next    = 1'b1;
                            state_next    = IDLE;
                        end else begin
                            hum_int_next = 0;
                            hum_dec_next = 0;
                            tem_int_next = 0;
                            tem_dec_next = 0;
                            counter_next = 0;
                            i_next       = 0;
                            wr_en_next   = 1'b1;
                            state_next   = IDLE;
                        end
                    end
                end
            end
        endcase
    end

endmodule

