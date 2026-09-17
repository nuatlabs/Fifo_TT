/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * seg7_decoder
 * ------------
 * Decodes a 4-bit value (0-8, used here for FIFO occupancy 0..DEPTH)
 * into a 7-segment pattern, active-high, segment order {g,f,e,d,c,b,a}
 * matching the standard Tiny Tapeout demo-board 7-segment wiring
 * (seg[6:0] = g,f,e,d,c,b,a).
 */
`default_nettype none

module seg7_decoder (
    input  wire [3:0] value,
    output reg  [6:0] seg   // {g,f,e,d,c,b,a}
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
