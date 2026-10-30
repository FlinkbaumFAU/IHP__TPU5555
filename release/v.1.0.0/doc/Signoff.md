# TPU5555 v.1.0.0 – Signoff report

All checks below were **re-run on the final release files**, not on an intermediate run output:

| File | SHA-256 |
| --- | --- |
| `release/v.1.0.0/gds/TPU5555.gds` | `1613674470a091f20336fc72455b644e9f031fe6895789b8a6e14feff32cf6b0` |
| `release/v.1.0.0/netlist/TPU5555.cdl` | `20becef2be7c4c99030b0148a122ba040c8f9f3dc07b229dd406e45d6938165f` |

Environment: KLayout 0.30.7, IHP-Open-PDK `3f66c9137d520b3b5a3e39a2364afd6f9e2d7fee` (SG13CMOS5L decks), run on 2026-10-30.
Script: `TPU5555-main/Flow/scripts/release/signoff_release.sh`.
Logs and result databases: `TPU5555-main/verification/{drc,lvs}/release/`, with `versions.txt` recording the tool version, the PDK commit and the input hashes.

## Results on the release files

| Check | Deck / options | Rules evaluated | Result | Files (`verification/…`) |
| --- | --- | --- | --- | --- |
| DRC | `ihp-sg13cmos5l.drc`, `no_recommended=true`, deep | 328 categories | **0 markers** | `drc/release/drc.klayout.lyrdb`, `klayout-drc.log` |
| DRC precheck | `ihp-sg13cmos5l.drc`, **`precheck_drc=true`**, `no_recommended=true`, deep | 259 categories | **0 markers** | `drc/release/drc_precheck.klayout.lyrdb`, `klayout-drc-precheck.log` (line 16: `PreCheck DRC enabled: true`) |
| Density | `rule_decks/density.drc` | 5 categories | **0 markers** | `drc/release/density.klayout.lyrdb` |
| Antenna | `antenna_cmos5l_pr990.drc` (PDK deck with PR #990 ported to the 5-metal stack) | 23 categories | **0 markers** | `drc/release/antenna.klayout.lyrdb` |
| LVS | `sg13cmos5l_chip.lvs` (PDK deck + `hard_ip.rb`, scope below) | – | **Netlists match** | `lvs/release/klayout-lvs.log` (line 448), `lvs.klayout.lvsdb.xz`, `TPU5555_extracted.cir` |

The LVS schematic is the concatenation of `TPU5555.cdl`, the PDK stdcell CDL, `sram.cdl`, `bondpad_70x70.cdl` and `sg13cmos5l_io.cdl`, in the same order as in LibreLane's `KLayout.LVS` step.

The original flow run `full-test-v7` (2026-10-16) also reported DRC, antenna, density and LVS clean on the pre-rename GDS. Its logs and databases are kept in `verification/*/full-test-v7/` for reference. **That run had precheck disabled.** The precheck result above comes from the re-run.

## LVS scope and waivers

The full-chip LVS compares all standard-cell logic, top-level routing, power nets and every connection to the hard IP at device level. The hard IP (IHP IO cells and IHP SRAM macros) is compared as **black boxes**, as follows:

1. **Why:** in the SG13CMOS5L LVS deck, the PDK's own CDL netlists of these cells don't match their PDK layouts. Affected are IO diodes and clamps, `LevelDown`, and the SRAM-internal `RSC_IHPSG13_CDLYX1_DUMMY`. A transistor-level comparison inside them would fail regardless of this design.
2. **Pads and SRAM macros** (`sg13cmos5l_IOPad*`, `RM_IHPSG13_1P_*`): blanked in both netlists. Their pins and all chip-level nets connected to them are still compared.
3. **IO fillers / corner cells:** flattened without their substrate taps, so that the IO-ring rails still join the pads at top level. They contain no schematic devices.
4. **Pad pin reconciliation, by name:**
   - Layout pins without a name (substrate) or without a schematic counterpart are removed.
   - Duplicate layout pins are merged only if every instance already connects them to the same net. Otherwise the script raises an error.
   - Schematic power pins with no layout counterpart are removed. In this run that was 4 pins: `IOPADVDD.IOVDD`, `IOPADVSS.VDD`, `IOPADIOVSS.VDD`, `IOPADIOVDD.VDD`, which are rails without devices in those pads (log lines 441–444).
5. **`sg13cmos5l_RCClampResistor`:** blanked before simplification. It is inside the pads, and KLayout's `Netlist#simplify` crashes on its rppd terminals.
6. **Comparison mode:** strict port mode with `flag_missing_ports`. Missing or mislabeled top-level ports count as errors.

**Waiver:** this LVS does not verify the internals of the IO cells and SRAM macros. Instead, the hard-IP cells in the release GDS were compared against the foundry-qualified IHP-Open-PDK GDS (`libs.ref/sg13cmos5l_io`, `libs.ref/sg13cmos5l_sram`, commit `3f66c91`). Scripts: `TPU5555-main/Flow/scripts/release/compare_hard_ip.py`, `compare_macro_flat.py`. Recorded output: `TPU5555-main/verification/lvs/release/hard_ip_vs_pdk.txt`.

- **Identical cell by cell to the PDK:** all 11 IO cells used (pads, fillers, corner) and the SRAM macros 1024x16, 1024x8 and 256x48. That covers every sub-cell, layer, text and instance.
- **`RM_IHPSG13_1P_1024x32_c2_bm_bist`:** geometrically identical to the PDK. A hierarchical XOR over all layers shows 0 differing polygons and identical texts, including the 399 156 device labels on 63/0. Its sub-cell hierarchy differs only in naming. The SRAM GDS files share bitcell names (`RM_IHPSG13_1P_BITKIT_*`) but reference differently named via cells, and when the macros are merged into one layout, one version of each shared cell is kept. The resulting geometry is unchanged.

So the hard IP in the release is exactly the PDK's. Its internal correctness rests on the foundry's qualification of those cells.

The check is not a no-op: a deliberately disconnected SRAM `A_DIN` pin is reported as a mismatch (tested during flow development).

## Timing (OpenROAD STA, flow run `full-test-v7`, post-route with extracted SPEF)

| Corner | Setup WNS | Hold WNS | Max slew | Max cap | Max fanout |
| --- | --- | --- | --- | --- | --- |
| nom_slow_1p08V_125C | +2.30 ns | +0.78 ns | 0 | 0 | 216 |
| nom_typ_1p20V_25C | +8.79 ns | +0.40 ns | 0 | 0 | 216 |
| nom_fast_1p32V_m40C | +12.56 ns | +0.18 ns | 0 | 0 | 216 |

**Max-fanout waiver:** all 216 entries are clock-tree buffers inserted by CTS, identical in every corner. That's 215 `clkbuf_leaf_*_clk_regs` leaf buffers and the root buffer `clkbuf_0_i_core.sclk_i`. Each drives 10–16 flip-flops against a fanout limit of 8 (`verification/sta/full-test-v7/checks_*.rpt`). This is CTS sink clustering by design.

Fanout is only a proxy. The electrical limits behind it are clean:
- There are 0 max-slew and 0 max-cap violations in all corners.
- Setup and hold slack are positive with extracted parasitics.

The layout is unchanged by the rename and label fix (see provenance), so these timing results apply to the release.

## Provenance of the release GDS

`TPU5555.gds` is built from the final GDS of LibreLane run `full-test-v7`. That GDS has SHA-256 `2c43322d32690378d762050ea7387870b405b2f0b68ab606696f0707d764a7d9` and is identical to the output of its `KLayout.Filler` step, which runs after `KLayout.SealRing`.

1. `TPU5555-main/Flow/scripts/release/make_release.py` makes two edits:
   - It renames the top cell `hdc_chip_top` → `TPU5555`.
   - It corrects the sealring PCell's registration label (layer 63/0) from "Calculated area: 4.8e-06 sq mm" to "4.8 sq mm".

   It then writes the file without PCell/context info and with zero-length paths eliminated.
2. `TPU5555-main/Flow/scripts/release/check_release.py` compares the result against the input with `pya.LayoutDiff` (top cell mapped back). The recorded output:

   ```
   orig top: ['hdc_chip_top'] | new top: ['TPU5555']
   new bbox (um): (0,0;2400,2000) | dbu: 0.001
   LayoutDiff identical: False
   cells: 260 260
   differences: 2
      ('only in orig', 'sealring', '63/0', 'Device registration size: x=2400.0 um ; y=2000.0 um\nCalculated area: 4.8e-06 sq mm')
      ('only in new', 'sealring', '63/0', 'Device registration size: x=2400.0 um ; y=2000.0 um\nCalculated area: 4.8 sq mm')
   zero-area shapes (all layers): 0
   ```

3. All physical checks were then re-run on the resulting file itself (see above), so the release is verified directly. The provenance chain is documentation, not the basis of the signoff.

The release netlists are the flow's `write_cdl` and powered Verilog outputs. The only change is the top subcircuit/module name, `hdc_chip_top` → `TPU5555`.

## Seal ring

The seal ring is the PDK `sealring` PCell, instantiated at (0, 0) in `TPU5555`. Its bbox is (0, 0)–(2400, 2000) µm, giving an area of 4.8 mm². `doc/info.json` records `sealring_x` = 2400.0 and `sealring_y` = 2000.0 in µm.

## Not covered

- No post-synthesis or post-layout gate-level simulation. The supplied testbench (`TPU5555-main/testbenches/`) checks the behavioral memory models against the SRAM-macro mapping of the `Accelerator`, not the full chip interface. The TRL is therefore declared as 4.
- No silicon measurements yet.
