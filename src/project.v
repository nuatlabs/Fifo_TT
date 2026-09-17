/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * tt_um_nuatlabs_fifo_pwm
 * -----------------------
 * Two digital blocks sharing one Tiny Tapeout tile:
 *
 *  1) An 8-deep, 4-bit-wide asynchronous FIFO with Gray-code pointer
 *     CDC synchronizers, occupancy shown live on a 7-segment display.
 *  2) A small PWM peripheral (4-bit duty, reusable later as a
 *     memory-mapped SoC peripheral).
 *
 * Pinout
 * ------
 * ui_in[0] : fifo_wr_en
 * ui_in[1] : fifo_rd_en
 * ui_in[2] : pwm_duty_load (pulse)
 * ui_in[3] : pwm_enable
 * ui_in[4] : fifo_rd_clk_sel  (0 = read domain clocked by ui_in[7] "ext_rd_clk",
 *                               1 = read domain clocked by the main "clk",
 *                               i.e. a synchronous fallback/test mode that
 *                               needs no external second clock source)
 * ui_in[5] : unused (reserved)
 * ui_in[6] : unused (reserved)
 * ui_in[7] : ext_rd_clk        (external clock for a true async CDC demo)
 *
 * uo_out[6:0] : 7-segment display of FIFO occupancy (0-8), {g,f,e,d,c,b,a}
 * uo_out[7]   : pwm_out
 *
 * uio_in[3:0]  : fifo_wr_data (write domain) / pwm duty_in (loaded on
 *                pwm_duty_load) -- same physical pins, time-multiplexed
 *                by which control pulse is asserted.
 * uio_out[7:4] : fifo_rd_data (read domain), zero-extended into [7:4]
 * uio[3:0]     : inputs, uio[7:4] : outputs (see uio_oe below)
 */
`default_nettype none

module tt_um_nuatlabs_fifo_pwm (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
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
