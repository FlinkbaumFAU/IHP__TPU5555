# TPU5555 v.2.0.0 – Signoff report

v.2.0.0 is the HDC classifier of v.1.0.0 plus an all-digital MDLL test structure (hard macro
`mdll`) with 13 additional pads. All checks below were **re-run on the final release files**,
not on an intermediate run output:

| File | SHA-256 |
| --- | --- |
| `release/v.2.0.0/gds/TPU5555.gds` | `17299d3e874d71e983490d9eaee8304a1fcd9fa8bcd229816d300e5ce95b27fe` |
| `release/v.2.0.0/netlist/TPU5555.cdl` | `3f637a4863a6bc61ee669c9f5076f7cf06a8ae92b82399ff711227098f842b52` |

Environment: KLayout 0.30.7, IHP-Open-PDK `3f66c9137d520b3b5a3e39a2364afd6f9e2d7fee` (SG13CMOS5L decks), run on 2026-11-05.
The decks and CDLs came from the hdc flow repository at `f442cc4`, identical to
`TPU5555-main/Flow/scripts/LibreLane/`.
Script: `TPU5555-main/Flow/scripts/release/signoff_release.sh`, with
`EXTRA_CDLS=ip/mdll/cdl/mdll_bb.cdl`.
Logs and result databases: `TPU5555-main/verification/{drc,lvs}/release_v.2.0.0/`, with
`versions.txt` recording the tool version, the PDK and deck commits, and the input hashes.

## Results on the release files

