`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:41:51
// Design Name: 
// Module Name: ALU_Module
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
// alu_1.v
//
// YEL5 fix (docx 6.2): renamed ports to match actual datapath semantics:
//   Data_in_SRC  (was Data_in_A) = mux output: immediate or register read-A
//   Data_in_DEST (was Data_in_B) = register file read-B (destination current value)
//
// The original Data_in_A / Data_in_B naming was reversed relative to
// conventional "A=destination, B=source" ALU convention, causing confusion
// when reading SUB: result = Data_in_B - Data_in_A = DEST - SRC. Correct.
//
// ORG8 fix: check = Enable_cal (HIGH during the cycle the ALU is computing).
//
// Operation table:
//   MOV : result = Data_in_SRC
//   ADD : result = Data_in_SRC  + Data_in_DEST
//   SUB : result = Data_in_DEST - Data_in_SRC
//   ABS : result = |Data_in_SRC|
//   NOT : result = ~Data_in_SRC
//   AND : result = Data_in_SRC  & Data_in_DEST
//   NEG : result = ~Data_in_SRC + 1
//   HLT : hold (Enable_cal never asserted by decoder for HLT)
//==============================================================================

module ALU_Module (
    input            CLK,
    input            RESET,
    input            Enable_cal,
    input  [2:0]     FS,
    input  [7:0]     Data_in_SRC,    // YEL5: renamed from Data_in_A
    input  [7:0]     Data_in_DEST,   // YEL5: renamed from Data_in_B
    output [7:0]     Result_out,
    output           check           // ORG8: HIGH during compute cycle
);

    localparam [2:0]
        MOV = 3'b000, ADD = 3'b001, SUB = 3'b010,
        ABS = 3'b011, NOT = 3'b100, AND = 3'b101,
        NEG = 3'b110, HLT = 3'b111;

    reg [7:0] temp_result;

    assign Result_out = temp_result;
    assign check      = Enable_cal;  // ORG8: real status

    always @(posedge CLK) begin
        if (!RESET) begin
            temp_result <= 8'd0;
        end
        else if (Enable_cal) begin
            case (FS)
                MOV: temp_result <= Data_in_SRC;
                ADD: temp_result <= Data_in_SRC  + Data_in_DEST;
                SUB: temp_result <= Data_in_DEST - Data_in_SRC;
                ABS: temp_result <= Data_in_SRC[7] ? (~Data_in_SRC + 8'd1)
                                                    :   Data_in_SRC;
                NOT: temp_result <= ~Data_in_SRC;
                AND: temp_result <= Data_in_SRC  & Data_in_DEST;
                NEG: temp_result <= ~Data_in_SRC + 8'd1;
                default: temp_result <= temp_result; // HLT: hold
            endcase
        end
    end

endmodule