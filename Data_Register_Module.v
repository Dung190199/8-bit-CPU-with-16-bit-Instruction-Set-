`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:43:28
// Design Name: 
// Module Name: Data_Register_Module
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

//==============================================================================
// Data_Register_Module.v
// 8 x 8-bit register file.
//   Write : synchronous, enabled by Enable_write
//   Read A: combinational, gated by Enable_Read_Data_A (1-operand ops)
//   Read B: combinational, gated by Enable_Read_Data_B (2-operand ops)
//   result: combinational read of regfile[0] for 7-segment display
//==============================================================================

module Data_Register_Module(
    input            clk,
    input            reset,

    input            Enable_write,
    input  [7:0]     Data_write,
    input  [2:0]     Data_write_address,

    input            Enable_Read_Data_A,
    input  [2:0]     Data_A_address,
    output [7:0]     Data_out_A,

    input            Enable_Read_Data_B,
    input  [2:0]     Data_B_address,
    output [7:0]     Data_out_B,

    output [7:0]     result,
    output           check
);

    integer i;
    reg [7:0] regfile [0:7];
    reg       written;           // first-back, replaces hardwired check
    
    always @(posedge clk) begin
        if (!reset) begin
            for (i = 0; i < 8; i = i + 1)
                regfile[i] <= 8'h00;
                written <= 1'b0;
        end
        else if (Enable_write) begin
            regfile[Data_write_address] <= Data_write;
            written <= 1'b1;
        end
    end

    assign Data_out_A = Enable_Read_Data_A ? regfile[Data_A_address] : 8'h00;
    assign Data_out_B = Enable_Read_Data_B ? regfile[Data_B_address] : 8'h00;
    assign result     = regfile[0];
    assign check      = written;  

endmodule