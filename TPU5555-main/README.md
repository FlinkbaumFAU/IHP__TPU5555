# TPU5555-main

Sources and implementation data of TPU5555.

The **RTL top is `hdc_chip_top`** (`rtl/asic/hdc_chip_top.vhdl`). All layout and netlist views were
renamed to `TPU5555` after signoff. The implementation views are those of v.2.0.0 (flow run `mdll-v2`).

| Directory | Content |
| --- | --- |
| `rtl/` | VHDL-2008 core: `hdc_word40_top` (SPI → command loader → `Accelerator`) and its memories (FPGA/behavioral architecture). `hdc_word40_core_top` is a measurement top only. |
| `rtl/asic/` | ASIC versions of the memories (same entity names; they map onto IHP SRAM macros), the pad-ring top `hdc_chip_top` (with the MDLL instance, its pads and the /4 divider), and `pad_keep.v` |
| `constraints/sdc/` | `chip_top.sdc` (clk 20 ns; sclk/cs_n 100 ns; mdll_ref 10 ns, mdll_out 1.25 ns; all asynchronous) |
| `Flow/scripts/release/` | Release GDS (`make_release.py`, `check_release.py`), renamed views (`rename_views.py`), signoff reruns (`signoff_release.sh`), hard-IP comparisons |
| `Flow/scripts/LibreLane/` | `config.yaml`, PDN, custom LVS/antenna/fill decks, CDLs, tech LEF with antenna margin, bondpad generator, macro/ECO-diode generator (`scripts/gen_macros_eco.py`), ECO hold-buffer generator (`scripts/gen_eco_buffers.py`), the packaged MDLL macro (`ip/mdll/`). `resolved_mdll-v2.json` / `resolved_full-test-v7.json` are the fully resolved configs of the v.2.0.0 / v.1.0.0 signoff runs. |
| `synthesis/netlist/` | Yosys netlist |
| `PlaceAndRoute/` | GDS, DEF, powered netlist, LIB/SDF per corner, SPEF |
| `testbenches/` | GHDL equivalence testbench: behavioral memories vs. SRAM-macro mapping of `Accelerator` |
| `testbenches/gls/` | Post-layout simulation of the routed netlist through SPI against the RTL (Verilator); see its README |
| `verification/` | KLayout DRC/antenna/density/LVS logs, STA reports, signoff metrics: `*/release_v.2.0.0/` and `*/mdll-v2/` (v.2.0.0), `*/release/` and `*/full-test-v7/` (v.1.0.0), `mdll/` (the MDLL macro on its own) |
| `mdll/` | Sources of the MDLL macro (schematics, RTL, flow, simulations) and of its custom cells; see its README |

Never compile `rtl/*Memory*.vhdl` and `rtl/asic/*Memory*.vhdl` into one library: the entity names are the same.

## Running the flow

```sh
cd Flow/scripts/LibreLane   # config.yaml paths are relative to this directory
librelane --manual-pdk --pdk-root <IHP-Open-PDK> --pdk ihp-sg13cmos5l --run-tag <tag> config.yaml
```

The flow is LibreLane's `Chip` flow with the VHDL substitutions (`Yosys.VHDLSynthesis`) and KLayout LVS.
A full run takes about 8 h, most of it fill, DRC and LVS. Some custom decks reference the PDK under
`/opt/IHP-Open-PDK`; adjust those paths to your install.

Two sections of `config.yaml` are generated from the run's own synthesized netlist, because
they name Yosys instances or depend on the macro placement. After any change that touches
synthesis, synthesize first, update them, then run the full flow:

```sh
librelane ... --run-tag <tag>-synth --to Yosys.VHDLSynthesis config.yaml
N=runs/<tag>-synth/01-yosys-vhdlsynthesis/hdc_chip_top.nl.v
PDK_ROOT=<IHP-Open-PDK> python3 scripts/gen_macros_eco.py $N --update config.yaml   # MACROS, INSERT_ECO_DIODES
python3 scripts/gen_eco_buffers.py $N --update config.yaml                         # INSERT_ECO_BUFFERS
```

`--check` instead of `--update` only verifies that `config.yaml` matches the netlist.

## Simulation

```sh
testbenches/run.sh            # GHDL; optional generic override, e.g. -gG_D=2000
```
