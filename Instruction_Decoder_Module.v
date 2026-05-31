`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:37:56
// Design Name: 
// Module Name: Instruction_Decoder_Module
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
// instruction_decoder1.v
// (ORG7 fix: renamed from intruction_decoder1.v - typo corrected)
//
// YEL6 fix: uses master_phase from ROM instead of independent clock counter.
// ORG8 fix: check = Enable_ALU | Enable_Write_Data (decoder is active).
//
// Enable_control bit map:
//   [0] Enable_RegALU_mul  - mux selects immediate operand
//   [1] Enable_ALU         - ALU compute enable
//   [2] Enable_Write_Data  - register file write enable
//   [3] Enable_Read_Data_A - port A (1-operand ops: ABS, NOT, NEG)
//   [4] Enable_Read_Data_B - port B (2-operand ops: ADD, SUB, AND, MOV)
//==============================================================================

module Instruction_Decoder_Module (
    input            CLK,
    input            RESET,
    input            CPU_EN,
    input  [3:0]     master_phase,   // YEL6: from ROM master counter

    input  [2:0]     Opcode,
    input  [2:0]     Operand_1_address,
    input            Operand_2_type,
    input            Operand_number,

    output [2:0]     Opcode_out,
    output           Enable_RegALU_mul,
    output           Enable_ALU,
    output           Enable_Write_Data,
    output           Enable_Read_Data_A,
    output           Enable_Read_Data_B,

    output [2:0]     Operand_1_address_to_write,
    output [2:0]     Operand_1_address_to_A,
    output [2:0]     Operand_1_address_to_B,

    output           check           // ORG8: active when decoder is driving datapath
);

    localparam [2:0]
        MOV = 3'b000, ADD = 3'b001, SUB = 3'b010,
        ABS = 3'b011, NOT = 3'b100, AND = 3'b101,
        NEG = 3'b110, HLT = 3'b111;

    localparam [3:0]
        CLK1 = 4'd0, CLK2 = 4'd1, CLK3 = 4'd2,
        CLK4 = 4'd3, CLK5 = 4'd4, CLK6 = 4'd5,
        CLK7 = 4'd6, CLK8 = 4'd7, CLK9 = 4'd8;

    reg [4:0] Enable_control;
    reg [2:0] Opcode_register;
    reg [2:0] Operand_1_address_register_to_write;
    reg [2:0] Operand_1_address_register_to_A;
    reg [2:0] Operand_1_address_register_to_B;

    assign Enable_RegALU_mul          = Enable_control[0];
    assign Enable_ALU                 = Enable_control[1];
    assign Enable_Write_Data          = Enable_control[2];
    assign Enable_Read_Data_A         = Enable_control[3];
    assign Enable_Read_Data_B         = Enable_control[4];
    assign Opcode_out                 = Opcode_register;
    assign Operand_1_address_to_write = Operand_1_address_register_to_write;
    assign Operand_1_address_to_A     = Operand_1_address_register_to_A;
    assign Operand_1_address_to_B     = Operand_1_address_register_to_B;
    // ORG8: check HIGH during active decode/execute/writeback window
    assign check = Enable_control[1] | Enable_control[2];

    always @(posedge CLK) begin
        if (!RESET) begin
            Enable_control                       <= 5'd0;
            Opcode_register                      <= HLT;
            Operand_1_address_register_to_write  <= 3'd0;
            Operand_1_address_register_to_A      <= 3'd0;
            Operand_1_address_register_to_B      <= 3'd0;
        end
        else if (CPU_EN) begin
            // YEL6: decode on master_phase
            case (master_phase)
                CLK3: begin
                    Opcode_register <= Opcode;
                end

                CLK4: begin
                    case (Opcode_register)
                        MOV, ADD, SUB, AND: Enable_control[0] <= 1'b1;
                        default:            Enable_control[0] <= 1'b0;
                    endcase
                end

                CLK5: begin
                    case (Opcode_register)
                        ADD, SUB, AND: begin
                            Operand_1_address_register_to_B <= Operand_1_address;
                            Enable_control[4]               <= 1'b1;
                        end
                        ABS, NOT, NEG: begin
                            Operand_1_address_register_to_A <= Operand_1_address;
                            Enable_control[3]               <= 1'b1;
                        end
                        default: ;
                    endcase
                end

                CLK6: begin
                    Enable_control[1] <= 1'b1;
                end

                CLK7: begin
                    Enable_control[1] <= 1'b0;
                    case (Opcode_register)
                        MOV: begin
                            Enable_control[2]                   <= 1'b1;
                            Operand_1_address_register_to_write <= Operand_1_address;
                        end
                        ADD, SUB, AND: Enable_control[4] <= 1'b0;
                        ABS, NOT, NEG: Enable_control[3] <= 1'b0;
                        default: ;
                    endcase
                end

                CLK8: begin
                    case (Opcode_register)
                        ADD, SUB, ABS, AND, NOT, NEG: begin
                            Enable_control[2]                   <= 1'b1;
                            Operand_1_address_register_to_write <= Operand_1_address;
                        end
                        default: ;
                    endcase
                end

                CLK9: begin
                    // clear all bits 
                    Enable_control <= 5'd0;
                end
                
                default: ;
            endcase
        end
    end

endmodule