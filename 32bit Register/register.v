`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/19 09:38:12
// Design Name: 
// Module Name: register
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


module register (
    input         clk,
    input         reset,
    input  [31:0] d,
    output [31:0] q
);

    reg [31:0] q_reg;
    assign q = q_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            q_reg <= 0;
        end else begin
            q_reg <= d;
        end
    end
endmodule
