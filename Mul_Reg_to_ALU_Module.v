`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:39:02
// Design Name: 
// Module Name: Mul_Reg_to_ALU_Module
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
// mul_to_alu1.v
// 2-to-1 combinational mux: selects ALU operand source.
//   selection=0 → Register_data
//   selection=1 → Immediate_data
//
// ORG8 fix: check = 1 always (mux is purely combinational,
// output is always valid - this is the correct status for this module).
//==============================================================================

module Mul_Reg_to_ALU_Module (
    input            selection,
    input  [7:0]     Immediate_data,
    input  [7:0]     Register_data,
    output [7:0]     Data_out,
    output           check
);

    assign Data_out = selection ? Immediate_data : Register_data;
    assign check    = 1'b1;  // combinational path always valid

endmodule