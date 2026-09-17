/*
 * Copyright (c) 2026 NUAT Labs
 * SPDX-License-Identifier: Apache-2.0
 *
 * async_fifo_cdc
 * ---------------
 * Dual-clock asynchronous FIFO with Gray-coded read/write pointers and
 * 2-stage flip-flop synchronizers across the clock-domain crossing (CDC),
 * based on the classic Cummings methodology.
 *
 * Architectural Principles:
 * 1. Dual Independent Clocks:
 *    - Write domain runs on `wr_clk` (data ingestion).
 *    - Read domain runs on `rd_clk` (data consumption).
 *    - Both clocks can have arbitrary, unrelated frequencies, phases, or jitters.
 *
 * 2. Gray-Code Pointers & Metastability Protection:
 *    - Pointers are maintained as (ADDR_W + 1) bits (one extra MSB to distinguish
 *      between empty and full wrap-arounds).
 *    - Pointers are converted to Gray code before crossing into the opposing
 *      clock domain. Because Gray code ensures only a single bit toggles per
 *      increment, multi-bit sampling skew is eliminated.
 *    - A 2-stage DFF synchronizer on each side resolves any single-bit
 *      metastability before the pointer is sampled by full/empty comparison logic.
 *
 * 3. Full / Empty Generation:
 *    - Empty flag is evaluated in the READ domain:
 *        empty = (rd_ptr_gray == wr_ptr_gray_sync2)
 *    - Full flag is evaluated in the WRITE domain:
 *        full = (wr_ptr_gray == {~rd_ptr_gray_sync2[MSB:MSB-1], rd_ptr_gray_sync2[MSB-2:0]})
 *        (MSB and MSB-1 inverted, lower bits identical)
 *
 * 4. Write-Domain Occupancy Display:
 *    - `occupancy_wr`: Calculated in the write domain by decoding the synchronized
 *      read pointer back into binary and computing `wr_ptr_bin - rd_ptr_bin_sync_wr`.
 *    - This gives a safe, monotonic occupancy metric (0..DEPTH) for the 7-segment display.
 */
`default_nettype none

module async_fifo_cdc #(
    parameter WIDTH  = 4,                 // Data bus width per word
    parameter ADDR_W = 3                  // Address width (DEPTH = 2**ADDR_W = 8 entries)
) (
    // Write domain ports
    input  wire             wr_clk,       // Write domain clock
    input  wire             wr_rst_n,     // Write domain active-low async reset
    input  wire             wr_en,        // Write enable (active-high)
    input  wire [WIDTH-1:0] wr_data,      // Write data payload
    output wire             full,         // Full flag (asserted in write domain)
    output wire [ADDR_W:0]  occupancy_wr, // Current FIFO occupancy in write domain (0..DEPTH)

    // Read domain ports
    input  wire             rd_clk,       // Read domain clock
    input  wire             rd_rst_n,     // Read domain active-low async reset
    input  wire             rd_en,        // Read enable (active-high)
    output reg  [WIDTH-1:0] rd_data,      // Read data payload (registered output)
    output wire             empty         // Empty flag (asserted in read domain)
);

  localparam DEPTH = (1 << ADDR_W);

  // ---------------------------------------------------------------
  // Storage Memory (inferred dual-port RAM)
  // ---------------------------------------------------------------
  // Port A: written synchronously by wr_clk
  // Port B: read synchronously into rd_data by rd_clk
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