| Check | Deck / options | Rules evaluated | Result | Files (`verification/…`) |
| --- | --- | --- | --- | --- |
| DRC | `ihp-sg13cmos5l.drc`, `no_recommended=true`, deep | 328 categories | **0 markers** | `drc/release_v.2.0.0/drc.klayout.lyrdb`, `klayout-drc.log` |
| DRC precheck | `ihp-sg13cmos5l.drc`, **`precheck_drc=true`**, `no_recommended=true`, deep | 259 categories | **0 markers** | `drc/release_v.2.0.0/drc_precheck.klayout.lyrdb`, `klayout-drc-precheck.log` (line 16: `PreCheck DRC enabled: true`) |
| Density | `rule_decks/density.drc` | 5 categories | **0 markers** | `drc/release_v.2.0.0/density.klayout.lyrdb` |
| Antenna | `antenna_cmos5l_pr990.drc` (PDK deck with PR #990 ported to the 5-metal stack) | 23 categories | **0 markers** | `drc/release_v.2.0.0/antenna.klayout.lyrdb` |
| LVS | `sg13cmos5l_chip.lvs` (PDK deck + `hard_ip.rb`, scope below) | – | **Netlists match** | `lvs/release_v.2.0.0/klayout-lvs.log` (line 448), `lvs.klayout.lvsdb.xz`, `TPU5555_extracted.cir` |

The LVS schematic is the concatenation of `TPU5555.cdl`, the PDK stdcell CDL, `sram.cdl`,
`bondpad_70x70.cdl`, `sg13cmos5l_io.cdl` and `mdll_bb.cdl`. The first five are in the same
order as in LibreLane's `KLayout.LVS` step; `mdll_bb.cdl` comes from the flow's
`EXTRA_CDLS`.

The flow run `mdll-v2` (2026-11-04) also reported DRC, antenna, density and LVS clean on
the pre-rename GDS. Its logs and databases are in `verification/*/mdll-v2/`. That run had
precheck disabled; the precheck result above comes from the re-run.

## LVS scope and waivers

The full-chip LVS compares all standard-cell logic, top-level routing, power nets and every
connection to the hard IP at device level. The hard IP (IHP IO cells, IHP SRAM macros and the
MDLL macro) is compared as **black boxes**, as in v.1.0.0:

1. **Why:**
   - **IO cells and SRAMs:** in the SG13CMOS5L LVS deck, the PDK's own CDL netlists of
     these cells don't match their PDK layouts. Affected are IO diodes and clamps,
     `LevelDown`, and the SRAM-internal `RSC_IHPSG13_CDLYX1_DUMMY`.
   - **The MDLL:** it is an own hard macro, verified on its own (below). Its schematic in
     the chip CDL is the pin-only `mdll_bb.cdl`.
2. **Pads, SRAM macros and the MDLL** (`sg13cmos5l_IOPad*`, `RM_IHPSG13_1P_*`, `mdll`):
   blanked in both netlists. Their pins and all chip-level nets connected to them are still
   compared.
3. **IO fillers / corner cells:** flattened without their substrate taps, so that the
   IO-ring rails still join the pads at top level. They contain no schematic devices.
4. **Pad pin reconciliation, by name**, as in v.1.0.0:
   - Layout pins without a name (substrate) or without a schematic counterpart are removed.
   - Duplicate layout pins are merged only if every instance already connects them to the
     same net. Otherwise the script raises an error.
   - Schematic power pins with no layout counterpart are removed.

   In this run that was 4 pins, the same as in v.1.0.0: `IOPADVDD.IOVDD`, `IOPADVSS.VDD`, `IOPADIOVSS.VDD`, `IOPADIOVDD.VDD`, which are rails without devices in those pads (log lines 441–444).
5. **Unreferenced circuits:** blanking leaves sub-circuits with no references. With the new
   pad types (`IOPadOut4mA`, `IOPadOut16mA`) that happens for the first time, and they are
   removed (`Netlist#remove`). v.1.0.0's `hard_ip.rb` called a nonexistent
   `remove_circuit` there; it was never reached, and is fixed.
6. **`sg13cmos5l_RCClampResistor`:** blanked before simplification. It is inside the pads,
   and KLayout's `Netlist#simplify` crashes on its rppd terminals.
7. **Comparison mode:** strict port mode with `flag_missing_ports`. Missing or mislabeled
   top-level ports count as errors.

**Waiver, IO cells and SRAMs:** the hard-IP cells in the release GDS were compared against
the foundry-qualified IHP-Open-PDK GDS (`libs.ref/sg13cmos5l_io`, `libs.ref/sg13cmos5l_sram`,
commit `3f66c91`). Scripts: `TPU5555-main/Flow/scripts/release/compare_hard_ip.py`,
`compare_macro_flat.py`. Recorded output:
`TPU5555-main/verification/lvs/release_v.2.0.0/hard_ip_vs_pdk.txt`.

- **Identical cell by cell to the PDK:** all 15 IO cells used (pads, among them the new
  `IOPadOut4mA` and `IOPadOut16mA`, fillers, corner) and the SRAM macros 1024x16, 1024x8
  and 256x48. That covers every sub-cell, layer, text and instance.
- **`RM_IHPSG13_1P_1024x32_c2_bm_bist`:** geometrically identical to the PDK on all 27
  layers, including the device labels. As in v.1.0.0, only the names of the via cells
  inside its shared bitcell sub-cells differ.

**Waiver, MDLL:** the MDLL's insides are verified at macro level. The results are copied in
`TPU5555-main/verification/mdll/` (README there):
- **Its own sign-off:** LibreLane KLayout DRC, LVS and antenna clean; the full PDK DRC
  clean; Calibre LVS of its GDS against its complete netlist (`netlist/mdll_full.cdl`)
  CORRECT.
- **The macro in this chip:** the `mdll` cell of the release GDS is **geometrically
  identical** to the packaged macro `Flow/scripts/LibreLane/ip/mdll/gds/mdll.gds` (flat XOR
  of all 23 layers with `compare_macro_flat.py`, recorded in `hard_ip_vs_pdk.txt`). So the
  verified macro is exactly what is in the chip. The chip's metal fill is in the top cell,
  not in the `mdll` cell (see "Known limitations").

## Timing (OpenROAD STA, flow run `mdll-v2`, post-route with extracted SPEF)

| Corner | Setup WNS | Hold WNS | Max slew | Max cap | Max fanout |
| --- | --- | --- | --- | --- | --- |
| nom_slow_1p08V_125C | +0.17 ns | +0.32 ns | 0 | 0 | 211 |
| nom_typ_1p20V_25C | +0.48 ns | +0.18 ns | 0 | 0 | 211 |
| nom_fast_1p32V_m40C | +0.66 ns | +0.10 ns | 0 | 0 | 211 |

The worst paths in every corner belong to the MDLL's /4 divider, clocked by `mdll_out`
(1.25 ns). The classifier's system clock `clk` (20 ns) has setup +3.13 ns (slow) and hold
+0.43 ns (fast). Per-clock values are in `doc/Specification.md`; the reports are in
`verification/sta/mdll-v2/`.

Constraint changes against v.1.0.0, in `constraints/sdc/chip_top.sdc`:
- **New clocks:** `mdll_ref` (10 ns, from `pad_mdll_clk_ref`) and `mdll_out` (1.25 ns, at
  the macro's `clk_out`), each asynchronous to all others.
- **Hold uncertainty on `mdll_out`:** 0.05 ns instead of 0.25 ns. The divider bits capture
  on the same edge that launched them, so clock jitter does not enter that check.
- **No timing on the MDLL's pad paths:** its reset input and its pad outputs (code, locked,
  both clocks) are false paths. They are observed off chip, not captured on it.

**Max-fanout waiver:** all 211 entries are clock-tree buffers inserted by CTS, identical in
every corner: 210 `clkbuf_leaf_*_clk_regs` leaf buffers and the root buffer
`clkbuf_0_i_core.sclk_i`. Each drives 10–16 flip-flops against a fanout limit of 8
(`verification/sta/mdll-v2/checks_*.rpt`). This is CTS sink clustering by design, as in
v.1.0.0 (216 entries there).

Fanout is only a proxy. The electrical limits behind it are clean:
- There are 0 max-slew and 0 max-cap violations in all corners.
- Setup and hold slack are positive with extracted parasitics.

The layout is unchanged by the rename and label fix (see provenance), so these timing
results apply to the release.

## Provenance of the release GDS

`TPU5555.gds` is built from the final GDS of LibreLane run `mdll-v2`. That GDS has SHA-256
`9573979b41b50b6cd8dc703f220736931925733808c5c8db88cada2c0b53f5e1` and is identical to the
output of its `KLayout.Filler` step, which runs after `KLayout.SealRing`. The hdc flow
repository was at `f442cc4` for that run.

1. `TPU5555-main/Flow/scripts/release/make_release.py` makes the same two edits as for
   v.1.0.0:
   - It renames the top cell `hdc_chip_top` → `TPU5555`.
   - It corrects the sealring PCell's registration label (layer 63/0) from
     "Calculated area: 4.8e-06 sq mm" to "4.8 sq mm".

   It then writes the file without PCell/context info and with zero-length paths eliminated.
2. `TPU5555-main/Flow/scripts/release/check_release.py` compares the result against the
   input with `pya.LayoutDiff` (top cell mapped back). The recorded output:

   ```
   orig top: ['hdc_chip_top'] | new top: ['TPU5555']
   new bbox (um): (0,0;2400,2000) | dbu: 0.001
   LayoutDiff identical: False
   cells: 294 294
   differences: 2
      ('only in orig', 'sealring', '63/0', 'Device registration size: x=2400.0 um ; y=2000.0 um\nCalculated area: 4.8e-06 sq mm')
      ('only in new', 'sealring', '63/0', 'Device registration size: x=2400.0 um ; y=2000.0 um\nCalculated area: 4.8 sq mm')
   zero-area shapes (all layers): 0
   ```

3. All physical checks were then re-run on the resulting file itself (see above), so the
   release is verified directly. The provenance chain is documentation, not the basis of
   the signoff.

The release netlists and all implementation views are the flow's outputs with the top name
`hdc_chip_top` replaced by `TPU5555`, by `TPU5555-main/Flow/scripts/release/rename_views.py`.
The script checks that the name occurs exactly as often as expected in each file.

In the release netlists:
- `mdll_bb.cdl` is the pin-only MDLL used by the LVS.
- `mdll_full.cdl` is the MDLL's complete netlist (top, blocks, custom cells, standard
  cells): the reference of its Calibre LVS.

