`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/21 11:16:53
// Design Name: 
// Module Name: fifo
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


module fifo (
    input        clk,
    input        reset,
    input  [7:0] wdata,
    input        wr_en,
    input        rd_en,
    output [7:0] rdata,
    output       full,
    output       empty
);

    wire [3:0] w_wr_ptr, w_rd_ptr;

    register_file U_register_file (
        .clk  (clk),
        .waddr(w_wr_ptr),
        .wdata(wdata),
        .wr_en(wr_en & ~full),
        .raddr(w_rd_ptr),
        .rdata(rdata)
    );

    fifo_control_unit U_fifo_control_unit (
        .clk(clk),
        .reset(reset),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_ptr(w_wr_ptr),
        .full(full),
        .rd_ptr(w_rd_ptr),
        .empty(empty)
    );
endmodule

module register_file (
    input        clk,
    input  [3:0] waddr,
    input  [7:0] wdata,
    input        wr_en,
    input  [3:0] raddr,
    output [7:0] rdata
);

    reg [7:0] mem[0:15];

    always @(posedge clk) begin
        if (wr_en) begin
            mem[waddr] <= wdata;
        end
    end

    assign rdata = mem[raddr];
endmodule

module fifo_control_unit (
    input        clk,
    input        reset,
    input        wr_en,
    input        rd_en,
    output [3:0] wr_ptr,
    output       full,
    output [3:0] rd_ptr,
    output       empty
);

    reg full_reg, full_next;
    reg empty_reg, empty_next;
    reg [3:0] wr_ptr_reg, wr_ptr_next;
    reg [3:0] rd_ptr_reg, rd_ptr_next;

    assign full   = full_reg;
    assign empty  = empty_reg;
    assign wr_ptr = wr_ptr_reg;
    assign rd_ptr = rd_ptr_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            full_reg   <= 0;
            empty_reg  <= 1;
            wr_ptr_reg <= 0;
            rd_ptr_reg <= 0;
        end else begin
            full_reg   <= full_next;
            empty_reg  <= empty_next;
            wr_ptr_reg <= wr_ptr_next;
            rd_ptr_reg <= rd_ptr_next;
        end
    end

    always @(*) begin
        full_next   = full_reg;
        empty_next  = empty_reg;
        wr_ptr_next = wr_ptr_reg;
        rd_ptr_next = rd_ptr_reg;
        case ({
            wr_en, rd_en
        })
            2'b01: begin  // read
                if (!empty_reg) begin
                    full_next   = 1'b0;
                    rd_ptr_next = rd_ptr_reg + 1;
                    if (rd_ptr_next == wr_ptr_reg) begin
                        empty_next = 1'b1;
                    end
                end
            end
            2'b10: begin  // write
                if (!full_reg) begin
                    empty_next  = 1'b0;
                    wr_ptr_next = wr_ptr_reg + 1;
                    if (wr_ptr_next == rd_ptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end
            2'b11: begin  // write, read
                if (empty_reg) begin
                    wr_ptr_next = wr_ptr_reg + 1;
                end else if (full_reg) begin
                    rd_ptr_next = rd_ptr_reg + 1;
                end else begin
                    wr_ptr_next = wr_ptr_reg + 1;
                    rd_ptr_next = rd_ptr_reg + 1;
                end
            end
            default: ;
        endcase
    end

endmodule
