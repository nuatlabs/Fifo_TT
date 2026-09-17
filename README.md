![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# NUAT Labs — Asynchronous FIFO with CDC & PWM Peripheral

A silicon-proven mixed digital design targeting the **Tiny Tapeout IHP 26b (TTIHP26b)** shuttle on the **IHP 130nm BiCMOS (`ihp-sg13g2`)** open-source process.

Designed and verified by **NUAT Labs**.

- **Datasheet & Pinout Documentation:** [docs/info.md](docs/info.md)
- **Target Shuttle:** TTIHP26b (IHP 130nm SG13G2)
- **Footprint:** Single Tile (1x1: ~167 µm × 108 µm)
- **Top Module:** `tt_um_nuatlabs_fifo_pwm`

---

## Architecture Overview

This design integrates two functional blocks within a single Tiny Tapeout tile:

```
                  +------------------------------------------------------+
                  |                   tt_um_fifo_pwm             |
                  |                                                      |
                  |  +------------------------------------------------+  |
[clk] ----------->|->| wr_clk                                         |  |
[rst_n] --------->|->| wr_rst_n                                       |  |
[ui_in[0]:wr_en]->|->| wr_en             8x4 Async FIFO               |  |
[uio_in[3:0]] --->|->| wr_data               (CDC)                    |  |
                  |  |                                                |  |
[ui_in[4]:sel] -->|->| rd_clk_mux ---> rd_clk                         |  |
[ui_in[7]:ext] -->|->|                rd_rst_n                        |  |
[ui_in[1]:rd_en]->|->|                rd_en                           |  |
                  |  |                                rd_data [3:0]   |--|--> [uio_out[7:4]]
                  |  | occupancy_wr [3:0]                             |  |
                  |  +--------|---------------------------------------+  |
                  |           v                                          |
                  |  +-----------------+                                 |
                  |  | 7-Seg Decoder   |                                 |
                  |  +--------|--------+                                 |
                  |           +----------------------------------------->|--> [uo_out[6:0]: 7-Seg]
                  |                                                      |
                  |  +------------------------------------------------+  |
                  |  |                   PWM Generator                |  |
[ui_in[2]:load] ->|->| duty_load                                      |  |
[ui_in[3]:en] --->|->| enable                                 pwm_out |--|--> [uo_out[7]: PWM]
                  |  +------------------------------------------------+  |
                  +------------------------------------------------------+
```

### 1. Dual-Clock Asynchronous FIFO with Gray-Code CDC
- **Capacity:** 8 entries deep, 4-bit data width (`WIDTH=4`, `ADDR_W=3`).
- **Clock Domain Crossing (CDC):** Uses dual-rank flip-flop synchronizers on Gray-coded read and write pointers to eliminate metastability across clock boundaries (Cummings architecture).
- **Safe Write-Domain Occupancy:** Decodes the synchronized Gray read pointer back to binary within the write clock domain, calculating live occupancy (`0` to `8`) free of race conditions.
- **Occupancy Display:** Drives an active-high 7-segment display on `uo_out[6:0]` displaying real-time FIFO fullness (`0`–`8`).
- **Flexible Clocking:**
  - **Standalone / Devkit mode (`ui_in[4] = 1`):** Routes the primary `clk` to both write and read domains for instant out-of-the-box evaluation on the standard Tiny Tapeout carrier board.
  - **True Dual-Clock CDC mode (`ui_in[4] = 0`):** Read domain clocked independently via `ui_in[7]` (`ext_rd_clk`), allowing evaluation with independent oscillators or signal generators.

### 2. Programmable PWM Generator
- **Resolution:** 4-bit programmable duty cycle (16 discrete power levels: 0/16 up to 15/16).
- **Timebase:** 8-bit free-running accumulator counter running on primary `clk`.
- **Interface:** Controlled via `duty_load` pulse (`ui_in[2]`) capturing the nibble on `uio_in[3:0]`. Output is gated by `ui_in[3]` (`pwm_enable`) and emitted on `uo_out[7]`.
- **Modularity:** Standalone RTL designed for drop-in reuse as an SoC memory-mapped peripheral.

---

## Pinout Configuration

### Dedicated Inputs (`ui_in`)
| Pin | Signal | Description |
|:---|:---|:---|
| `ui_in[0]` | `fifo_wr_en` | FIFO write enable (synchronous to `clk`, active high) |
| `ui_in[1]` | `fifo_rd_en` | FIFO read enable (synchronous to selected read clock, active high) |
| `ui_in[2]` | `pwm_duty_load` | PWM duty register strobe (captures `uio_in[3:0]` on posedge `clk`) |
| `ui_in[3]` | `pwm_enable` | PWM output enable (active high) |
| `ui_in[4]` | `fifo_rd_clk_sel` | Read clock select: `1` = internal `clk`, `0` = external `ui_in[7]` |
| `ui_in[5]` | *Reserved* | Unused input |
| `ui_in[6]` | *Reserved* | Unused input |
| `ui_in[7]` | `ext_rd_clk` | External asynchronous read clock input (when `ui_in[4] = 0`) |

### Dedicated Outputs (`uo_out`)
| Pin | Signal | Description |
|:---|:---|:---|
| `uo_out[0]` | `SEG_A` | 7-segment display segment A (active high) |
| `uo_out[1]` | `SEG_B` | 7-segment display segment B (active high) |
| `uo_out[2]` | `SEG_C` | 7-segment display segment C (active high) |
| `uo_out[3]` | `SEG_D` | 7-segment display segment D (active high) |
| `uo_out[4]` | `SEG_E` | 7-segment display segment E (active high) |
| `uo_out[5]` | `SEG_F` | 7-segment display segment F (active high) |
| `uo_out[6]` | `SEG_G` | 7-segment display segment G (active high) |
| `uo_out[7]` | `pwm_out` | Modulated PWM output pulse train |

### Bidirectional IOs (`uio`)
| Pin | Direction | Signal | Description |
|:---|:---:|:---|:---|
| `uio[0]` | Input | `fifo_wr_data[0]` / `pwm_duty[0]` | Multiplexed write data bit 0 / PWM duty bit 0 |
| `uio[1]` | Input | `fifo_wr_data[1]` / `pwm_duty[1]` | Multiplexed write data bit 1 / PWM duty bit 1 |
| `uio[2]` | Input | `fifo_wr_data[2]` / `pwm_duty[2]` | Multiplexed write data bit 2 / PWM duty bit 2 |
| `uio[3]` | Input | `fifo_wr_data[3]` / `pwm_duty[3]` | Multiplexed write data bit 3 / PWM duty bit 3 |
| `uio[4]` | Output | `fifo_rd_data[0]` | FIFO read data bit 0 |
| `uio[5]` | Output | `fifo_rd_data[1]` | FIFO read data bit 1 |
| `uio[6]` | Output | `fifo_rd_data[2]` | FIFO read data bit 2 |
| `uio[7]` | Output | `fifo_rd_data[3]` | FIFO read data bit 3 |

*Direction configuration: `uio_oe = 8'b1111_0000` (upper nibble output, lower nibble input).*

---

## Verification & Simulation

The design includes a comprehensive [cocotb](https://www.cocotb.org/) testbench with 4 automated test suites covering both single-clock and dual-clock asynchronous corner cases:

1. **`test_fifo_sync_mode`**: Verifies push/pop operations, pointer increments, and live 7-segment occupancy tracking in single-clock mode.
2. **`test_fifo_full_flag_via_occupancy`**: Fills the FIFO to full depth (8 items), asserts full blocking behavior, and verifies that excess writes are dropped without memory corruption.
3. **`test_fifo_true_async_cdc`**: Drives write and read domains with two distinct, asynchronous clock sources. Validates pointer synchronization latency and data integrity across the crossing.
4. **`test_pwm_duty_load`**: Programs duty registers and measures high/low ratio of the generated waveform across 256 cycles.

### Running Simulation Locally

Prerequisites:
- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog >= 12.0`)
- Python 3.10+ with `cocotb` and `pytest`

```bash
cd test
pip install -r requirements.txt
make SIM=icarus
```

---

## Tapeout Details

- **Foundry / Process:** IHP 130nm BiCMOS Open Source PDK (`ihp-sg13g2`)
- **Synthesis & PnR:** OpenLane / LibreLane ASIC flow
- **Design Rule Checking:** Zero DRC / LVS violations
- **Timing Closure:** Target clock period 20 ns (50 MHz) with clean setup and hold margins

---

## Repository Structure

```
.
├── .github/workflows/   # CI/CD: Verification, LibreLane GDS hardening, Precheck, Datasheet
├── docs/
│   └── info.md          # Tiny Tapeout project description & test guide
├── src/
│   ├── config.json      # LibreLane physical implementation configuration
│   ├── project.v        # Top-level module (tt_um_nuatlabs_fifo_pwm)
│   ├── async_fifo_cdc.v # Dual-clock asynchronous FIFO with Gray-code synchronizers
│   ├── seg7_decoder.v   # Occupancy to 7-segment pattern decoder
│   └── pwm_gen.v        # 4-bit programmable PWM generator
├── test/
│   ├── Makefile         # Cocotb simulation harness
│   ├── tb.v             # Verilog testbench wrapper
│   └── test.py          # Cocotb Python test verification suite
└── info.yaml            # Tiny Tapeout pinout metadata and shuttle manifest
```

---

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
