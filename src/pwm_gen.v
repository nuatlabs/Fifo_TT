/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * pwm_gen
 * -------
 * Small, reusable PWM peripheral. Free-running 8-bit counter compared
 * against a 4-bit duty register (16 duty steps). Duty is loaded from
 * an external 4-bit bus on a load pulse. Designed to be reused
 * as-is later as a memory-mapped peripheral in a larger RISC-V SoC
 * (register interface can be wrapped around duty_in/load/enable).
 */
`default_nettype none

module pwm_gen (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       duty_load,     // pulse: capture duty_in on this clk edge
    input  wire [3:0] duty_in,       // 0..15 -> duty cycle in 16ths
    output wire       pwm_out
);

  reg [7:0] counter;
  reg [3:0] duty_reg;

  // Free-running counter (only when enabled)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      counter <= 8'd0;
    else if (enable)
      counter <= counter + 8'd1;
  end

  // Duty register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      duty_reg <= 4'd0;
    else if (duty_load)
      duty_reg <= duty_in;
  end

  // PWM: high while the top 4 bits of the counter are below duty_reg
  assign pwm_out = enable && (counter[7:4] < duty_reg);

endmodule
