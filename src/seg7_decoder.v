/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * seg7_decoder
 * ------------
 * Decodes a 4-bit binary value (0-8, representing FIFO occupancy 0..DEPTH)
 * into an active-high 7-segment LED driver pattern.
 *
 * Segment Layout:
 *      aaa
 *     f   b
 *     f   b
 *      ggg
 *     e   c
 *     e   c
 *      ddd
 *
 * Output Bit Mapping:
 *   seg[0] = Segment 'a' (top)
 *   seg[1] = Segment 'b' (top-right)
 *   seg[2] = Segment 'c' (bottom-right)
 *   seg[3] = Segment 'd' (bottom)
 *   seg[4] = Segment 'e' (bottom-left)
 *   seg[5] = Segment 'f' (top-left)
 *   seg[6] = Segment 'g' (middle)
 *
 * Format: {g, f, e, d, c, b, a}
 * This bit ordering directly matches the standard Tiny Tapeout demo-board
 * 7-segment display wiring connected to dedicated output pins uo_out[6:0].
 */
`default_nettype none

module seg7_decoder (
    input  wire [3:0] value,   // Binary input value (valid range: 0..8)
    output reg  [6:0] seg     // Active-high segment outputs: {g,f,e,d,c,b,a}
);

  always @(*) begin
    case (value)
      4'd0: seg = 7'b0111111; // 0
      4'd1: seg = 7'b0000110; // 1
      4'd2: seg = 7'b1011011; // 2
      4'd3: seg = 7'b1001111; // 3
      4'd4: seg = 7'b1100110; // 4
      4'd5: seg = 7'b1101101; // 5
      4'd6: seg = 7'b1111101; // 6
      4'd7: seg = 7'b0000111; // 7
      4'd8: seg = 7'b1111111; // 8
      default: seg = 7'b1000000; // dash, shouldn't happen for depth-8 FIFO
    endcase
  end

endmodule
