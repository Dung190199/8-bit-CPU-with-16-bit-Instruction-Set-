`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:36:55
// Design Name: 
// Module Name: Instruction_Register_Module
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
// instruction_register1.v
// (ORG7 fix: renamed from intruction_register1.v - typo corrected)
//
// Latches 5 instruction fields from the 2-byte ROM stream.
//   CLK2: latch high byte → Opcode, Operand_num, Operand_2_type, Operand_1_address
//   CLK3: latch low  byte → Operand_2 (immediate value)
//
// YEL6 fix: phase counter driven by master_phase input from ROM module,
// eliminating the independent counter.
//
// ORG8 fix: check output reflects real "register loaded" status -
//   HIGH once Operand_2 has been latched (after CLK3 of first instruction).
//==============================================================================

module Instruction_Register_Module (
    input            CLK,
    input  [7:0]     Instruction_in,
    input            RESET,
    input            CPU_EN,
    input  [3:0]     master_phase,   // YEL6: from ROM master counter

    output [2:0]     Opcode,
    output [7:0]     Operand_2,
    output           Operand_num,
    output           Operand_2_type,
    output [2:0]     Operand_1_address,
    output           check           // ORG8: 1 when register loaded with valid data
);

    localparam [3:0]
        CLK1 = 4'd0, CLK2 = 4'd1, CLK3 = 4'd2,
        CLK4 = 4'd3, CLK5 = 4'd4, CLK6 = 4'd5,
        CLK7 = 4'd6, CLK8 = 4'd7, CLK9 = 4'd8;

    reg [2:0] reg_Opcode;
    reg [7:0] reg_Operand_2;
    reg       reg_Operand_num;
    reg       reg_Operand_2_type;
    reg [2:0] reg_Operand_1_address;
    reg       reg_loaded;            // ORG8: tracks if valid data present

    assign Opcode            = reg_Opcode;
    assign Operand_2         = reg_Operand_2;
    assign Operand_num       = reg_Operand_num;
    assign Operand_2_type    = reg_Operand_2_type;
    assign Operand_1_address = reg_Operand_1_address;
    assign check             = reg_loaded;

    always @(posedge CLK) begin
        if (!RESET) begin
            reg_Opcode            <= 3'd0;
            reg_Operand_num       <= 1'b0;
            reg_Operand_2_type    <= 1'b0;
            reg_Operand_1_address <= 3'd0;
            reg_Operand_2         <= 8'd0;
            reg_loaded            <= 1'b0;
        end
        else if (CPU_EN) begin
            // YEL6: use master_phase instead of local counter
            case (master_phase)
                CLK2: begin
                    reg_Opcode            <= Instruction_in[7:5];
                    reg_Operand_num       <= Instruction_in[4];
                    reg_Operand_2_type    <= Instruction_in[3];
                    reg_Operand_1_address <= Instruction_in[2:0];
                end
                CLK3: begin
                    reg_Operand_2 <= Instruction_in;
                    reg_loaded    <= 1'b1;   // ORG8: valid from this point
                end
                default: ; // hold all fields
            endcase
        end
    end

endmodule