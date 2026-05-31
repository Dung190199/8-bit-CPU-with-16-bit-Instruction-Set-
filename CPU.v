`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:46:37
// Design Name: 
// Module Name: CPU
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
// CPU.v - structural wrapper
//
// Changes vs previous version:
//   YEL5: ALU ports renamed Data_in_SRC / Data_in_DEST
//   YEL6: master_phase broadcast from ROM to IR and Decoder
//   ORG7: instantiates instruction_register1 / instruction_decoder1
//         (renamed modules; old intruction_* names retired)
//   ORG8: check_* now carry real status signals
//==============================================================================

module CPU (
    input  wire       clk,
    input  wire       reset,
    input  wire       cpu_en,
    output wire [7:0] databus,
    output wire [7:0] result_out,
    output wire       check_instruction_register,
    output wire       check_instruction_decoder,
    output wire       check_data_register,
    output wire       check_alu,
    output wire       check_mul
);

    // ── Internal wires ────────────────────────────────────────────────────────
    wire [7:0] half_instruction;
    wire [3:0] master_phase;          // YEL6: single phase bus

    wire [2:0] Opcode;
    wire [7:0] Operand_2;
    wire       Operand_num;
    wire       Operand_2_type;
    wire [2:0] Operand_1_address;

    wire [2:0] Opcode_out;
    wire       Enable_RegALU_mul;
    wire       Enable_ALU;
    wire       Enable_Write_Data;
    wire       Enable_Read_Data_A;
    wire       Enable_Read_Data_B;
    wire [2:0] Operand_1_address_to_write;
    wire [2:0] Operand_1_address_to_A;
    wire [2:0] Operand_1_address_to_B;

    wire [7:0] Data_out_A;
    wire [7:0] Data_out_B;
    wire [7:0] Data_out_mux;
    wire [7:0] Result_out_alu;

    // ── ROM (master phase source) ─────────────────────────────────────────────
    Machine_Code_ROM_Module u_rom (
        .CLK             (clk),
        .RESET           (reset),
        .CPU_EN          (cpu_en),
        .half_instruction(half_instruction),
        .phase_out       (master_phase)     // YEL6
    );

    // ── Instruction Register ──────────────────────────────────────────────────
    Instruction_Register_Module u_ir (
        .CLK                (clk),
        .RESET              (reset),
        .CPU_EN             (cpu_en),
        .master_phase       (master_phase),  // YEL6
        .Instruction_in     (half_instruction),
        .Opcode             (Opcode),
        .Operand_2          (Operand_2),
        .Operand_num        (Operand_num),
        .Operand_2_type     (Operand_2_type),
        .Operand_1_address  (Operand_1_address),
        .check              (check_instruction_register) // ORG8
    );

    // ── Instruction Decoder ───────────────────────────────────────────────────
    Instruction_Decoder_Module u_dec (
        .CLK                        (clk),
        .RESET                      (reset),
        .CPU_EN                     (cpu_en),
        .master_phase               (master_phase),  // YEL6
        .Opcode                     (Opcode),
        .Operand_1_address          (Operand_1_address),
        .Operand_2_type             (Operand_2_type),
        .Operand_number             (Operand_num),
        .Opcode_out                 (Opcode_out),
        .Enable_RegALU_mul          (Enable_RegALU_mul),
        .Enable_ALU                 (Enable_ALU),
        .Enable_Write_Data          (Enable_Write_Data),
        .Enable_Read_Data_A         (Enable_Read_Data_A),
        .Enable_Read_Data_B         (Enable_Read_Data_B),
        .Operand_1_address_to_write (Operand_1_address_to_write),
        .Operand_1_address_to_A     (Operand_1_address_to_A),
        .Operand_1_address_to_B     (Operand_1_address_to_B),
        .check                      (check_instruction_decoder) // ORG8
    );

    // ── Mux ───────────────────────────────────────────────────────────────────
    Mul_Reg_to_ALU_Module u_mux (
        .selection      (Enable_RegALU_mul),
        .Immediate_data (Operand_2),
        .Register_data  (Data_out_A),
        .Data_out       (Data_out_mux),
        .check          (check_mul)
    );

    // ── ALU (YEL5: updated port names) ───────────────────────────────────────
    ALU_Module u_alu (
        .CLK         (clk),
        .RESET       (reset),
        .Enable_cal  (Enable_ALU),
        .FS          (Opcode_out),
        .Data_in_SRC (Data_out_mux),   // YEL5
        .Data_in_DEST(Data_out_B),     // YEL5
        .Result_out  (Result_out_alu),
        .check       (check_alu)       // ORG8
    );

    // ── Register File ─────────────────────────────────────────────────────────
    Data_Register_Module u_rf (
        .clk                (clk),
        .reset              (reset),
        .Enable_write       (Enable_Write_Data),
        .Data_write         (Result_out_alu),
        .Data_write_address (Operand_1_address_to_write),
        .Enable_Read_Data_A (Enable_Read_Data_A),
        .Data_A_address     (Operand_1_address_to_A),
        .Data_out_A         (Data_out_A),
        .Enable_Read_Data_B (Enable_Read_Data_B),
        .Data_B_address     (Operand_1_address_to_B),
        .Data_out_B         (Data_out_B),
        .result             (result_out),
        .check              (check_data_register)
    );

    assign databus = half_instruction;

endmodule
