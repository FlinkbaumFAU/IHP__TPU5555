# MDLL: sources of the hard macro `mdll`

TPU5555 v.2.0.0 contains an all-digital multiplying delay-locked loop (MDLL) as a separate
test structure: instance `i_mdll` of the hard macro `mdll`, with its own pads (see the
datasheet). The chip flow uses only its packaged views,
`Flow/scripts/LibreLane/ip/mdll/` (GDS, LEF, Liberty, CDL). This directory holds the
sources those views were built from.

| Directory | Source | Commit |
| --- | --- | --- |
| `mixed_signal_design_blocks/` | MDLL design: schematics, RTL, block and top-level LibreLane configs, flow scripts, SPICE testbenches and analysis scripts | `9b729dc` (snapshot; the macro was built from `a6808fa`, and the commits between change no layout input) |
| `custom_stdcell/` | Custom cells: switched unit capacitors `custom_cap_*` (LEF, Liberty, GDS, CDL, SPICE, xschem symbols) | `33fd5af` |

Both are plain copies (`git archive`), kept as siblings: the MDLL flow finds
`custom_stdcell` next to its own root. Start with `mixed_signal_design_blocks/CLAUDE.md`
(architecture, flow, traps) and `TAPEOUT.md` (verification history and results).

## Architecture in one paragraph

The MDLL is a gated ring oscillator. clk_gen runs four DCO periods from each `clk_ref` edge,
so at lock `clk_out` is 4 × `f_ref`. The DCO period is set by an 8-bit code through 63
thermometer-coded unit capacitors, with the two LSBs dithered over the four periods.
Acquisition works in two stages:
- **Coarse:** a Vernier TDC measures the residual `T_REF − 4·T_DCO` and lock_ctrl
  converts that reading into code jumps.
- **Fine:** after handover, a bang-bang phase detector with an 8-bit Gray-coded
  accumulator (bbpd) tracks.

lock_ctrl restarts acquisition when injections go missing or the code sits at a rail.

## Rebuilding the macro (SG13CMOS5L)

Tools: LibreLane 3.0.16, Yosys 0.69, OpenROAD 26Q2, KLayout 0.30.12, xschem 3.4.7, from a nix
profile. The SPICE checks additionally need ngspice-45 and Verilator 5.048. `PDK_ROOT` must
point to an IHP-Open-PDK checkout with `ihp-sg13cmos5l`.

```sh
cd mixed_signal_design_blocks
for b in clk_gen tdc bbpd lock_ctrl; do make -C $b harden_cmos5l; done
make macros_cmos5l harden_cmos5l match_report_cmos5l   # top level, replica matching
make ip_cmos5l                                         # -> build/sg13cmos5l/ip/mdll/
```

The hardening is reproducible. Built on two machines from a clean tree, with the same
tool store paths but different PDK checkouts (`3f66c91` and `6ac9bb9d`), every block and the
top level came out **geometrically identical** (KLayout XOR: 0 differing layers; see
`TAPEOUT.md`, "Reproduced on cae02"). After a tool update, build from clean
(`make clean`): the make rules don't track tool versions.

## Verification of the macro

Summarised in `../verification/mdll/` (copies of the logs). In `TAPEOUT.md`:
- **Layout checks:** LibreLane DRC/LVS/antenna/timing clean, and the full PDK DRC on the
  GDS is clean.
- **Calibre LVS** against the macro's CDL: CORRECT.
- **Replica matching** (`div` vs `clk_ref_g`): within 20 ps.
- **Closed-loop simulations** at transistor level, on the layout-extracted netlist and on
  Calibre RC netlists.