## Seal ring

The seal ring is the PDK `sealring` PCell, instantiated at (0, 0) in `TPU5555`. Its bbox is
(0, 0)–(2400, 2000) µm, giving an area of 4.8 mm². `doc/info.json` records `sealring_x` =
2400.0 and `sealring_y` = 2000.0 in µm.

## Post-layout simulation

The routed netlist `TPU5555` (v.2.0.0) was simulated through its SPI pads with the IHP cell,
IO and SRAM models. The MDLL is a stub (outputs low) with its input pads tied low; it has no
digital model and is verified at transistor level (see the MDLL waiver above). The
simulation is zero-delay (Verilator); timing is covered by the STA above. It ran the full
classifier flow: all 4347 training and 1088 test samples of the supplied EMG data set.

- For three different random power-up states of all flops and SRAMs, the SPI protocol trace
  (every command, acknowledgement and result byte, with timestamps) and all 1088 predictions
  are identical to the RTL reference.
- Accuracy is 1039/1088 (95.5 %) in every run, the same as v.1.0.0. The RTL predictions are
  identical to v.1.0.0's.

Testbench, model fixes and results: `TPU5555-main/testbenches/gls/` (README.md,
`results/v.2.0.0/`).

## Known limitations

- **MDLL lock range at the slow corner.** Closed-loop simulation of the MDLL's Calibre RC
  netlist locks at ss (1.08 V, 125 °C) at 100 and 112.7 MHz and fails from 123.3 MHz, where
  acquisition keeps restarting. At 100 MHz it locks at all corners; tt and ff lock from 123.3
  to 150 MHz. The runs below 123 MHz were not all finished at release time. The state of those
  simulations at release time is in `verification/mdll/pex_status_2026-11-05.txt`.
- **Chip fill inside the MDLL area.** The chip's KLayout filler placed metal fill (about
  16–35 % on Metal1–TopMetal1) and Activ/GatPoly fill inside the MDLL outline. The MDLL's
  RC extraction does not include it, so the ring on silicon is slightly slower than
  simulated, and the ss limit drops further. The MDLL carries no fill-blocking layers;
  adding them requires a new chip run, which the schedule did not allow.
- **East pad pitch.** The east side carries 14 pads at a bondpad pitch of about 96 µm.

## Not covered

- No timing-annotated (SDF) simulation; timing is verified by STA only.
- The MDLL is not part of the gate-level simulation (stub); it is verified at transistor
  level (see `TPU5555-main/mdll/mixed_signal_design_blocks/TAPEOUT.md`).
- No silicon measurements yet.
