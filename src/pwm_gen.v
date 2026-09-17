/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * pwm_gen
 * -------
 * Small, reusable Pulse-Width Modulation (PWM) generator peripheral.
 *
 * Theory of Operation:
 * - Employs a free-running 8-bit counter (period = 256 system clock cycles).
 * - A 4-bit programmable duty register (`duty_reg`) provides 16 discrete
 *   duty cycle levels (0/16 up to 15/16).
 * - Comparison logic compares the top 4 bits of the 8-bit counter (`counter[7:4]`)
 *   against `duty_reg`:
 *     - If counter[7:4] < duty_reg: pwm_out = 1
 *     - If counter[7:4] >= duty_reg: pwm_out = 0
 *   Duty Cycle Table:
 *     duty_in = 4'd0  ->   0/16 =  0.00% (permanently LOW)
 *     duty_in = 4'd4  ->   4/16 = 25.00% HIGH
 *     duty_in = 4'd8  ->   8/16 = 50.00% HIGH
 *     duty_in = 4'd12 ->  12/16 = 75.00% HIGH
 *     duty_in = 4'd15 ->  15/16 = 93.75% HIGH
 *
 * Reusability Note:
 * - Fully synchronous design. Can easily be wrapped into an APB, Wishbone,
 *   or AXI-Lite memory-mapped register block for use inside an embedded RISC-V SoC.
 */
`default_nettype none

module pwm_gen (
    input  wire       clk,        // System clock
    input  wire       rst_n,      // Asynchronous active-low reset
    input  wire       enable,     // Global enable: when low, counter freezes and output is forced low
    input  wire       duty_load,  // Synchronous load pulse: captures duty_in on rising edge of clk
    input  wire [3:0] duty_in,    // 4-bit target duty cycle value (0..15)
    output wire       pwm_out     // Generated PWM output signal
);

  // 8-bit free-running timebase accumulator
  reg [7:0] counter;

  // Registered duty setting (shadowed to ensure glitch-free updates on pulse)
  reg [3:0] duty_reg;

  // -----------------------------------------------------------------
  // Free-running 8-bit Counter
  // -----------------------------------------------------------------
  // Increments every clock edge when enabled; rolls over naturally from 255 to 0.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      counter <= 8'd0;
    else if (enable)
      counter <= counter + 8'd1;
  end

  // -----------------------------------------------------------------
  // Duty Cycle Register
  // -----------------------------------------------------------------
  // Latches new duty value only when the user asserts duty_load.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      duty_reg <= 4'd0;
    else if (duty_load)
      duty_reg <= duty_in;
  end

  // -----------------------------------------------------------------
  // PWM Output Generator
  // -----------------------------------------------------------------
  // High while the upper nibble of the counter is strictly less than duty_reg.
  // Gated with enable so output is immediately silent when disabled.
  assign pwm_out = enable && (counter[7:4] < duty_reg);

endmodule
