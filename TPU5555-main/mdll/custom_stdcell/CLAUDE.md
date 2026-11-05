# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A hand-crafted custom standard-cell library for the **IHP SG13G2 130nm open-source PDK**. There is no software application here — the "source" is IC layout (GDS), transistor-level netlists (SPICE/CDL), schematic symbols (xschem), and an abstract view (LEF) for place-and-route. Work consists of drawing/editing layout in Magic, capturing the intended netlist, and verifying the two match via DRC and LVS.

`PDK_ROOT` must be set (currently `/opt/IHP-Open-PDK`). The toolchain (Magic ≥ 8.3.617, KLayout ≥ 0.30, xschem) is expected on `PATH`.

## Cell families

Two families, all sharing the pin/power convention `VDD`/`VSS` power rails and living in the single `custom_stdcell.gds`:

- **`custom_einvn_*`** — tristate/enable inverters. Pins `Z A TE_B VDD VSS` (Z=output, A=input, TE_B=active-low tri-state enable). Sizes: `p5`, `1`, `16` (drive strength). Internally a 3-transistor-per-rail structure with an internal `TE` node derived from `TE_B`.
- **`custom_cap_*`** — switched capacitor / varactor-style cells. Pins `C A VDD VSS`. Sizes `p125 p25 p5 1 2 4 8 16` — the suffix is the *relative capacitance* (p125 = 0.125, p5 = 0.5, etc.). Larger cells scale device W; sub-unit cells (p125…p5) instead trade off with longer-L "resistor-like" devices. Each is tuned by hand so LVS matches the schematic while DRC stays clean.

Suffix notation throughout the repo: `p` = decimal point (`p125` → 0.125, `p5` → 0.5).

## The four views must stay consistent

A change to one cell usually means touching several files, all keyed by cell name (`custom_<family>_<size>`):

| View | File | Role |
|------|------|------|
| Layout | `custom_stdcell.gds` | Physical geometry (edit in Magic). Source of truth for LVS/DRC. |
| Netlist (sim) | `custom_stdcell.spice` | Transistor-level netlist, IHP model syntax (`sg13_lv_pmos`/`_nmos`, W/L/AS/AD/PS/PD). |
| Netlist (CDL) | `custom_stdcell.cdl` | Netlist for LVS comparison (`MN*/MP*` device lines). |
| Symbol | `xschem/custom_*.sym` | Schematic symbol; `format=`/`template=` lines define port order + the `custom_` prefix. |
| Abstract | `custom_stdcell.lef` | P&R view — **generated, do not hand-edit** (see below). |

Port order matters and has bitten this project before (see commit `Fix port order for spice file`). When adding a device or renaming a net, update the SPICE, CDL, and symbol together.

## Common commands

### Regenerate the LEF (after any layout/pin change)
```bash
python3 lef_out.py
```
`lef_out.py` checks the Magic version, runs `lef_out.tcl` under Magic (headless) to write per-cell LEF into a temp `lef_out/` dir, then concatenates them (one header + all `MACRO…END` blocks + `END LIBRARY`) into `custom_stdcell.lef` and cleans up. **To include a cell in the LEF you must add its name to the `set cells [list …]` line in `lef_out.tcl`** — it currently only lists a subset (`custom_cap_16`, `custom_einvn_16`, `custom_einvn_1`), so the generated LEF is intentionally not the full library.

### DRC (design-rule check) via the PDK's KLayout deck
```bash
python3 $PDK_ROOT/ihp-sg13g2/libs.tech/klayout/tech/drc/run_drc.py \
  --path custom_stdcell.gds --topcell <cell_name>
```
Runs `main` + `sg13g2_maximal` checks; results land in a `drc_run_*` dir (git-ignored). A clean run prints `✅ KLayout DRC Check Passed`.

### LVS (layout-vs-schematic)
```bash
python3 $PDK_ROOT/ihp-sg13g2/libs.tech/klayout/tech/lvs/run_lvs.py \
  --layout custom_stdcell.gds --topcell <cell_name>
```
Compares extracted layout against the netlist; output in a `lvs_run_*` dir (git-ignored). Look for `Status | PASS` / `netlists match` in the log. DRC and LVS are run **per top cell**, not for the whole library at once.

Consult the exact flag names with `run_drc.py --help` / `run_lvs.py --help` if a run fails — this PDK's CLI has changed across KLayout versions.

## Git conventions

`.gitignore` excludes all verification artifacts (`drc_*`, `lvs_run_*`, `*.cir`, `*.lyrdb`, `pex`). The committed run directories predate the ignore rules or were added deliberately as reference-passing runs — don't add new ones. Commits are scoped per cell / per milestone (e.g. "Refine cap cells", "Add p5 cap cell to gds"); the typical flow is: edit layout → pass DRC + LVS → update netlists/symbol → regenerate LEF → commit.
