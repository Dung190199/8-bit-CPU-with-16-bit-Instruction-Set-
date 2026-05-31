`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:35:43
// Design Name: 
// Module Name: Machine_Code_ROM_Module
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
// machine_code_rom_1.v
// 8 x 16-bit instruction ROM.
//
// Fix YEL4 (docx 6.2): instruction_counter now freezes when current
// instruction is HLT (opcode 3'b111).  Counter only increments on CLK9
// if the instruction is NOT HLT.  On reset the counter returns to 0.
//
// ROM is implemented as localparams + combinational functions → Vivado
// infers distributed LUT-ROM (no BRAM, correct for 8 x 16b).
//==============================================================================

module Machine_Code_ROM_Module (
    input            CLK,
    input            RESET,
    input            CPU_EN,
    output reg [7:0] half_instruction,   // 8bits bus:high byte then low byte
    // YEL6 fix: master phase published as wire - no extra register stage
    output wire [3:0] phase_out
);

    // ── Opcode constant ───────────────────────────────────────────────────────
    localparam [2:0] OPC_HLT = 3'b111;
    
    // ── ROM content ───────────────────────────────────────────────────────────
    (* rom_style = "distributed" *)
    
    localparam [15:0]
        ROM_0 = 16'b000_1_1_000_00111100,   // MOV R0, 60
        ROM_1 = 16'b001_1_1_000_01000110,   // ADD R0, 70
        ROM_2 = 16'b010_1_1_000_10110100,   // SUB R0, 180
        ROM_3 = 16'b011_0_0_000_00000000,   // ABS R0
        ROM_4 = 16'b100_0_0_000_00000000,   // NOT R0
        ROM_5 = 16'b101_1_1_000_00001111,   // AND R0, 0x0F
        ROM_6 = 16'b110_0_0_000_00000000,   // NEG R0
        ROM_7 = 16'b111_0_0_000_00000000;   // HLT

    // ── Phase encoding ────────────────────────────────────────────────────────
    localparam [3:0]
        CLK1 = 4'd0, CLK2 = 4'd1, CLK3 = 4'd2,
        CLK4 = 4'd3, CLK5 = 4'd4, CLK6 = 4'd5,
        CLK7 = 4'd6, CLK8 = 4'd7, CLK9 = 4'd8;

    reg [3:0] clock;
    reg [2:0] instruction_counter;

    // ── ROM lookup functions (combinational, inferred as LUT-ROM) ─────────────
    function [7:0] rom_hi;
        input [2:0] idx;
        case (idx)
            3'd0: rom_hi = ROM_0[15:8]; 3'd1: rom_hi = ROM_1[15:8];
            3'd2: rom_hi = ROM_2[15:8]; 3'd3: rom_hi = ROM_3[15:8];
            3'd4: rom_hi = ROM_4[15:8]; 3'd5: rom_hi = ROM_5[15:8];
            3'd6: rom_hi = ROM_6[15:8]; 3'd7: rom_hi = ROM_7[15:8];
        endcase
    endfunction

    function [7:0] rom_lo;
        input [2:0] idx;
        case (idx)
            3'd0: rom_lo = ROM_0[7:0]; 3'd1: rom_lo = ROM_1[7:0];
            3'd2: rom_lo = ROM_2[7:0]; 3'd3: rom_lo = ROM_3[7:0];
            3'd4: rom_lo = ROM_4[7:0]; 3'd5: rom_lo = ROM_5[7:0];
            3'd6: rom_lo = ROM_6[7:0]; 3'd7: rom_lo = ROM_7[7:0];
        endcase
    endfunction

    assign phase_out = clock;   // YEL6: wire - zero latency broadcast
    // Must use temp variable - Verilog-2001 disallows slicing a function return
    reg [2:0] current_opcode;
    reg [7:0] hi_tmp;
    always @(*) begin
        hi_tmp        = rom_hi(instruction_counter);
        current_opcode = hi_tmp[7:5];
    end

    // ── FSM ───────────────────────────────────────────────────────────────────
    always @(posedge CLK) begin
        if (!RESET) begin
            clock               <= CLK1;
            half_instruction    <= 8'd0;
            instruction_counter <= 3'd0;
        end
        else if (CPU_EN) begin
            case (clock)
                CLK1: begin
                    half_instruction <= rom_hi(instruction_counter);
                    clock            <= CLK2;
                end
                CLK2: begin
                    half_instruction <= rom_lo(instruction_counter);
                    clock            <= CLK3;
                end
                CLK3: clock <= CLK4;
                CLK4: clock <= CLK5;
                CLK5: clock <= CLK6;
                CLK6: clock <= CLK7;
                CLK7: clock <= CLK8;
                CLK8: clock <= CLK9;
                CLK9: begin
                    clock <= CLK1;
                    // YEL4 FIX: freeze PC on HLT - do not advance to next instr
                    if (current_opcode != OPC_HLT)
                        instruction_counter <= instruction_counter + 3'd1;
                end
                default: begin
                    clock               <= CLK1;
                    half_instruction    <= 8'd0;
                    instruction_counter <= 3'd0;
                end
            endcase
        end
    end

endmodule