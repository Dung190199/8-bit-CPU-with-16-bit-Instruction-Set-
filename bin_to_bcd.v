`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.05.2026 11:44:38
// Design Name: 
// Module Name: bin_to_bcd
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
// bin_to_bcd.v
// 8-bit binary → 3-digit BCD (Double-Dabble), purely combinational.
//==============================================================================

module bin_to_bcd (
    input  [7:0]     bin,
    output reg [3:0] hundreds,
    output reg [3:0] tens,
    output reg [3:0] ones
);

    integer    i;
    reg [19:0] shift;

    always @(*) begin
        shift = {12'b0, bin};
        for (i = 0; i < 8; i = i + 1) begin
            if (shift[11:8]  >= 4'd5) shift[11:8]  = shift[11:8]  + 4'd3;
            if (shift[15:12] >= 4'd5) shift[15:12] = shift[15:12] + 4'd3;
            if (shift[19:16] >= 4'd5) shift[19:16] = shift[19:16] + 4'd3;
            shift = shift << 1;
        end
        hundreds = shift[19:16];
        tens     = shift[15:12];
        ones     = shift[11:8];
    end

endmodule