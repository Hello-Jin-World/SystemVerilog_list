`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/20 16:28:38
// Design Name: 
// Module Name: dual_port_ram
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


module dual_port_ram (
    input        clk,
    input  [3:0] waddr,
    input  [3:0] raddr,
    input  [7:0] wdata,
    input        write,
    output [7:0] rdata
);

    reg [7:0] mem[0:15];

    always @(posedge clk) begin
        if (write) begin
            mem[waddr] <= wdata;
        end
    end

    assign rdata = mem[raddr];
endmodule
