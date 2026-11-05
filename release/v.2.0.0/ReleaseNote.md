# TPU5555 v.2.0.0

Second tape-out release (2026-11-05): the HDC classifier of v.1.0.0, unchanged, plus an
all-digital multiplying delay-locked loop (MDLL) as a separate test structure with its own
13 pads.

## Deliverables

| Path | Content |
| --- | --- |
| `gds/TPU5555.gds` | Final layout. Top cell `TPU5555`, seal ring and metal/active fill included. Saved without PCell/context info and with zero-length paths eliminated. |
| `netlist/TPU5555.cdl` | LVS netlist of the top cell (OpenROAD `write_cdl`) |
| `netlist/sram.cdl`, `netlist/sg13cmos5l_io.cdl`, `netlist/bondpad_70x70.cdl` | Sub-circuits referenced by `TPU5555.cdl` (SRAM macros, IO cells without `IOPadInOut30mA`, bondpad) |
| `netlist/mdll_bb.cdl` | The MDLL macro's pins, as compared in the chip LVS (black box) |
| `netlist/mdll_full.cdl` | The MDLL macro's complete netlist (reference of its Calibre LVS) |
| `netlist/TPU5555.v` | Powered gate-level Verilog netlist |
| `doc/` | Datasheet, specification, signoff report (`Signoff.md`), layout render, flow-run metrics |

## Changes against v.1.0.0

- **MDLL** (instance `i_mdll`, hard macro `mdll`, 257.8 × 294.8 µm in the top-right corner
  of the core). It multiplies the clock on `pad_mdll_clk_ref` by 4.
  - **New pads:** `pad_mdll_clk_ref`, `pad_mdll_resetb` (inputs), `pad_mdll_code[7:0]` and
    `pad_mdll_locked` (4 mA), `pad_mdll_clk` = output / 4 (16 mA), `pad_mdll_clk_raw` =
    output (30 mA). 35 pads in total.
  - **Sources:** `TPU5555-main/mdll/`; its own verification in
    `TPU5555-main/verification/mdll/`.
- **Pad ring:** the MDLL pads sit at the top of the east side and the right of the north
  side. `pad_led` moved to the bottom of the east side; `pad_spare[3]` and `pad_spare[4]`
  moved to the south side.
- **Classifier hold fix:** ECO hold buffers now cover all 32 bits of the SPI shift and
  receive registers (v.1.0.0: the 31 that violated in an earlier run). The list is
  generated from the synthesized netlist by register name
  (`Flow/scripts/LibreLane/scripts/gen_eco_buffers.py`).
- **Flow and release scripts:**
  - LVS script `lvs/hard_ip.rb`: the MDLL is compared as a black box, and a call to the
    nonexistent `Netlist#remove_circuit` is fixed.
  - New `rename_views.py`.
  - `signoff_release.sh` now takes its paths from the environment.

The classifier logic (RTL core) is unchanged; the layout was re-implemented around the MDLL.

## Signoff

Every physical check was re-run on the final `gds/TPU5555.gds` and `netlist/TPU5555.cdl`
themselves, using KLayout 0.30.7 and IHP-Open-PDK `3f66c91` on 2026-11-05:

- DRC: 0 markers
- DRC with `precheck_drc=true`: 0 markers
- Density: 0 markers
- Antenna: 0 markers
- LVS: netlists match, with the IO cells, SRAM macros and the MDLL compared as black boxes
- The IO cells and SRAMs in the GDS are identical to the PDK's. The MDLL cell is
  geometrically identical to its packaged macro, which passed its own DRC, LVS and Calibre
  LVS.

Timing comes from LibreLane run `mdll-v2`: setup and hold are met in all corners. Worst
slack: setup +0.17 ns, hold +0.10 ns, both on the MDLL's /4 divider. The classifier clock
has setup +3.13 ns and hold +0.43 ns.

Post-layout simulation of the routed netlist through SPI (zero delay, full EMG data set,
three random power-up states, MDLL as a stub): the protocol trace and all 1088 test
predictions are identical to the RTL, with 1039/1088 correct. See
`TPU5555-main/testbenches/gls/README.md`.

`doc/Signoff.md` has:
- the file hashes;
- the LVS scope and waivers (IO cells, SRAMs, MDLL) and the max-fanout waiver;
- the provenance of the release GDS.

## Known limitations

- SRAM contents are undefined after power-up. Issue one dummy finalize before training
  (see the datasheet).
- `hv_length` is unused. D is fixed at 1000.
- **MDLL lock range at the slow corner (ss, 1.08 V, 125 °C):** closed-loop simulation of the
  extracted MDLL locks at 112.7 MHz and fails from 123.3 MHz. At 100 MHz every corner locks;
  tt and ff lock from 123.3 to 150 MHz. The runs below 123 MHz were not all finished at
  release time.
- **Chip metal fill inside the MDLL area.** It is not in the MDLL's RC extraction, so the
  ring on silicon is slightly slower than simulated, and the ss limit drops further.
- **East bondpad pitch:** about 96 µm (14 pads).
