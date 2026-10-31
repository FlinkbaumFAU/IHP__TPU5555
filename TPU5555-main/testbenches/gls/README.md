# Post-layout (gate-level) simulation

This simulation runs the complete routed chip netlist `TPU5555` through the HDC classifier flow, driven only through its SPI pads. The netlist (`../../synthesis/netlist/TPU5555.nl.v`) is the one written after routing, so it includes the clock trees, hold buffers and ECO diodes. The simulation covers the IO pads, the SPI front end with its clock-domain crossings, the command loader, the accelerator and the SRAM macros.

## Result

All 4347 training and 1088 test samples of `data/TestData/P01_Noshy` (EMG data, 5 classes):

| Model | Protocol trace | Predictions | Accuracy | Runtime |
| --- | --- | --- | --- | --- |
| RTL reference | – | – | 1039/1088 (95.5 %) | 1.8 min |
| Gate level, power-up seed 1 | identical to RTL | identical to RTL (1088/1088) | 1039/1088 | 68 min |
| Gate level, power-up seed 2 | identical to RTL | identical to RTL (1088/1088) | 1039/1088 | 67 min |
| Gate level, power-up seed 3 | identical to RTL | identical to RTL (1088/1088) | 1039/1088 | 64 min |

- **Protocol trace:** every SPI command, acknowledgement and result byte with its simulation timestamp. The gate-level traces match the RTL trace line by line, timestamps included (`results/full_*.log.xz`).
- **Power-up seeds:** each gate-level run starts from different random contents of all flops and SRAMs (`+verilator+rand+reset+2 +verilator+seed+N`). The identical results show that the chip doesn't depend on its undefined power-up state, given the dummy finalize after reset (see below).

Results: `results/full_result.txt`, prediction files `results/pred_*.txt` (one `sample label prediction` line per test sample), and the short-case traces `results/short_trace_*.log`.

Environment: Verilator 5.044, GCC 14.2, IHP-Open-PDK `3f66c91`, on cae02 (2026-10-30). Each run is single-threaded. A model built with `--threads 8` was about 4× slower on this netlist.

## Files

| File | Purpose |
| --- | --- |
| `tb_hdc_word40_gate.v` | SPI-level testbench by the HDC developer, with small additions (below) |
| `chip_wrapper.v` | Maps the testbench's `hdc_word40_top` ports onto the `TPU5555` pads; stub for the bondpad cell |
| `functional_stdcells.py` | Generates a functional copy of the PDK standard-cell models (below) |
| `build.sh` | Builds the Verilator models `gate` (netlist) and `rtl` (reference) |
| `data/` | Item and level vectors (`position-vectors.txt`, `value_vectors.txt`). The EMG training and test recordings are **not published** in this repository; see below |

## Running

The EMG recordings (`training_emg.csv`, `training_labels.csv`, `testing_emg.csv`, `testing_labels.csv`) are not part of this repository. Obtain them from the HDC developers and place them in `data/TestData/P01_Noshy/` (the path the testbench expects). The vector files are included.

```sh
./build.sh rtl                      # needs yosys with the ghdl plugin
PDK_ROOT=<IHP-Open-PDK> ./build.sh gate
cd <run dir>
<gls>/build/gate/Vtb_hdc_word40_gate +TRAIN_PER_CLASS=0 +TEST_PER_CLASS=0 \
    +verilator+rand+reset+2 +verilator+seed+1 +PRED_FILE=pred_gate.txt
```

- `+TRAIN_PER_CLASS=n` / `+TEST_PER_CLASS=n` limit the samples per class (0 = all; default 1, about 1 min at gate level).
- `EXTRA_VFLAGS` adds options at build time:
  - `+define+TRACE`: protocol trace.
  - `+define+PROGRESS`: a marker every 100 µs of simulated time.
  - `--trace +define+VCD=<ns>`: waveform of the first `<ns>` nanoseconds.

## Changes to the testbench

The original testbench behavior is the default. The additions:
- The data location (`DATA_DIR`) is configurable.
- Sample counts and the prediction file can be set at runtime.
- `TRACE`, `PROGRESS` and `VCD` are optional build defines.
- A **dummy finalize** runs after reset, as the datasheet requires, because the SRAM class counters are undefined at power-up. `+define+NO_DUMMY_FINALIZE` turns it off.

## Simulation model fixes

The IHP PDK Verilog models aren't usable as-is in a simulator that ignores `specify` blocks:

1. **Flops and latches are never clocked.** Their UDPs are fed by `delayed_CLK`, `delayed_D`, … These wires are only driven by the `$setuphold`/`$recrem` timing checks. `functional_stdcells.py` ties each `delayed_X` to `X`.
2. **SRAMs have the same issue** in the default branch of their wrappers (`*_DELAY` wires). The wrappers' own `FUNCTIONAL` view is used instead (`+define+FUNCTIONAL`).
3. **Zero-delay race between flops.** The flop UDP updates its output immediately. On one clock edge, a flop could then change before another flop on a different clock-tree leaf had sampled it. The first observed symptom: the SPI reply byte was lost between `tx_req_seen_spi` and `tx_shadow_byte`. The only flop type in the netlist, `sg13cmos5l_dfrbpq_1` (3001 instances), is therefore modeled behaviorally with nonblocking assignments, using the UDP's function (`RESET_B = 0` → `Q = 0`; rising `CLK` → `Q = D`).
4. **Reset already active at time 0.** In a 2-state simulator this produces no edge. Example: the SPI front end is reset while `cs_n` is high, i.e. from start-up. The flop model applies such a reset once at start-up.

A unit-delay variant (clock-to-Q delay on all flops) was also tried. It was about 65× slower in Verilator, so it was dropped in favor of the nonblocking model. It also did not respond on SPI, but it predates fix 4, which probably explains that.

The SG13CMOS5L SRAM wrappers reference a core model that this PDK version doesn't ship. The identical-family SG13G2 core model is used instead.

## Scope

This is a **functional, zero-delay** simulation of the post-layout netlist: Verilator ignores the cell timing. Timing is covered by static timing analysis (setup and hold met in all corners, see `release/v.1.0.0/doc/Signoff.md`). The testbench includes `$sdf_annotate` support (`SDF_FILE`) for an event-driven simulator, but no SDF-annotated run has been done.
