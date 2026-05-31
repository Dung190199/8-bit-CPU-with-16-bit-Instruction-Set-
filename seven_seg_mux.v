`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:45:56
// Design Name: 
// Module Name: seven_seg_mux
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
// sen_seg_mux.v  (filename preserved from original)
// Time-multiplexed 3-digit 7-segment display driver.
// Refresh: 100 MHz / 2^18 ≈ 381 Hz per digit (>60 Hz, no flicker).
// Digit 3 (an[3]) is blanked (4th digit unused on Basys3/Nexys).
// Active-low anode: 0 = digit ON.
//==============================================================================

module seven_seg_mux (
    input            clk,
    input            reset,
    input  [6:0]     seg_hun,
    input  [6:0]     seg_ten,
    input  [6:0]     seg_one,
    output reg [6:0] seg,
    output reg [3:0] an
);

    reg [17:0] refresh_counter;

    always @(posedge clk) begin
        if (!reset) refresh_counter <= 18'd0;
        else        refresh_counter <= refresh_counter + 18'd1;
    end

    always @(*) begin
        case (refresh_counter[17:16])
            2'b00: begin an = 4'b1110; seg = seg_one; end
            2'b01: begin an = 4'b1101; seg = seg_ten; end
            2'b10: begin an = 4'b1011; seg = seg_hun; end
            2'b11: begin an = 4'b0111; seg = 7'b1111111; end
        endcase
    end

endmodule