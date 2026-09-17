`default_nettype none
`timescale 1ns / 1ps

/*
 * Tiny Tapeout Top-Level Testbench Wrapper
 * ----------------------------------------
 * Instantiates the top module `tt_um_nuatlabs_fifo_pwm` and routes
 * the 8-bit Tiny Tapeout standard pin interface to testbench registers
 * and wires driven directly by the Cocotb testbench environment (`test.py`).
 *
 * Waveform Output:
 * - Generates `tb.fst` for efficient signal inspection with GTKWave or Surfer.
 */
module tb ();

  // Configure waveform dumping (Fast Signal Trace - FST format)
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_nuatlabs_fifo_pwm user_project (
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
