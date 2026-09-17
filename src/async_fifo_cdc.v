/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * async_fifo_cdc
 * ---------------
 * Standard dual-clock async FIFO using Gray-coded read/write pointers
 * with 2-flop synchronizers across the clock-domain crossing (the
 * classic Cliff Cummings-style structure).
 *
 * DEPTH = 2**ADDR_W entries, each WIDTH bits wide.
 *
 * occupancy_wr : number of entries currently in the FIFO, expressed
 *                in the WRITE clock domain (safe to use directly,
 *                since it is derived from the already-synchronized
 *                read pointer).
 */
`default_nettype none

module async_fifo_cdc #(
    parameter WIDTH  = 4,
    parameter ADDR_W = 3                 // 2**ADDR_W = 8 entries
) (
    // Write domain
    input  wire             wr_clk,
    input  wire             wr_rst_n,
    input  wire             wr_en,
    input  wire [WIDTH-1:0] wr_data,
    output wire             full,
    output wire [ADDR_W:0]  occupancy_wr,

    // Read domain
    input  wire             rd_clk,
    input  wire             rd_rst_n,
    input  wire             rd_en,
    output reg  [WIDTH-1:0] rd_data,
    output wire             empty
);

  localparam DEPTH = (1 << ADDR_W);

  // ---------------------------------------------------------------
  // Storage (inferred dual-port RAM)
  // ---------------------------------------------------------------
  reg [WIDTH-1:0] mem [0:DEPTH-1];

  // ---------------------------------------------------------------
  // Write-domain pointer (binary + gray), one extra MSB for full/empty
  // ---------------------------------------------------------------
  reg [ADDR_W:0] wr_ptr_bin;
  reg [ADDR_W:0] wr_ptr_gray;
  wire [ADDR_W:0] wr_ptr_bin_next  = wr_ptr_bin + (wr_en && !full);
  wire [ADDR_W:0] wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;

  always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_ptr_bin  <= {(ADDR_W+1){1'b0}};
      wr_ptr_gray <= {(ADDR_W+1){1'b0}};
    end else begin
      wr_ptr_bin  <= wr_ptr_bin_next;
      wr_ptr_gray <= wr_ptr_gray_next;
    end
  end

  always @(posedge wr_clk) begin
    if (wr_en && !full)
      mem[wr_ptr_bin[ADDR_W-1:0]] <= wr_data;
  end

  // ---------------------------------------------------------------
  // Read-domain pointer (binary + gray)
  // ---------------------------------------------------------------
  reg [ADDR_W:0] rd_ptr_bin;
  reg [ADDR_W:0] rd_ptr_gray;
  wire [ADDR_W:0] rd_ptr_bin_next  = rd_ptr_bin + (rd_en && !empty);
  wire [ADDR_W:0] rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;

  always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_ptr_bin  <= {(ADDR_W+1){1'b0}};
      rd_ptr_gray <= {(ADDR_W+1){1'b0}};
    end else begin
      rd_ptr_bin  <= rd_ptr_bin_next;
      rd_ptr_gray <= rd_ptr_gray_next;
    end
  end

  always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n)
      rd_data <= {WIDTH{1'b0}};
    else if (rd_en && !empty)
      rd_data <= mem[rd_ptr_bin[ADDR_W-1:0]];
  end

  // ---------------------------------------------------------------
  // CDC: 2-flop synchronizers (Gray code -> single-bit-change safe)
  // ---------------------------------------------------------------
  reg [ADDR_W:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2; // wr->rd domain
  reg [ADDR_W:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2; // rd->wr domain

  always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      wr_ptr_gray_sync1 <= {(ADDR_W+1){1'b0}};
      wr_ptr_gray_sync2 <= {(ADDR_W+1){1'b0}};
    end else begin
      wr_ptr_gray_sync1 <= wr_ptr_gray;
      wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
    end
  end

  always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      rd_ptr_gray_sync1 <= {(ADDR_W+1){1'b0}};
      rd_ptr_gray_sync2 <= {(ADDR_W+1){1'b0}};
    end else begin
      rd_ptr_gray_sync1 <= rd_ptr_gray;
      rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
    end
  end

  // ---------------------------------------------------------------
  // Full / empty flags (standard Gray-code MSB-inverted-match rule)
  // ---------------------------------------------------------------
  assign empty = (rd_ptr_gray == wr_ptr_gray_sync2);

  // NOTE: deliberately compares the CURRENT registered wr_ptr_gray
  // (not wr_ptr_gray_next) -- using the "next" value here would make
  // full combinationally depend on itself through wr_ptr_bin_next's
  // "(wr_en && !full)" gating term, an unstable zero-delay loop.
  // Using the current pointer (same pattern as `empty` above) means
  // full asserts one cycle after occupancy reaches DEPTH, which is
  // enough to block the following write and is standard practice.
  assign full  = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_W:ADDR_W-1],
                                   rd_ptr_gray_sync2[ADDR_W-2:0]});

  // ---------------------------------------------------------------
  // Occupancy, computed in the WRITE domain from the synchronized
  // (Gray-decoded) read pointer -- safe, no metastability risk here
  // since rd_ptr_gray_sync2 is already double-flopped.
  // ---------------------------------------------------------------
  function [ADDR_W:0] gray2bin(input [ADDR_W:0] g);
    integer i;
    begin
      gray2bin[ADDR_W] = g[ADDR_W];
      for (i = ADDR_W-1; i >= 0; i = i-1)
        gray2bin[i] = gray2bin[i+1] ^ g[i];
    end
  endfunction

  wire [ADDR_W:0] rd_ptr_bin_sync_wr = gray2bin(rd_ptr_gray_sync2);
  assign occupancy_wr = wr_ptr_bin - rd_ptr_bin_sync_wr;

endmodule
