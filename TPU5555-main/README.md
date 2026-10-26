# TPU5555-main

Sources and implementation data of TPU5555.

The **RTL top is `hdc_chip_top`** (`rtl/asic/hdc_chip_top.vhdl`). All layout and netlist views were
renamed to `TPU5555` after signoff.

| Directory | Content |
| --- | --- |
| `rtl/` | VHDL-2008 core: `hdc_word40_top` (SPI → command loader → `Accelerator`) and its memories (FPGA/behavioral architecture). `hdc_word40_core_top` is a measurement top only. |
| `rtl/asic/` | ASIC versions of the memories (same entity names; they map onto IHP SRAM macros), the pad-ring top `hdc_chip_top`, and `pad_keep.v` |
| `constraints/sdc/` | `chip_top.sdc` (clk 20 ns; sclk/cs_n 100 ns, asynchronous) |
| `Flow/scripts/LibreLane/` | `config.yaml`, PDN, custom LVS/antenna/fill decks, CDLs, tech LEF with antenna margin, bondpad generator, macro/ECO-diode generator. `resolved_full-test-v7.json` is the fully resolved config of the signoff run. |
| `synthesis/netlist/` | Yosys netlist |
| `PlaceAndRoute/` | GDS, DEF, powered netlist, LIB/SDF per corner, SPEF |
| `testbenches/` | GHDL equivalence testbench: behavioral memories vs. SRAM-macro mapping of `Accelerator` |
| `verification/` | KLayout DRC/antenna/density/LVS logs, STA summary, signoff metrics |

Never compile `rtl/*Memory*.vhdl` and `rtl/asic/*Memory*.vhdl` into one library: the entity names are the same.

## Running the flow

```sh
cd Flow/scripts/LibreLane   # config.yaml paths are relative to this directory
librelane --manual-pdk --pdk-root <IHP-Open-PDK> --pdk ihp-sg13cmos5l --run-tag <tag> config.yaml
```

The flow is LibreLane's `Chip` flow with the VHDL substitutions (`Yosys.VHDLSynthesis`) and KLayout LVS.
A full run takes about 8 h, most of it fill, DRC and LVS. Some custom decks reference the PDK under
`/opt/IHP-Open-PDK`; adjust those paths to your install.

## Simulation

```sh
testbenches/run.sh            # GHDL; optional generic override, e.g. -gG_D=2000
```
