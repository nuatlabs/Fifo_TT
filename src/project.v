/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * tt_um_nuatlabs_fifo_pwm
 * -----------------------
 * Dual-function digital ASIC subsystem sharing a single Tiny Tapeout tile (1x1):
 *
 * Block 1: Asynchronous FIFO with Clock Domain Crossing (CDC)
 *   - Depth: 8 entries, Width: 4 bits.
 *   - Dual independent clock domains (Write clk: `clk`, Read clk: `clk` or `ext_rd_clk`).
 *   - Classic Gray-coded read/write pointers with 2-stage flip-flop synchronizers.
 *   - Live FIFO occupancy (0..8) decoded and driven onto the on-board 7-segment display.
 *
 * Block 2: Reusable Pulse-Width Modulation (PWM) Peripheral
 *   - Free-running 8-bit timebase counter with 4-bit programmable duty cycle (16 steps).
 *   - Independent enable and synchronous duty reload latching.
 *   - Suitable for immediate drop-in reuse as an SoC memory-mapped peripheral.
 *
 * Pinout & Interface Mapping
 * --------------------------
 * Dedicated Inputs (ui_in):
 *   ui_in[0] : fifo_wr_en        (Write enable pulse, write domain)
 *   ui_in[1] : fifo_rd_en        (Read enable pulse, read domain)
 *   ui_in[2] : pwm_duty_load     (Capture duty_in into PWM duty register)
 *   ui_in[3] : pwm_enable        (Enable PWM counter and output generation)
 *   ui_in[4] : fifo_rd_clk_sel   (Read clock select:
 *                                   1 = Synchronous fallback using primary `clk` (stock TT board)
 *                                   0 = Asynchronous mode using `ext_rd_clk` on ui_in[7])
 *   ui_in[5] : unused / reserved (tied to internal unused sink)
 *   ui_in[6] : unused / reserved (tied to internal unused sink)
 *   ui_in[7] : ext_rd_clk        (Secondary asynchronous read-domain clock input)
 *
 * Dedicated Outputs (uo_out):
 *   uo_out[6:0] : 7-segment display segments {g,f,e,d,c,b,a} showing FIFO occupancy (0..8)
 *   uo_out[7]   : pwm_out (Digital PWM square wave)
 *
 * Bidirectional IOs (uio):
 *   uio_in[3:0]  : Time-multiplexed inputs:
 *                    - fifo_wr_data[3:0] (sampled when fifo_wr_en=1)
 *                    - pwm_duty_in[3:0]  (sampled when pwm_duty_load=1)
 *   uio_out[7:4] : fifo_rd_data[3:0] (Read domain FIFO output data)
 *   uio_out[3:0] : Driven to 4'b0000 (disabled by output enable mask)
 *   uio_oe[7:0]  : 8'b1111_0000 (Pins [7:4] configured as outputs, [3:0] as inputs)
 */
`default_nettype none

module tt_um_nuatlabs_fifo_pwm (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active-high: 0=input, 1=output)
    input  wire       ena,      // Tiny Tapeout design select (always high when powered)
    input  wire       clk,      // Primary system clock (write domain)
    input  wire       rst_n     // Active-low global asynchronous reset
);

  // -------------------------------------------------------------
  // Control signal breakout
  // -------------------------------------------------------------
  wire fifo_wr_en        = ui_in[0];
  wire fifo_rd_en        = ui_in[1];
  wire pwm_duty_load     = ui_in[2];
  wire pwm_enable        = ui_in[3];
  wire fifo_rd_clk_sel   = ui_in[4]; // 1 = use main clk for read domain
  wire ext_rd_clk        = ui_in[7];

  wire [3:0] fifo_wr_data = uio_in[3:0];
  wire [3:0] pwm_duty_in  = uio_in[3:0];

  // Read-domain clock mux: lets the design be demoed with just the
  // stock TT devkit (fifo_rd_clk_sel = 1, no extra hardware needed),
  // or with a real second clock on ui_in[7] for a true async CDC test.
  wire fifo_rd_clk = fifo_rd_clk_sel ? clk : ext_rd_clk;

  // -------------------------------------------------------------
  // Block 1: async FIFO with CDC
  // -------------------------------------------------------------
  wire       fifo_full;
  wire       fifo_empty;
  wire [3:0] fifo_occupancy; // 0..8
  wire [3:0] fifo_rd_data;

  async_fifo_cdc #(
      .WIDTH  (4),
      .ADDR_W (3)             // 8-entry FIFO
  ) u_fifo (
      .wr_clk       (clk),
      .wr_rst_n     (rst_n),
      .wr_en        (fifo_wr_en),
      .wr_data      (fifo_wr_data),
      .full         (fifo_full),
      .occupancy_wr (fifo_occupancy),

      .rd_clk       (fifo_rd_clk),
      .rd_rst_n     (rst_n),
      .rd_en        (fifo_rd_en),
      .rd_data      (fifo_rd_data),
      .empty        (fifo_empty)
  );

  wire [6:0] seg_pattern;
  seg7_decoder u_seg7 (
      .value (fifo_occupancy),
      .seg   (seg_pattern)
  );

  // -------------------------------------------------------------
  // Block 2: PWM peripheral
  // -------------------------------------------------------------
  wire pwm_out;
  pwm_gen u_pwm (
      .clk        (clk),
      .rst_n      (rst_n),
      .enable     (pwm_enable),
      .duty_load  (pwm_duty_load),
      .duty_in    (pwm_duty_in),
      .pwm_out    (pwm_out)
  );

  // -------------------------------------------------------------
  // Output mapping
  // -------------------------------------------------------------
  assign uo_out  = {pwm_out, seg_pattern};

  assign uio_out = {fifo_rd_data, 4'b0000};
  assign uio_oe  = 8'b1111_0000; // [7:4] output (rd_data), [3:0] input (wr_data/duty)

  // -------------------------------------------------------------
  // Unused signal sink (fifo_full/fifo_empty are available for a
  // future revision that exposes them on spare pins; ena is fixed
  // high whenever the design is powered)
  // -------------------------------------------------------------
  wire _unused = &{ena, fifo_full, fifo_empty, ui_in[5], ui_in[6], uio_in[7:4], 1'b0};

endmodule
