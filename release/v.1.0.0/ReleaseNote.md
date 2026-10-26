# TPU5555 v.1.0.0

First tape-out release (2026-10-26).

## Deliverables

| Path | Content |
| --- | --- |
| `gds/TPU5555.gds` | Final layout. Top cell `TPU5555`, seal ring and metal/active fill included. Saved without PCell/context info and with zero-length paths eliminated. |
| `netlist/TPU5555.cdl` | LVS netlist of the top cell (OpenROAD `write_cdl`) |
| `netlist/sram.cdl`, `netlist/sg13cmos5l_io.cdl`, `netlist/bondpad_70x70.cdl` | Sub-circuits referenced by `TPU5555.cdl` (SRAM macros, IO cells without `IOPadInOut30mA`, bondpad) |
| `netlist/TPU5555.v` | Powered gate-level Verilog netlist |
| `doc/` | Datasheet, specification, layout render, signoff metrics |

## Signoff

The data comes from LibreLane run `full-test-v7` (2026-10-16), using IHP-Open-PDK `3f66c91`, process SG13CMOS5L.
It reports KLayout DRC 0, antenna 0, density 0, LVS clean, and setup/hold met in all corners.

After signoff, the top cell was renamed from `hdc_chip_top` to `TPU5555` and the file was re-saved with the
required KLayout options. KLayout `LayoutDiff` against the signed-off GDS reports the two as identical apart
from the name. The file has 0 zero-area polygons on the layers checked by IHP's `zero.py`.

## Known limitations

- SRAM contents are undefined after power-up. Issue one dummy finalize before training (see the datasheet).
- `hv_length` is unused. D is fixed at 1000.
