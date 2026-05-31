`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:47:39
// Design Name: 
// Module Name: Top_Module
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
// Top_Module.v - FPGA top-level
// 100 MHz clock divider + CPU core + BCD display chain.
// Target: Basys3 / Nexys4-DDR (Artix-7 XC7A35T), 100 MHz oscillator.
//==============================================================================

module Top_Module (
    input  wire       clk,
    input  wire       reset_btn,     // btnc on basys3 is active-high 
    output wire [6:0] seg,
    output wire [3:0] an,
    output wire [7:0] led
);
    // invert button to active-low reset expected by all sib_modules.
    // reset when btnc was not pressed (btnc=0 -> reser=0 -> active-lơ asserted)
    wire reset = ~reset_btn;
    
    localparam [26:0] DIV_LIMIT = 27'd52_000_000;

    reg [26:0] slow_clk_count;
    reg        cpu_en;

    always @(posedge clk) begin
        if (!reset) begin
            slow_clk_count <= 27'd0;
            cpu_en         <= 1'b0;
        end
        else begin
            if (slow_clk_count == DIV_LIMIT) begin
                slow_clk_count <= 27'd0;
                cpu_en         <= 1'b1;
            end
            else begin
                slow_clk_count <= slow_clk_count + 27'd1;
                cpu_en         <= 1'b0;
            end
        end
    end

    wire [7:0] cpu_result;
    wire [7:0] data_bus;

    CPU my_cpu (
        .clk                        (clk),
        .reset                      (reset),
        .cpu_en                     (cpu_en),
        .databus                    (data_bus),
        .result_out                 (cpu_result),
        .check_instruction_register (led[0]),
        .check_instruction_decoder  (led[1]),
        .check_data_register        (led[2]),
        .check_alu                  (led[3]),
        .check_mul                  (led[4])
    );

    assign led[5] = 1'b0;
    assign led[6] = 1'b0;
    assign led[7] = cpu_en;

    wire [3:0] bcd_hun, bcd_ten, bcd_one;
    wire [6:0] seg_hun, seg_ten, seg_one;

    bin_to_bcd bcd_conv (
        .bin      (cpu_result),
        .hundreds (bcd_hun),
        .tens     (bcd_ten),
        .ones     (bcd_one)
    );

    hex_to_7seg dec_hun (.digit(bcd_hun), .seg(seg_hun));
    hex_to_7seg dec_ten (.digit(bcd_ten), .seg(seg_ten));
    hex_to_7seg dec_one (.digit(bcd_one), .seg(seg_one));

    seven_seg_mux mux_display (
        .clk     (clk),
        .reset   (reset),
        .seg_hun (seg_hun),
        .seg_ten (seg_ten),
        .seg_one (seg_one),
        .seg     (seg),
        .an      (an)
    );

endmodule