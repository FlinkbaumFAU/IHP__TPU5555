# TPU5555 v.1.0.0

First tape-out release (2026-10-26).

## Deliverables

| Path | Content |
| --- | --- |
| `gds/TPU5555.gds` | Final layout. Top cell `TPU5555`, seal ring and metal/active fill included. Saved without PCell/context info and with zero-length paths eliminated. |
| `netlist/TPU5555.cdl` | LVS netlist of the top cell (OpenROAD `write_cdl`) |
| `netlist/sram.cdl`, `netlist/sg13cmos5l_io.cdl`, `netlist/bondpad_70x70.cdl` | Sub-circuits referenced by `TPU5555.cdl` (SRAM macros, IO cells without `IOPadInOut30mA`, bondpad) |
| `netlist/TPU5555.v` | Powered gate-level Verilog netlist |
| `doc/` | Datasheet, specification, signoff report (`Signoff.md`), layout render, flow-run metrics |

## Signoff

Every physical check was re-run on the final `gds/TPU5555.gds` and `netlist/TPU5555.cdl` themselves, using KLayout 0.30.7 and IHP-Open-PDK `3f66c91` on 2026-10-30:

- DRC: 0 markers
- DRC with `precheck_drc=true`: 0 markers
- Density: 0 markers
- Antenna: 0 markers
- LVS: netlists match, with the IO cells and SRAM macros compared as black boxes

Timing comes from LibreLane run `full-test-v7`: setup and hold are met in all corners.

`doc/Signoff.md` has the file hashes, the LVS scope and waivers, the max-fanout waiver, and the provenance of the release GDS.

## Changes after the review in issue #76 (2026-10-30)

- `gds/TPU5555.gds`: the sealring area label now reads "4.8 sq mm" instead of the PDK PCell's "4.8e-06 sq mm". Geometry is unchanged.
- `doc/info.json`: `sealring_x/y` are now given in µm (2400.0 / 2000.0).
- The repository now has a `LICENSE` (Apache-2.0) and a `NOTICE`.
- The precheck DRC was actually run. The earlier documentation claimed precheck coverage that the flow run did not have.
- The reproducible release scripts (`TPU5555-main/Flow/scripts/release/`) and the result databases (`TPU5555-main/verification/`) were added.

## Known limitations

- SRAM contents are undefined after power-up. Issue one dummy finalize before training (see the datasheet).
- `hv_length` is unused. D is fixed at 1000.
