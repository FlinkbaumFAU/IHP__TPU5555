# Tape-out status and next steps

Hand-over notes for continuing the MDLL tape-out verification on any machine.
Last updated 2026-11-03. Read `CLAUDE.md` first for the
flow, the tools and the traps.

## Goal and plan

1. Harden every block with LibreLane. **Done.**
2. Harden a top-level **MDLL macro without pads**, with the four blocks as macros.
   The pad ring / shuttle harness is a separate, later step. **Done 2026-10-22.**
3. Run an independent full-chip LVS on the top-level GDS. Extract a transistor
   netlist from the layout (no parasitics) and simulate the closed loop in
   ngspice. This is the "open-source verified" MDLL. **Done 2026-10-23.**
4. Run Calibre RC extraction on the top-level GDS and simulate the closed loop
   with it. **This is the tape-out gate.** Ask Michael for the Calibre
   settings; magic is deliberately not used for RC.
5. Later, for the paper: open-source RC extraction of the same GDS (KLayout-based
   PEX / magic / OpenRCX for wiring), compared against Calibre.

## Where it stands (2026-10-23)

**Closed loop.** All runs are graded by `simulations/check_mdll.py` and PASS.
State: the `buf_4` replica (see Done on 2026-10-23).

| Run | Handover | Coarse jumps | Final 6-bit band | Lock offset `div − clk_ref` |
|---|---|---|---|---|
| Full transistor level, tt | cycle 33 | 0→49→66→72 | 18..19 | +246 ps (sd 141) |
| Full transistor level, ff / 1.32 V / −40 °C | cycle 20 | 0→103→132 | 34..35 | +154 ps (sd 103) |
| Full transistor level, ss / 1.08 V / 125 °C | cycle 23 | 0→12 | 4..5 | +492 ps (sd 201) |
| **Layout-extracted netlist (`make layout_sim`), tt** | cycle 31 | 0→49→65→70 | 18..19 | +324 ps (sd 138) |
| `make mdll_mixed_sim`, tt / ff / ss | 33 / 20 / 22 | as transistor level | 18..19 / 34..35 / 4..5 | — |

- The transistor-level runs used decks frozen in `build/tlvl/` (made from
  `build/test_mdll.spice`, the corner switched as `gen_mixed.py` does it).
  `simulations/analyse_mdll.py` gives the TDC readings, `div` per period and the
  lock offset: the nearest `div` rise to each of the last 30 `clk_ref` rises,
  i.e. the bang-bang dither. Before the replica changes (2026-10-21, tt) it
  was +334 ps (sd 194).
- Every corner ends its coarse phase on a TDC `hit` and hands over at once.
- The mixed runs used lock_ctrl's output delays from before the 2026-10-23
  re-harden; those moved by up to 51 ps since.

**Blocks** (sg13g2, re-hardened 2026-10-23 without magic; see Done):

| Block | Run tag (local only) | DRC / LVS / antenna | Setup / hold | 
|---|---|---|---|
| clk_gen | RUN_2026-10-23_13-19-13 | 0 / 0 / 0 | met, all corners (tightest +14 ps setup at fast, x12 → x11 recovery) |
| tdc | RUN_2026-10-23_13-21-55 | 0 / 0 / 0 | met |
| bbpd | RUN_2026-10-23_13-24-13 | 0 / 0 / 0 | met |
| lock_ctrl | RUN_2026-10-23_13-24-13 | 0 / 0 / 0 | met |

clk_gen reports 2 non-critical disconnected pins: `C[0]`, `C[1]`, which the
decoder ignores (`code[7:2]` only). bbpd has one max-fanout warning (x1.x6,
the `clk_ref_d` buf_2, fanout 10 > 8; slew and cap clean).

**Top-level macro `mdll`** (`make macros harden`): RUN_2026-10-23_13-28-13,
257.8 × 294.8 µm. KLayout DRC 0, LVS 0, routing DRC 0, antenna 0, PDN 0;
setup/hold met at all corners (WS +6.2 / +0.41 ns). `make match_report`:
`clk_ref_g − div` +9..+15 ps (worst 14.9 ps, gate 20 ps); wire loads `div`
22.6 fF, `clk_ref_g` 19.0 fF.

**Independent full-chip LVS** (`make lvs_full`): the PDK's `run_lvs.py` on the
merged top-level GDS against our own complete CDL (top + four blocks +
custom_stdcell + PDK stdcells, checked for duplicates and completeness):
**match**, 12 840 devices, 3 842 nets, 14 pins. Independent of LibreLane's
KLayout.LVS and its truncated-CDL bug.

- All signal pins are Metal2 on the north and south edges. VPWR/VGND are Metal3
  stripes inset to the core.

**SG13CMOS5L variant**, re-run 2026-10-23 on this machine's PDK (IHP-Open-PDK
`dev`, which now contains CMOS5L, with LVS deck `sg13cmos5l.lvs`): all four
blocks and the top level clean, timing met. **Since 2026-10-26 the CMOS5L top
level stops at Metal4** (`CMOS5L_2026-10-26_16-16-21`: no TopVia1/TopMetal1
at all; DRC/LVS/antenna/PDN 0; setup/hold WS +5.99 / +0.41 ns), so it uses
only layers sg13g2 has in the same place: both process specs give identical
thicknesses from Activ up to Metal4 (TILD0..3, TMET1..4), and the tech LEFs
are identical there. Above Metal4 they differ (sg13g2: 540 nm to Metal5;
CMOS5L: 850 nm to TopMetal1, then passivation), which only touches the upward
fringe of Metal4 wires. So IHP's sg13g2 Calibre decks (LVS and PEX) can be
used on the CMOS5L layout. The PDN there was Metal4 straps alone already: the
TopMetal1 straps had been removed by OpenROAD as floating (no Metal4–TopMetal1
via fit). `make match_report_cmos5l`: worst 11.5 ps, PASS (was 9.5 ps with
TopMetal1). Two notes:

- **Calibre LVS (2026-10-26, Michael):** IHP's Calibre deck exists for sg13g2
  only; applied to the CMOS5L layout, everything matches except (a) the filler
  instances in the CDL (device-less, nothing to match in the layout: use
  `make calibre_cdl_cmos5l` / `calibre_cdl`, which leave them out) and (b) the
  only two nets that use TopVia1/TopMetal1, `tdc_sel` and `net6` (`code[2]`),
  each split in two: in sg13g2 TopVia1 lands on Metal5, in CMOS5L on Metal4,
  which the sg13g2 deck does not connect. The deck picks its process from the
  `$IHP_TECH` directory name (SG13S/G2/G3/G2C/RH, Cu variants); none is
  CMOS5L, and every aluminium one wires M4–Via4–M5–TopVia1. Fixed by keeping
  the CMOS5L top level below TopMetal1 (above).
- That PDK's CMOS5L OpenRCX rules are a byte-identical copy of sg13g2's 7-layer
  rules, so the CMOS5L wire loads are still extracted with sg13g2's stack.
- With `buf_1` the CMOS5L match swung from −46 ps to +20 ps on routing alone
  (see Done); that is why the replica is `buf_4` now.

- **`pnr/runs/` is not in git.** On a new machine, re-create the layouts with
  `make netlist harden` in each of `clk_gen/`, `tdc/`, `bbpd/` and
  `lock_ctrl/` (about 2 min each). Then run `make delays` in `bbpd/` and
  `lock_ctrl/`, and check that `git diff` of `simulations/output_delays.json`
  is empty or negligible.

## Next steps, in order

Done on 2026-10-22:

- **`gen_mixed.py --spice-corner`.** `make mdll_mixed_sim CORNER=fast|slow`
  now switches the SPICE corner together with the STA delays (models, `VDD`,
  `.TEMP`, the d_cosim bridges' levels and `dco_decode`'s `vhi`/`vth`);
  `SPICE_CORNER=` overrides it. `check_mdll.py` takes its threshold from the
  run's `clk_ref` level. At typ the deck is unchanged. ff and ss reproduce the
  table above. The ff run's operating point prints "singular matrix: check node
  x1.x1.x11.x6.net5" (the divider's arm flop) and converges.
- **`lock_ctrl.v` timing comment.** A run ends within R fast-ring periods of
  `clk_ref`: ~7 cycles at tt, ~12 at ss. TMO = 31 covers both.
- **TDC arming margin** (`tdc/simulations/arm_margin.py`). The TDC ignores a
  Clk_out (`div`) edge that comes before the threshold below, and starts the
  slow ring on one that comes after:

  | Corner | Sel → Reset | threshold after Reset | after `busy` | after Sel |
  |---|---|---|---|---|
  | tt | 630 ps | +238 ps | +96 ps | 0.87 ns |
  | ss | 946 ps | +411 ps | +171 ps | 1.36 ns |
  | ff | 427 ps | +142 ps | +57 ps | 0.57 ns |

  The "37 ps" at ss was measured from Sel (`tdc_sel` 30.627 ns, stale `div`
  30.590 ns). Against the threshold the stale edge is 1.38 ns on the safe side.
  In the tt/ss/ff closed loops every `div` edge is ≥ 1.1 ns from the threshold
  (`arm_margin.py --closed-loop`). Near the threshold x6 resolves late and the
  slow ring starts up to ~200 ps later. That reads less error, i.e. the safe
  direction. If x6 resolves to "ignored", the next `div` comes after `clk_ref`
  and the run reports `hit`.
- **Top-level macro** (`pnr/config.yaml`; `make macros harden` copies each
  block's latest `final/` views into `build/macros/` and records the run tags
  in `build/macros/RUNS.txt`). Floorplan: clk_gen (N) and bbpd (FS) below a
  channel, tdc (FS) and lock_ctrl (N) above it, so `div`, `sel`, `C[7:4]`,
  tdc's Sel/Start/Clk_* and bbpd's/lock_ctrl's seed/load face the channel;
  clk_gen's `div` pin sits under tdc's `Clk_out`, and the clk_ref replica
  sits just above clk_gen's `div` pin. Metal4/Metal5 PDN, signals up to Metal5, TopMetal1/2 left to the
  parent. Things that needed fixing on the way, all commented in the config:
  - `pnr/pdn_cfg.tcl`: LibreLane's macro grid only connects Metal4–Metal5;
    the blocks' power pins are Metal3, so it adds a Metal3–Metal4 connect.
  - tdc is top-aligned with lock_ctrl: bottom-aligned, the rows left above
    it fell between two Metal5 straps (PDN-0179).
  - `KLAYOUT_CONFLICT_RESOLUTION: SkipNewCell`: the default renamed every
    block's copy of the standard cells (`sg13g2_buf_1$1`, …) on GDS merge,
    and LVS failed all four blocks.
  - The replica x5/x7/x8 is placed by hand; the tie cell x6 cannot be (the
    resizer replaces it before that step).
- **`div`/`clk_ref_g` replica made structural.** The tdc and bbpd compare
  `div` with `clk_ref_g`, a copy of clk_ref meant to carry the same gate delay.
  It did not: x5 (lgcp_1) drove bbpd's unbuffered 48.7 fF `clk_ref` pin, while
  `div` had a `buf_1` LibreLane's port buffering had put after the divider's
  ICG. The two happened to cancel to +16..+23 ps; the schematic-level runs,
  without that buffer, had about +129 ps (typ; +83..+202 over corners). Now:
  - clk_gen `divider.sch`: x5 (ICG) → x9 `buf_1` → `div`, x7 reads `div`;
    `clk_gen.sch`: explicit `buf_1` on `sel` (x15) and `clk_out` (x14), whose
    internal nets are now `sel_i` / `ring_out`; `pnr/config.yaml`
    `DESIGN_REPAIR_BUFFER_OUTPUT_PORTS: false`.
  - bbpd `pd.sch`: x6 `buf_2` drives `clk_ref_d` for everything but the
    sampler x1 (x3, x4, and dlf through a new `pd` pin): `clk_ref` pin
    48.7 → 6.5 fF (`div` pin 5.5 fF).
  - `mdll.sch`: x5 (lgcp_1) → x7 `buf_1` → `clk_ref_g`, x8 `nor2b_1` input as
    the dummy for x11.x7; placed just above clk_gen's `div` pin.
  - Checks: `make match_report` −12..+4 ps; gate_check `x12` margins
    250 / 411 / 152 ps (were 220 / 364 / 131); `pd_sim` PASS, +85 ps;
    mixed closed loop PASS at all three corners (table above).
  - What still sets the residual: clk_gen's internal `div` wire (3 fF), a
    little more top-level wire on `div`, and the ICG input slew: the ring
    drives it with ~21 ps edges, `clk_ref` arrives from outside. Each 10 ps of
    `clk_ref` edge moves the result by ~4 ps; check it again with the pad ring.

Done on 2026-10-23:

- **No magic in any LibreLane flow.** This machine's PDK (IHP-Open-PDK `dev`)
  has a CMOS5L magic tech that needs magic >= 8.3.657; LibreLane 3.0.16's
  shell has 8.3.623, cannot load it, cannot read the standard cells, and
  `Magic.WriteLEF` spun for an hour. Every `pnr/config.yaml` now substitutes
  out `Magic.WriteLEF` and `Odb.CheckDesignAntennaProperties` (magic's
  StreamOut/DRC were already off). In 3.0.16 no other registered step writes
  the design LEF, so the root `macros`/`macros_cmos5l` write each block's LEF
  from its final ODB (`common/pnr/write_lef.tcl`, OpenROAD
  `write_abstract_lef -bloat_factor 2`). `-bloat_occupied_layers` blocked the
  blocks' edge margins next to the pins, where magic's `-hide` LEF left room,
  and the top-level `div` route detoured (CMOS5L match −46 ps).
- **librelane is not on this machine's PATH.** Runs used LibreLane 3.0.16 from
  its exact commit: `NIX_SHELL="nix develop
  git+file:///home/michael/Documents/Passionate/librelane?rev=01ddb25e4424f6f5aaf6b951b14a2b6fdcf737c0 -c"`
  (the checkout itself is at 3.0.5).
- **Replica drivers upsized to `buf_4`** (clk_gen `divider.sch` x9 and
  `mdll.sch` x7, together). With `buf_1` (~2 ps/fF) the CMOS5L match moved
  from −46 to +20 ps between runs whose only difference was the macro LEFs.
  With `buf_4` it is −9.5 ps although `div` still carries 11 fF more wire
  than `clk_ref_g`; sg13g2 +14.9 ps. What remains is mostly the two clock
  gates (x11.x5 vs x5), which see `clk_ref`'s external slew: recheck with the
  pad ring. gate_check x12 leads unchanged (250 / 411 / 152 ps at code 0).
- **gate_check.py adds RSHUNT=1e12**: the typ code-0 deck stopped at 30 ns
  with "timestep too small" under KLU alone.
- **Step 3 (`make lvs_full`, `make layout_sim`, `simulations/gen_layout_tb.py`).**
  Full-chip LVS match (above). The extracted netlist's internal nets get the
  schematic names from the LVS cross-reference, so `check_mdll.py` and the
  save list work unchanged; the extracted ring is ~1 % slower than the
  schematic's. Layout closed loop: PASS (table above), ~4 h on a loaded
  machine.
  - **The 5 router-inserted antenna diodes are left out of the simulation**
    (`--keep-antenna` puts them back): the PDK's `dantenna` model stops
    ngspice-45 with "timestep too small" as soon as its node undershoots VSS,
    reproduced with the PDK's own `sg13g2_antennanp` on one `buf_1`. Each is
    ~1 fF on a code / `locked` output; LVS covers them.

Next steps, in order:

1. **Calibre RC (step 4) -- in progress, see "Calibre RC extraction" below.**
   typ and ff PASS with ideal supply; **ss fails: the DCO is out of range**
   (see "DCO range at the slow corner": fix proposed, not started). The
   full-supply runs on cae02 are still going.
2. Later: open-source RC extraction for the paper (step 5).
3. The `dantenna` model problem: report upstream (IHP-Open-PDK) or find a
   simulation setting that copes, so the layout sim can include the diodes.

Deferred design ideas (not needed for tape-out):
- **Two-jump acquisition** via a ROM of the measured e(code) curve, saving one
  TDC measurement (~8 cycles). Worth doing.
- **A seed→code pass-through** in dlf. Not worth it on its own: the TDC
  handshake needs its two edges anyway.

## Calibre RC extraction (step 4, started 2026-10-26)

**What was extracted.** The CMOS5L top level `CMOS5L_2026-10-26_16-16-21`
(Metal4 at most, see above), by Michael with Calibre v2025.4 and IHP's
**sg13g2** xRC deck (`SG13G2_618_rev1.3.2/Calibre/RSF/xrc.tvf`; IHP ships no
CMOS5L deck, and up to Metal4 the stacks are identical). Source netlist:
`make calibre_cdl_cmos5l` (`build/sg13cmos5l/layout/mdll_calibre.cdl`, no
filler instances). Settings (`_xrc.tvf_` in the run directory): R+C+CC, flat,
`PEX NETLIST ... ELDO SOURCENAMES`, no TICER reduction, 25 °C nominal, fill
mode G.
- Its LVS: **CORRECT** (all 2255 nets / 5877 reduced instances matched;
  warnings only about smashed MOS and 13 arbitrarily matched symmetric nets
  inside tdc's cap bank).
- Netlist: 17 818 MOS (fingers listed separately; total W within 0.5 % of the
  KLayout extraction), 12 antenna diodes, 306 844 R, 59 575 C to ground,
  119 782 coupling C, 3842 nets. VPWR/VGND alone hold 214 k of the R.
- Files: `mdll.pex.spice` + `mdll.pex.spice.pex` + `mdll.pex.spice.mdll.pxi`
  (+ LVS report, svdb). On cae02: `/home/rzlin/fi08deni/sg13cmos5l_mdll/CALIBRE_PEX/`
  (on Michael's laptop a copy was in `/tmp/test/CALIBRE_PEX/`, not durable).

**Simulation.** `make pex_sim PEX=<dir>/mdll.pex.spice [PEX_TAG=..]
[PEX_OPTS=--ideal-supply] [PEX_THREADS=8]` (`gen_layout_tb.py pex`): the
test_mdll deck with x1 replaced by the RC netlist, a 0 V probe per saved
internal net (from a node named after the net to its first gate node), then
`check_mdll.py`. Results land in `build/pex/<tag>/` (`check.txt`, `.log`,
`.raw`). Antenna diodes are left out as in `layout_sim`.
- `--ideal-supply` drops the VPWR/VGND networks and ties their nodes to the
  ports: 92 670 R, 21 456 C, all coupling C kept. The faster variant; the full
  one is the reference.
- **Runtime.** On the laptop the full netlist took ~7 min for the operating
  point (gmin stepping, "singular matrix" warnings on internal nodes, then
  converged) and ~12 min for the first 2 ns: the 1200 ns run would take days.
  Do not run it on the laptop. check_mdll needs handover + 40 cycles, i.e.
  ~700 ns at tt.

**Running on cae02.cs.fau.de** (96 cores, 755 GB): repo copy at
`/scratch.local/fi08deni/eda/mixed_signal_design_blocks`, ngspice-45 from
`~/.nix-profile/bin`, no xschem there. Setup (done 2026-10-26):
- `build/test_mdll.spice` is copied from the laptop (xschem output; `pex_sim`
  takes it as it is).
- The server's PDK (`/scratch/IHP-Open-PDK`) has no compiled OSDI models.
  Its MOS model files and PSP103 Verilog-A are identical to the laptop's, so
  the laptop's `osdi/*.osdi` are copied to an overlay,
  `build/pex/pdk/ihp-sg13g2/libs.tech/ngspice/{osdi,models -> PDK's}`, and
  ngspice runs with `PDK_ROOT=<repo>/build/pex/pdk PDK=ihp-sg13g2` (read by
  `~/.spiceinit`). The shared PDK is untouched.
- Two runs, started in the background with `nohup`, each writing
  `build/pex/<tag>/done` when it ends: `PEX_TAG=rc` (full) and
  `PEX_TAG=rc_ideal PEX_OPTS=--ideal-supply`. See "Runs started" below for
  the exact commands and the start time.

**Runs started 2026-10-26 17:46** on cae02, PIDs 2953413 (`rc`, full) and
2953416 (`rc_ideal`, `--ideal-supply`), 8 OSDI threads each. Two more things
the server needed: its default `python3` is 3.6 (too old for the scripts), so
`build/pex/bin/python3 -> /usr/bin/python3.11` goes first on PATH; and the
runs are started by `build/pex/launch.sh <tag> [pex options]` (not tracked,
in `build/` on cae02), which does:
```
cd /scratch.local/fi08deni/eda/mixed_signal_design_blocks
export PDK_ROOT=$PWD/build/pex/pdk PDK=ihp-sg13g2
export PATH=$PWD/build/pex/bin:$HOME/.nix-profile/bin:$PATH
P=/home/rzlin/fi08deni/sg13cmos5l_mdll/CALIBRE_PEX/mdll.pex.spice
tag=$1; shift; mkdir -p build/pex/$tag
nohup setsid sh -c "date > build/pex/$tag/started; make pex_sim PEX=$P PEX_TAG=$tag \
  PEX_OPTS=\"$*\"; date > build/pex/$tag/done" > build/pex/$tag.make.log 2>&1 < /dev/null &
```
**All runs restarted 2026-10-27 14:50** on cae02 with the new
`test_mdll.sch` control block (also saves `x1.clk_ref_g`; writes
`<raw>.300ns` at 300 ns and continues). The 10-26 runs were killed (`rc` after
21 h), the finished `rc_ideal` is kept as `build/pex/rc_ideal_2026-10-26/`.
cae02's `build/test_mdll.spice` = the laptop deck with the new control block
(identical to a fresh local netlist). Four runs, 8 OSDI threads each:

| Tag | Corner | Supply | ngspice PID |
|---|---|---|---|
| `rc` | typ | full | 3069124 |
| `rc_ideal` | typ | `--ideal-supply` | 3069128 |
| `rc_ss` | slow | full | 3069121 |
| `rc_ideal_ss` | slow | `--ideal-supply` | 3069131 |

**Results so far (2026-10-28):**
- `rc_ideal` (typ): PASS, the same as on 10-26: handover at cycle 19,
  jumps 0→34→48, band 13..14.
- `rc_ideal_ss` (ss): **FAIL, out of range.** Even at code 0x00 the ring is
  too slow: `div` comes 551 ps after `clk_ref` in every period (lock needs
  about +245 ps). The first TDC reading is `hit`, lock_ctrl hands over at
  cycle 6, and the bbpd says "too slow" every cycle with dlf saturated at
  0x00. `check_mdll.py` passed this as a "band 0..0" until check 7 (code
  at dlf's limit or constant after handover) was added. The old grade is
  kept as `check.old_grader.txt`.
- `rc` and `rc_ss` (full supply) had not reached 300 ns after 18 h. The ideal
  runs got there in about 2.6 h, so expect 3+ days for 1200 ns. Kept running.

Started as `[PEX_CORNER=slow] build/pex/launch.sh <tag> [--ideal-supply]`;
slow = mos_ss, VDD 1.08 V, `.TEMP 125` (`gen_layout_tb.py --corner`). The
extracted R and C stay at Calibre's 25 °C. The `clk_ref_g` probe sits on x8's
input (the first gate node of the net), not on the tdc/bbpd pins. Why ss: `rc_ideal` (typ, done
2026-10-27 06:10, PASS) locked at 6-bit 13..14 instead of 18..19, because the
RC slows the DCO by 15–21 % (+300..330 ps per period). The schematic ss loop
locks at 4..5 with 4·T_DCO(code 0) = 8.80 ns, so by that factor code 0 may no
longer reach T_REF = 10 ns at ss.

**Re-extraction and runs of 2026-10-29** (the loop changes of the section
below; the 10-27 runs are kept in `build/pex/2026-10-27_nodither/` on cae02).
Calibre re-extracted the new CMOS5L top `CMOS5L_2026-10-29_14-31-13` at
14:44 (same deck and settings; LVS **CORRECT**): 18 001 MOS, 310 977 R,
60 859 C, 133 604 coupling C. Six runs started 15:08, 8 OSDI threads each:
`rc`, `rc_ss`, `rc_ff` (full supply network; ngspice PIDs 3470365, 3470362,
3470359) and `rc_ideal`, `rc_ideal_ss`, `rc_ideal_ff` (`--ideal-supply`).
Results (2026-10-30, `simulations/analyse_mdll.py` on the raws):

| Run | Grade | Handover | Coarse jumps | 6-bit band | `div − clk_ref`, last 30 cycles |
|---|---|---|---|---|---|
| `rc_ideal` (typ) | PASS | cycle 24 | 0→32→45 | 13 | +298 ps, sd 31 (266..329) |
| `rc_ideal_ff` | PASS | cycle 28 | 0→82→107→113 | 29..30 | +180 ps, sd 38 (126..232) |
| `rc_ideal_ss` | **FAIL** | — | none | 0 | +658 ps at code 0x00 |

- The dither works with parasitics: 63 ps pp at typ (schematic mixed run 62).
- **ss is out of range** (as on 10-27, +551 ps then): at code 0x00 `div`
  comes 658 ps after `clk_ref` every cycle, the TDC reads `hit`, and
  lock_ctrl's restart fires every 14 cycles as designed (9 handovers, 8
  restarts in 1.2 us). See "DCO range at the slow corner" below.
- The full-supply runs had not reached 300 ns after 18 h (2026-10-30 09:00).

Check with `ls build/pex/*/done` and `cat build/pex/*/check.txt` (the grade);
`build/pex/<tag>/test_mdll_pex.log` is ngspice's output. ngspice prints
nothing during `tran` in batch mode, so before the end progress is only
visible as CPU time (`ps -C ngspice -o pid,etime,time,args`). To analyse a
finished run like the others, copy its `.raw` back and run
`simulations/analyse_mdll.py` / `check_mdll.py --raw` on it.

## DCO range at the slow corner (open, 2026-10-30) -- blocks tape-out

With the extracted wiring the ring cannot reach T_REF = 10 ns at ss
(mos_ss, 1.08 V, 125 °C) even at code 0x00 (`rc_ideal_ss` above: `div`
658 ps after `clk_ref`). Cause and a candidate fix, from
`clk_gen/simulations/dco_variant.py` (free-running ring, gen_char_dco's deck;
4·T in ns; "wire" = the extracted load added to each ring node):

**Where the time goes.** Each half-stage is an `inv_1` driving a ring node
that carries eight `cap_4` units, the next stage, and the cross-coupled
`inv_1` pair. The 10-29 PEX puts **6.1–6.7 fF of wiring on each of the eight
ring nodes** (`ring_p/n`, dco `net1..net6`; ~2.8 fF to ground + ~3.5 fF
coupling, mostly to VPWR/VGND). Everything else in the DCO is < 1 fF, except
the output taps (`clk_outb`, `ring_out`: ~7.5 fF, outside the loop).

| Ring | ss code 0 | typ code 0 | typ code 63 | ff code 0 | ff code 63 |
|---|---|---|---|---|---|
| today, schematic | 8.14 | 5.05 | 22.82 | — | — |
| today + wire | **9.70** | 6.01 | 23.82 | 3.91 | 16.48 |
| inv_2 forward inverters (x13/x14) + wire | 6.02 | 3.77 | 11.99 | 2.47 | **8.19** |
| `cap_2` units + wire | 8.68 | 5.41 | 14.26 | 3.53 | **9.72** |
| **inv_2 + `cap_8` units + wire** | **6.55** | 4.08 | 20.70 | 2.66 | **14.32** |
| inv_2 + `cap_8`, 1.5× wire | 6.92 | — | — | 2.81 | 14.47 |
| inv_2 + `cap_8`, 2× wire | 7.29 | — | — | 2.95 | 14.62 |

- The wire alone costs +19 % at ss code 0 (8.14 → 9.70).
- `rc_ideal_ss` itself, from the start (compared with the schematic ss run
  `build/mixed_slow`): ring period at code 0x80 5.88 ns (schematic 5.32,
  +10.5 %), at code 0x00 2.52 ns free-running, i.e. 4·T ≈ 10.08 ns
  (schematic 2.065 ns / 8.26 ns, +22 %). So 4·T(0) is just above T_REF: the
  ring is still in its 4th period when `clk_ref` comes, never gates (no wait
  phase; the schematic waits 2.79 ns before each injection), and the
  injection pulls it to exactly T_REF/4 with `div` a constant +0.66 ns after
  `clk_ref`. The fixed wire load weighs more at code 0 than at 0x80. The
  free-running model with the wire gives 2.43 ns; the RC's other parasitics
  add the rest.
- Today's range is lopsided: the upper half of the bank is unused at every
  corner (ff locks at 8-bit 113). What must hold is ss code 0 well below
  10 ns AND ff code 63 well above it.
- inv_2 alone or `cap_2` alone lose the top end at ff (< 10 ns).
- **inv_2 + `cap_8`** shifts the whole curve: 35 % margin at ss code 0, 43 % at
  ff code 63, still 27 % / 46 % with twice the extracted wire. Near the lock
  points the step per code stays the same (typ: 0.27 vs 0.28 ns of 4·T per
  6-bit code around 10 ns; ss 0.35 vs 0.39; ff 0.19 vs 0.20), so lock_ctrl's
  K and the dither should carry over. Lock codes move up (typ 6-bit ~16 → ~24).

**Implementation (started 2026-10-30).**
- custom_stdcell `33fd5af`: `cap_8` was 5.68 µm wide (not a multiple of
  the 0.48 µm site) with its rail contacts off the site centres -- abutted
  rows broke Cnt.b / CntB.*; now 5.76 µm (12 sites), contacts at
  0.24 + 0.48k, LEF and Liberty added. **`cap_4` had a VSS-rail contact at
  x 0.73 instead of 0.72**, which merges with a flipped neighbour's into a
  0.17 µm ContBar: **108 `CntB.a1` (a precheck rule) in the hardened
  clk_gen**, unseen because LibreLane's KLayout DRC runs the ciel deck's main
  rules only (`run_drc.py` on the GDS shows them). Fixed in the cell; every
  block with cap_4 (clk_gen, tdc's rings) needs a re-harden. Run the full
  PDK `run_drc.py --no_density` on the final GDS as part of sign-off.
- clk_gen: `src/delay_cell.sch` x13/x14 inv_1 → inv_2, the 16 caps → `cap_8`;
  `gen_char_dco.py` likewise (and `set num_threads=1` per deck: on cae02 the
  64 shards otherwise started 96 OSDI threads each). `dco_variant.py`'s
  defaults are the new ring.
- `make char` (on cae02): PASS, 1103 → 198 MHz, strictly monotonic.
  Free-running 4·T, schematic / + extracted wire (`clk_gen/build/curves/`):

  | Corner | code 0 | T_REF at 6-bit | code 63 |
  |---|---|---|---|
  | ss | 5.81 / 6.55 ns | 13 / 11 | 31.0 / 31.8 ns |
  | typ | 3.63 / 4.08 ns | 27 / 25 | 20.2 / 20.7 ns |
  | ff | 2.37 / 2.66 ns | 43 / 42 | 14.0 / 14.3 ns |

- `lock_ctrl/simul/dco_period.vh` regenerated from the new char. `make
  sim_acq`: 216/216 PASS; also 40/40 at DCO 60/70/150/165/180 % (lock codes
  49 .. 8, handover by cycle 53).
- `gate_check` (cae02, `clk_gen/build/gate_drv2_*.txt`, `gate_x12map_*`):
  every code around the lock points gates in the low half with one `div`
  and x12 on the injection's own edge (margin ≥ 557 ps). **Open: at low
  codes x12 misses** -- the injected edge reaches `clk_outb` sooner through
  the faster ring, the release (sel falling) does not move:

  | corner | x12 lead at code 0 | misses up to 8-bit code | ok from |
  |---|---|---|---|
  | ss | 114 ps | 16 (needs ~300 ps) | 20 |
  | typ | 68 ps | 8 | 12 |
  | ff | 35 ps | 8 | 12 |

  The divider then starts one edge late: `div` after 5 DCO periods, which
  under-reads (safe) -- but where 4·T < T_REF < 5·T (ss around 6-bit 4) the
  TDC would read `hit` on a fast ring and hand over early. ff code 0 still
  gives two `div` per period. Also: clk_gen's STA assumes code-0 periods of
  1.2 / 1.95 / 0.78 ns (`pnr/base.sdc`); the new ring is ~0.91 / 1.45 /
  0.59 ns, so the x12 → x11 recovery check (the tightest) must be redone.
  **Resolved (2026-10-30): lock_ctrl starts at `START` = 8'h18** (6-bit 6)
  after reset and restart, `4405fa0`. x12 is on the injection's edge there at
  every corner (222/378/130 ps tt/ss/ff); 4·T at ss with the wire ~8.5 ns,
  still the fast side. At ff it still gives 8 edges and two `div` per period,
  as code 0 did with the old ring (harmless, see "Things that are easy to get
  wrong"). LEC, formal (restart forces `seed == START`), sim_acq 216/216 and
  48/48 at DCO 60..200 % PASS; `sim_variants` unchanged in the grid; the
  fault table improves at 160 % (97/108 relock, was 72/108). clk_gen's STA
  periods are now START's (1.17/1.91/0.75 ns), `pnr/base.sdc`.
  `check_mdll.py` reads START from the RTL.
- Running on cae02 since 2026-10-30 15:30: transistor-level closed loops of
  the new ring with START at tt/ss/ff (`build/tlvl_start24/`, decks made from
  `build/test_mdll.spice` with `gen_mixed.set_corner`, paths rewritten for
  cae02; ngspice PIDs 3578390 / 3578409 / 3578425; `<tag>.done` when
  finished, `<raw>.300ns` snapshot). The first attempt (`build/tlvl_drv2/`)
  failed its operating point at a ring node under KLU; `test_mdll.sch` now
  sets RSHUNT=1e12 next to KLU (`18912a5`).

- **Re-hardened 2026-10-30** (this laptop; all four blocks, as the 10-29 runs
  exist only on the other machine; `build/reharden/` has the scripts and logs):

  | Block / top | sg13g2 | CMOS5L |
  |---|---|---|
  | clk_gen | RUN_2026-10-30_15-44-53 | CMOS5L_2026-10-30_15-46-40 |
  | tdc | RUN_2026-10-30_15-31-24 | CMOS5L_2026-10-30_15-34-32 |
  | bbpd | RUN_2026-10-30_15-31-24 | CMOS5L_2026-10-30_15-34-31 |
  | lock_ctrl | RUN_2026-10-30_15-31-24 | CMOS5L_2026-10-30_15-34-30 |
  | top `mdll` | RUN_2026-10-30_15-48-44 | CMOS5L_2026-10-30_15-49-49 |

  Every run: KLayout DRC 0, LVS 0, routing DRC 0, antenna 0 (top: PDN 0),
  setup and hold met at all corners. clk_gen setup slack fast/typ/slow
  +50/+103/+182 ps (CMOS5L +35/+78/+141). `match_report` 8.6 ps, CMOS5L 7.5 ps
  (gate 20). `lvs_full`: match. **Full PDK DRC (`run_drc.py --no_density`) on
  both top-level GDS: clean** -- including the CntB precheck rules.
  - clk_gen's tightest check, x12 → x13 → x11 recovery at fast, first failed
    by 5 ps: x13 now takes `div_rstb_s` on A, its fastest input (~8 ps), and
    `pnr/base.sdc` times the DCO clocks at the START period of the ring with
    its extracted wiring, 5 % under (1.26/2.01/0.83 ns typ/slow/fast; the
    schematic ring alone is ~11 % faster). See the comment there.
  - `common/pnr/cmos5l_pdk.sh` falls back to the PDK's own LibreLane config
    when the checkout predates 23854a19 (this laptop: bf079026).
  - bbpd and lock_ctrl output delays regenerated (bbpd up to +260 ps at slow
    vs the 10-29 runs: a different layout); `bbpd/simulations/dlf.spice`
    regenerated by this machine's yosys (same 125 cells, renumbered).
  - Calibre inputs for the new layout: `pnr/runs/CMOS5L_2026-10-30_15-49-49/
    final/gds/mdll.gds` + `build/sg13cmos5l/layout/mdll_calibre.cdl`
    (sg13g2: `RUN_2026-10-30_15-48-44` + `build/layout/mdll_calibre.cdl`).

- **Closed-loop runs started 2026-10-30 16:40** (all on the re-hardened design):
  - `mdll_mixed_sim` tt/ss/ff on this laptop, `build/mixed2_<corner>/`
    (deck, cosim, shim copied per corner from `gen_mixed.py --corner`;
    `done.txt` when finished; ngspice PIDs 401583 / 401585 / 401586).
  - The layout-extracted netlist of `RUN_2026-10-30_15-48-44` at tt/ss/ff on
    cae02, `build/layout_2026-10-30/` (`gen_layout_tb.py tb`, the corner
    switched in the deck; PIDs 3580926 / 3580938 / 3580953).
  - Transistor-level loops tt/ss/ff on cae02, `build/tlvl_start24/` (see above).
  Grade each with `simulations/check_mdll.py --raw <raw>` and
  `simulations/analyse_mdll.py <raw>`.

- **Results (2026-10-31)**, `check_mdll.py` / `analyse_mdll.py`:

  | Run | tt | ss | ff |
  |---|---|---|---|
  | mixed (`build/mixed2_*`) | PASS, cyc 34, 153..391 ps | PASS, cyc 26, 255..631 ps | PASS, cyc 29, 133..186 ps |
  | transistor level (`tlvl_start24`) | PASS, cyc 25, 155..323 ps | FAIL (check 3), cyc 27, 256..533 ps | PASS, cyc 29, 136..188 ps |
  | layout netlist (`layout_2026-10-30`) | PASS, cyc 34, 222..334 ps | PASS, cyc 35, 259..490 ps | PASS, cyc 29, 149..196 ps |

  (handover cycle, `div − clk_ref` over the last 30 cycles.) Every run
  acquires from START on the fast side and hands over on `hit`.
  - **The transistor-level ss FAIL:** at 213 ns, with `load` high, the code
    went 36 -> 35 for one cycle while lock_ctrl's `seed` changed 36 -> 43 on
    the same clk_ref edge: bits 0..2 new, bit 3 old, i.e. dlf's seed
    re-register most likely caught `seed` mid-change (a hold race in the
    schematic netlist, which has no clock tree). The layout netlist at ss does
    not show it, and top-level STA has hold met (+0.36 ns). Not confirmed:
    dlf's internal nodes were not saved.
  - **Lock swing:** where the lock lands next to a 6-bit carry (tt 103/104,
    ss 47/48) the code walks +-2 LSB in a period-8 triangle (100..380 ps pp);
    ff (169/170) alternates by one LSB (~50 ps pp). Cause: the code reaches
    the cap bank ~2 ns into period 0 of the next run (T_DCO 2.5 ns). A step
    that only changes the dither (unit N in the last k periods) acts on
    periods still ahead; the carry (N,3) -> (N+1,0) changes all four periods,
    and period 0 is mostly over, so its first run moves only ~0.2 LSB. The
    static steps are even (`gate_check`, `clk_gen/build/gate_dither_*.txt`:
    tt codes 100..108 move div by 40..110 ps each, the carry 70 ps). The
    10-29 design locked at 74/75 at tt, away from a carry. Fix not decided
    (options: a dither pattern whose every step changes only periods ahead;
    accept +-2 LSB; act one run later).
- The 10-29 full-supply RC runs on cae02 (`rc`, `rc_ss`, `rc_ff`, the old
  ring) were stopped on 2026-10-31 after 48 h without finishing.

**Still to do:** decide the dither / carry question; fix the seed hand-over
race (see "Start-up" below: dlf re-register on the falling clk_ref); then a
Calibre RC extraction of the then-current `CMOS5L_*` top run and `make
pex_sim` at all corners (the tape-out gate).

## Start-up: start controller and dlf reset code (2026-11-02)

**Found** in `build/tlvl_start24/test_mdll_ss.raw` (Michael): the first run
after reset mixed codes and began at no clk_ref edge.
- `resetb` rose at 1.025 ns, mid-high-half. clk_gen's `Resetb` forces `sel`
  high (selector.sch x5, `Sel = nand(net4, Resetb)`); on release `sel` falls
  at once and the ring closes, so the release itself started the run, and the
  divider (x13 takes `Resetb`) counted from there.
- dlf's update from the 0.025 ns clk_ref edge (clk_dlf, ~1.5 ns at ss) came
  after the release with `load_r` reset to 0: a bang-bang step 0x80 -> 0x81.
  lock_ctrl's preset (START) reached the code ~13 ns, inside the first run.
  The first `div` (15.4 ns) ended a 0x80/0x81/0x18 run.
- Harmless in that run (the first TDC reading is at cycle 7, at a clean
  0x18) and not the cause of the ss check-3 FAIL, but where `resetb` lands
  decided how the loop started.

**Fix, `0d6b77c`:**
- `mdll.sch` x9..x13, the start controller. x9/x10: synchroniser on the
  RISING clk_ref -> `rstb_gen` (clk_gen). x12 on the falling clk_ref, D =
  `rstb_gen` -> `rstb_ctl` (lock_ctrl, bbpd) half a period later.
- Why the rising edge: the DCO's input muxes are `M_outb = sel ? clk_ref :
  ring_p` (dco.sch x9/x1). In reset `M_outb` follows clk_ref and the ring end
  `ring_p` holds the low-half level (high) until the injected edge has gone
  round, ~T_DCO/2 after it. `sel` may fall anywhere in that window without a
  glitch -- exactly what a normal injection does. A release in the low half
  would start the ring at the release (`M_outb` jumps to `ring_p` = 1).
  Window: release at clk_gen < ~T_DCO/2 at START after the edge (~0.37 ns at
  ff, ~1 ns at ss); clk-to-q + x5 nand is well inside. Not STA-timed (a
  clk_ref -> ring relation, as x12): the transistor-level runs check it.
- Why lock_ctrl later: clk_gen's reset forces `sel` (lock_ctrl's `inj`) high,
  which would read as an injecting edge. Released on the falling edge, its
  first edge is the one after the ring's first run.
- `bbpd/rtl/dlf.v`: `RESET_CODE = 8'h18` (= lock_ctrl's START) and
  `load_r/seed_r` reset to "load RESET_CODE", so the code is START from reset
  on and no update before lock_ctrl's preset follows comp. LEC, formal (dlf
  and lock_ctrl), comp-cone check pass; `dlf.spice` regenerated (131 cells).
- `check_mdll.py`: exits if dlf's RESET_CODE != lock_ctrl's START (separate
  macros); check 0 is now "START at the first edge after reset", check 3
  covers every coarse cycle; check 6 keeps the 0x80 bang-bang baseline.
- `test_mdll.sch` saves `x1.rstb_gen x1.rstb_ctl x1.inj_sel`.
- The testbench releases `resetb` at one phase only (1.025 ns). Other phases
  need no new mechanism (x9/x10 resynchronise any of them) but are not
  simulated.

**Results so far (2026-11-02 evening):**
- First run after reset = a normal injection at every corner: clk_ref ->
  first clk_out fall 818 / 1289 / 543 ps (tt/ss/ff, mixed) against 819 / 1291
  / 543 ps for the later injections; transistor level ss 1289 vs 1291, ff 544
  vs 544. `rstb_gen` 161..364 ps after the edge (STA at the clk_gen pin
  0.17 / 0.25 / 0.38 ns ff/tt/ss); `rstb_ctl` half a period later.
- Mixed (`build/mixed3_*`, 10-30 output delays): **PASS** at all corners -- tt
  cyc 36, 24->75->93->99, band 25..26; ss cyc 28, 24->36->43, band 11..12; ff
  cyc 31, 24->128->157->164, band 42..42 (8-bit dithers).
- Re-harden (`build/reharden2/`): bbpd `RUN_2026-11-02_17-12-54` /
  `CMOS5L_2026-11-02_17-13-43` (setup +15 / +30 ps, hold met), top
  `RUN_2026-11-02_17-33-22` / `CMOS5L_2026-11-02_17-34-51`: KLayout DRC 0,
  LVS 0, routing DRC 0, antenna 0, PDN 0, setup/hold met (top hold +0.21 ns);
  `match_report` 10.5 / 8.5 ps; `lvs_full` match; full PDK DRC clean on both
  GDS. bbpd output delays regenerated (-216 .. +120 ps vs the 10-30 run; the
  mixed runs above still used the old ones). New Calibre inputs:
  `pnr/runs/CMOS5L_2026-11-02_17-34-51/final/gds/mdll.gds` +
  `build/sg13cmos5l/layout/mdll_calibre.cdl`.
- **Abstract LEF fix.** The first top-level run had an M3.b (0.19 < 0.21 um)
  error: `tdc_f[6]` routed 0.42 um inside lock_ctrl's outline, next to a Via2
  whose enclosure (to x 4.465) is not in the LEF (OBS ends at 4.42).
  OpenROAD's `write_abstract_lef` puts wires in OBS but not via enclosures.
  `common/pnr/grow_obs.py`, run by `make macros`, grows every OBS rectangle
  by 0.1 um. All macro LEFs regenerated with it.
- **Seed hand-over race, in the schematic netlists only.** Every coarse jump
  in the transistor-level runs passes through one mixed code for one cycle
  (ss 24 -> 60 -> 36 and 36 -> 35 -> 43; ff 24 -> 152 -> 128, 128 -> 133 ->
  157, 157 -> 188 -> 164; 60 = 24|36). lock_ctrl launches `seed` on the raw
  clk_ref (structural `lock_ctrl.spice`: bits change at +0.25..0.30 ns at
  ss) and dlf's `seed_r` captures it on `clk_ref_g` (x5+x7, +0.254 ns): bits
  2/5 land before the capture, 3/4 after. A hold race; the hardened design
  meets it only because PnR adds delay (top-level hold +0.21 ns), which the
  schematic netlists lack. So the schematic transistor-level runs will FAIL
  check 3 (the 10-30 ss FAIL was the same race). Proposed fix (not done):
  re-register load/seed in dlf on the FALLING clk_ref -- launched at the rise,
  captured half a period later, loaded at the next clk_dlf as now, so the
  latency is unchanged and hold has ~5 ns instead of ~0.2.

**Runs started 2026-11-02 ~17:10:**
- Transistor level tt/ss/ff on cae02, `build/tlvl_startctl/` (decks from
  `build/test_mdll.spice` as for `tlvl_start24`; PIDs 3786429 / 3786446 /
  3786461; `<c>.start`, `<c>.done`, `<raw>.300ns`).
- Mixed tt/ss/fast on this laptop, `build/mixed3_<corner>/` (`done.txt`). Output
  delays still from the 10-30 bbpd (dlf's reset values only changed).
- Re-harden of bbpd and the top level (sg13g2 + CMOS5L, match_report, LVS,
  full DRC) on this laptop: `build/reharden2/run.sh`, `steps.txt`.
- Layout-extracted netlist of `RUN_2026-11-02_17-33-22` tt/ss/ff on cae02,
  `build/layout_2026-11-02/` (started ~18:20, PIDs 3788663 / 3788671 /
  3788689, `<c>.done`). Decks made locally by `gen_layout_tb.py tb`, models /
  VDD / .TEMP switched (no dco_decode line in a layout deck), paths rewritten.
  Grade every run with `check_mdll.py --raw` and `analyse_mdll.py`.

## Re-harden on this machine (2026-11-03)

The 10-30 and 11-02 runs were made elsewhere; here every block and both top
levels were re-hardened from `5824cc9` (custom_stdcell fast-forwarded to
`33fd5af` first -- the cap_8 ring needs it).

- Blocks `RUN_/CMOS5L_2026-11-03_12-46-4x` (bbpd `13-42-47` / `13-44-16`),
  tops `RUN_2026-11-03_13-46-43` / `CMOS5L_2026-11-03_13-47-44`: DRC, LVS,
  antenna, slew/cap 0, timing met; match_report 14.3 / 8.0 ps; `lvs_full`
  match; full PDK DRC (`run_drc.py --no_density`) clean on both tops. bbpd
  output delays and both Calibre CDLs regenerated.
- **NW.d at bbpd's top-right halo corner** (full PDK DRC only; LibreLane's
  KLayout DRC does not check it): with bbpd at y 22.68 its top + halo ended
  just under the VDD rail at y 124.74, so the row below was cut and the one
  above was not; the shared NWell got a notch and the upper row's N+ rail tap
  sat 0.24 um from it (0.31). Any cell there does it -- fill_2 as well as
  decap_8 -- and a one-site nudge only moved it between sg13g2 and CMOS5L.
  Fix: bbpd one row lower (y 18.90), so the corner ends on a VSS rail, and
  bbpd's die fixed at 93.42 x 97.02 um (it was the last block sized by
  utilisation; its height decides where that corner falls).
- **Reproduced on cae02 (2026-11-04), GDS-identical.** From `a6808fa` with
  clean build dirs and cae02's own PDK (`/scratch/IHP-Open-PDK`, 3f66c913;
  this laptop: 6ac9bb9d), all CMOS5L blocks and the top level
  (`build/rh_cae02.sh` there): DRC/LVS/antenna 0, timing met, match 8.6 ps,
  full PDK DRC clean. The tools are this laptop's exact nix store paths
  (LibreLane 3.0.16, Yosys 0.69, OpenROAD 26Q2, KLayout 0.30.12, xschem
  3.4.7), in cae02's `build/tools/` (`. build/tools/env.sh`; GC roots in
  `build/tools/gcroots`). They came over with `nix copy --no-check-sigs
  --to 'ssh-ng://cae02?remote-program=/nix/var/nix/profiles/default/bin/nix-daemon'`;
  Yosys is a local build without a cache signature, which cae02 refuses, so
  its `.drv` was copied instead and realised there (same output path).
  KLayout XOR against this laptop's runs: clk_gen, bbpd, lock_ctrl and,
  after the fix below, tdc and the top level **0 of 17 / 23 layers differ**.
- **Stale counter netlist.** tdc differed first: this laptop's
  `tdc/build/01-synth/counter.v` was from 09-30, Yosys 0.59.1. The make rule
  depends on the RTL and the script only, so the switch to Yosys 0.69 never
  rebuilt it. Rebuilt from clean (LEC PASS): tdc `CMOS5L_2026-11-04_14-28-02`
  and top `CMOS5L_2026-11-04_14-28-46`, identical to cae02's
  `CMOS5L_2026-11-04_14-21-44`; `tdc/simulations/counter.spice` regenerated.
  The 11-03 top (and its Calibre extraction) has the old, equivalent counter
  mapping, i.e. different buffers inside tdc. A clean build (`make clean`)
  after any tool change avoids this.
- **Current runs (2026-11-04, older ones deleted):** clk_gen, bbpd,
  lock_ctrl as above; tdc `RUN_2026-11-04_15-07-52` /
  `CMOS5L_2026-11-04_14-28-02`; top `RUN_2026-11-04_15-08-18` /
  `CMOS5L_2026-11-04_14-28-46`. sg13g2 top: DRC/LVS/antenna 0, setup/hold
  +3.20 / +0.20 ns, match 17.0 ps (14.3 with the old counter order);
  CMOS5L match 8.6 ps; `lvs_full` match; full PDK DRC 0 on both; Calibre
  CDLs and `build/sg13cmos5l/ip/mdll/` from these. The Calibre-extracted
  11-03 CMOS5L GDS survives only as `CALIBRE_PEX/mdll.gds` on cae02.
- **Calibre RC of `CMOS5L_2026-11-04_14-28-46`** (Michael, 11-04 15:05,
  same deck/settings; GDS and CDL byte-identical to this laptop's; LVS
  CORRECT): 18 243 MOS, 116 233 R with ideal supply, 26 223 C, 136 675 CC.
  The 11-03 runs were stopped (full-supply ones after 23 h, unfinished)
  and moved to `build/pex/2026-11-03_layout/` on cae02. **Started 11-04
  15:30** (`build/pex/launch_all.sh` there): `rc`, `rc_ss`, `rc_ff` (full
  supply) and `rc_ideal*` at 100 MHz, 2 OSDI threads each; and
  `build/pex/sweep/f<MHz>_<corner>/`: 16 reference frequencies 70..150 MHz
  (70 + k*80/15) x typ/slow/fast, ideal supply, 120 reference cycles each
  (`gen_layout_tb.py pex --tref/--tstop`), 1 thread each (the solve is
  matrix-bound: the old 8-thread runs averaged ~1.3 cores).
- **For the hdc chip:** `make ip_cmos5l` packages the CMOS5L top level
  (GDS, LEF, Liberty, CDL, pin-only CDL, SOURCE.txt) in
  `build/sg13cmos5l/ip/mdll/`. The hdc repo's branch `mdll` (cae02,
  `/scratch.local/fi08deni/eda/hdc`) has cae02's package in `asic/ip/mdll/`.
- `run_drc.py` on the CMOS5L GDS hung in deep mode on the maximal deck (40
  min, no progress, after the per-table runs finished in a minute);
  `--run_mode=flat` runs it in 85 s. The sg13g2 deck runs fine in deep mode.
  Both need the `klayout` stub package (`build/layout/pyshim`, from
  `make lvs_full`) on PYTHONPATH -- only for run_drc.py: exported for the
  whole job it also replaces LibreLane's real klayout and the stream-out
  fails. Stopping a hung run_drc.py takes its whole process group: killing
  the Python parent left its multiprocessing KLayout child running (3 h).
- **Calibre RC of this layout**, extracted by Michael 2026-11-03 16:01 into
  the usual `CALIBRE_PEX/` on cae02: GDS and CDL byte-identical to
  `CMOS5L_2026-11-03_13-47-44` / `build/sg13cmos5l/layout/mdll_calibre.cdl`,
  LVS **CORRECT**; 18 223 MOS, 314 773 R (ideal supply: 116 100), 61 123 C,
  136 758 CC. **Six runs started 16:08** on cae02 by `build/pex/launch.sh`
  (nohup + setsid: own session, no tty, parent init), 8 OSDI threads each:
  `rc`, `rc_ss`, `rc_ff` (full supply) and `rc_ideal`, `rc_ideal_ss`,
  `rc_ideal_ff`. Deck: a fresh `build/test_mdll.spice` (start controller
  saves, RSHUNT) copied over. The 10-29 runs moved to
  `build/pex/2026-10-29_dither/`.

  Results, ideal supply (done 11-04 04:00..05:10; `analyse_mdll.py` on the
  raws, copies in `build/pex_2026-11-03/` on the laptop):

  | Run | Grade | Handover | Coarse jumps | Lock codes (8-bit) | `div − clk_ref`, last 30 cycles |
  |---|---|---|---|---|---|
  | `rc_ideal` (tt) | PASS | cycle 32 | 24→62→77→82 | 86..89, period-6 triangle | +276 ps, 169..362 (194 pp) |
  | `rc_ideal_ss` | PASS | cycle 7 (first reading `hit`) | none | 34/35 | +447 ps, 410..484 (74 pp) |
  | `rc_ideal_ff` | PASS | cycle 31 | 24→109→137→144 | 151/152 | +201 ps, 182..220 (38 pp) |

  - **ss is in range now** (10-29: stuck at 0x00, `div` +658 ps): START is
    already close enough, the bbpd walks 24 → 34/35.
  - tt locks on the 6-bit carry 87/88 (0x57/0x58) and shows the +-2 LSB
    triangle of "Lock swing" above; ss is away from a carry (1 LSB); ff sits
    on one (0x97/0x98) and still alternates by 1 LSB, as on 11-02.
  - The full-supply runs had not written their 300 ns snapshot after 16.5 h
    (11-04 08:30).

## Loop latency, out-of-lock restart, dither (started 2026-10-28)

Goal: shrink the bang-bang swing at lock (284 ps pp in the mixed run). Five
steps; 1-4 done (62 ps pp in the mixed run), nothing committed yet, and **every macro hardened before this
is stale for bbpd and lock_ctrl** (clk_gen too after step 4).

1. **Behavioural study** (`make -C lock_ctrl sim_variants`,
   `lock_ctrl/simul/sweep_variants.py` -- findings in its header). The ring
   model in `tb_acq.v` was corrected to clk_gen's gate_check (sel rises
   ~1.1 ns BEFORE div; the old model's falling-edge injection mode is gone).
   Result: dither code[1:0] over the LAST k of the 4 DCO periods, and update
   the code early in the next run -> one quarter step of swing (61/79/94 ps
   at DCO 80/100/125 %). A slowed ring mostly finds a mid-range false lock,
   not a rail.
2. **lock_ctrl restart** (`rtl/lock_ctrl.v`, "Re-acquisition"): FINE goes back
   to ARM (code 0x00, locked low) after 2 locked edges without injection
   (counted until 16 consecutive edges inject) or 8 cycles at 0x00/0xFF.
   Formal: restart only on that evidence, always forces 0x00, always happens
   on it. Relocks in 17..33 cycles after a 115..140 % DCO step; never fires in
   a normal lock (sim_acq, and the mixed run).
3. **bbpd: early update, Gray dlf, no late flag.**
   - pd.sch: x4/x5 and the `sel` pin removed (mdll.sch, test_fine_loop.sch,
     pin order). x2 retimes ~0.42 ns after clk_ref (x7), dlf updates ~1.2 ns
     after it (`clk_dlf`, x8..x10) -- delay cells, they track PVT.
   - Flops resolve slowly: tau 56 ps tt / 100 ps ss (`make -C bbpd meta_char`).
     So `rtl/dlf.v` holds the code in Gray: an unresolved comp reaches only
     the <=2 bits in which code+-1 differ, and any outcome is within +-2 LSB.
     `synth/check_comp_cone.py` (run by the synthesis rule) checks that comp
     reaches the state only through and2 -> xor2.
   - lock_ctrl's load/seed (0.81 ns tt, 1.28 ss) are re-registered on clk_ref
     inside dlf: cycle-equivalent to before. Formal wrappers use `PREG=0`.
   - `pnr/base.sdc`: same-cycle captures onto clk_dlf are
     `set_multicycle_path 0 -setup`; x1 -> x2 has a max-delay and no hold
     check. OpenSTA on the unplaced netlist: met at tt/ss/ff.
   - Checks: `pd_sim` PASS (+85 ps offset unchanged), `fine_loop_sim` PASS
     (seed now 60, the fast side: a clearly late start is lock_ctrl's job),
     `mdll_mixed_sim` PASS -- code period 4 instead of 6, swing 253 ps (whole
     DCO steps until step 4).
4. **clk_gen dither.** The divider counts in Gray (Johnson counter; x3 gone,
   x4 a nor2b; `divn1` and the div/ICG path unchanged), and `rtl/dco_decode.v`
   adds unit N for the last code[1:0] periods of each run (`g[1:0]` from the
   divider through dco.sch). Glitch-free by construction: single gates with one
   changing input, and frac_on is 0 in period 0, where the code changes;
   `synth/check_dither_cone.py` (run by the synthesis rule) checks the mapped
   netlist. The SPICE model dithers too; `pnr/base.sdc`'s `divn1` clock is on
   x11.x4/Y now. lock_ctrl `STEP` 4 -> 2 (4 handed over two steps short at the
   slow corner once the TDC saw fractional codes).
   - Decoder: exhaustive, 256 codes x 4 periods, 4N + k unit-periods per run;
     LEC PASS. (`make sim_decode` needs iverilog, absent on this machine --
     run with Verilator.)
   - gate_check (tt): div 0.10 / 0.14 / 0.215 / 0.275 / 0.38 ns for codes
     72..76 -- monotonic quarter steps of 40..110 ps; x12 leads at code 0
     unchanged (250 / 411 / 152 ps).
   - `mdll_mixed_sim` (typ): PASS, handover cycle 32, code 74 <-> 75 every
     cycle, div - clk_ref_g +53..+115 ps: **62 ps pp, from 284**.
5. **Re-harden** (started 2026-10-29, in parallel with the step-4 fine loop).
   sg13g2:
   - Blocks: clk_gen `RUN_2026-10-29_14-11-15`, bbpd `RUN_2026-10-29_14-04-11`,
     lock_ctrl `RUN_2026-10-29_14-11-15` (tdc unchanged). DRC 0, LVS match,
     antenna/slew/cap 0, timing met at all corners. clk_gen and lock_ctrl now
     have absolute dies at their old sizes (they grew at 35 % utilisation and
     no longer fitted the top floorplan; ~44 % / ~41 % now). bbpd grew to
     92.9 x 96.5 um and moved down to y 22.68 (PDN-0179 otherwise).
   - bbpd: delay chains untouched, `clk_dlf` drives the 8 state flops
     directly, no hold buffers. Tightest: x2 -> dlf (same cycle) +24 ps at tt
     (+65 ss, +30 ff), with the 50 ps clock uncertainty already taken off.
     dlf's netlist got two buf_1 for aliased wires (`insbuf`: LibreLane
     rejects `assign`).
   - `output_delays.py --from-launch-clock` for bbpd (C[7:0] 0.75 ns from
     clk_dlf at tt), lock_ctrl from clk_ref as before; both regenerated.
   - Top `RUN_2026-10-29_14-13-52`: DRC 0, LVS match, timing met;
     `match_report` worst |clk_ref_g - div| 7.3 ps (gate 20): PASS.
     `build/layout/mdll_calibre.cdl` regenerated for Calibre.
   - Running: `mdll_mixed_sim` with the new delays, `layout_sim` (~4 h).
   CMOS5L: blocks `CMOS5L_2026-10-29_14-28-33`, top `CMOS5L_2026-10-29_14-31-13`:
   DRC 0, LVS match (current `sg13cmos5l.lvs`), timing met; `match_report_cmos5l`
   worst 10.8 ps: PASS; `build/sg13cmos5l/layout/mdll_calibre.cdl` written.
   The /opt PDK at 6ac9bb9d contains commit 23854a19, which moved the PDK's
   LibreLane config to the names of LibreLane's unreleased `dev` branch
   (`LIB` -> `CELL_LIBS`/`PAD_LIBS`, `KLAYOUT_*_OPTIONS` -> `*_DEFINES`);
   released LibreLane (main 64ef808, 3.0.16) still reads `LIB`. The CMOS5L
   runs therefore use `build/pdk_cmos5l` (`common/pnr/cmos5l_pdk.sh`): the
   installed PDK with `libs.tech/librelane` from 23854a19^. Drop it once
   LibreLane releases the new names.
   Calibre RC: re-extracted and running on cae02 since 2026-10-29, see
   "Re-extraction and runs of 2026-10-29" above.

## Things that are easy to get wrong

- **The clk_gen x12 injection race is not timed by STA.** It's a
  clk_ref → DCO-clock crossing, and only SPICE covers it
  (`clk_gen/simulations/gate_check.py --corner {typ,slow,fast}`: at lock_ctrl's
  START code (0x18) and above, x12/Q must rise on the first clk_outb edge
  after the release; leads 222/378/130 ps at tt/ss/ff with the inv_2 / cap_8
  ring). Below START it misses (8-bit ≤ 16 at ss, ≤ 8 at tt/ff) -- that is
  why acquisition starts at START, not 0x00. **Re-run it whenever clk_gen's
  schematic changes, and keep START above the miss region.** See the
  comments in `clk_gen/pnr/base.sdc` (its DCO periods are START's).
- **At ff, START (and code 0) does not gate.** The ring gives 8 edges and two `div` per
  reference period. It's harmless today: the TDC's slow ring starts on the
  first `div`, so the first reading is right, and the first jump leaves code 0.
  Any change to the acquisition start or to the TDC arming must keep that true.
- **The toolchain moves.** nix yosys went from 0.59 to 0.70 and re-maps
  `lock_ctrl` differently (LEC still passes). After a toolchain update, re-run
  `make lec` per block and commit regenerated SPICE models together with the
  layouts made from the same netlists.
- **Absolute paths** that must exist or be adapted on another machine:
  - None for the flow tools: the block Makefiles take them from PATH (the
    nix profile). `NIX_SHELL="nix develop <librelane checkout> -c"` runs them
    from a checkout's dev shell instead.
  - None for custom_stdcell since `a6808fa`: it is a separate repo,
    expected next to this one (`../custom_stdcell`; LibreLane `dir::` paths,
    relative paths in the scripts). It needs commit `33fd5af` or later
    (cap_8, and cap_4's VSS-rail contact on the site grid).
  - xschem: batch runs (every Makefile call) use `tools/xschemrc`, not the
    user's `~/.xschem/xschemrc`; it builds the symbol path from
    `PDK_ROOT`/`PDK`, this repo and `../custom_stdcell/xschem`.
  - The PDK at `/opt/IHP-Open-PDK/` (`PDK_ROOT`).
- **Versions.** The 2026-10-21 layouts and models: ngspice-45, Verilator
  5.052, yosys 0.70 (nix), librelane checkout `bf87321`. From 2026-10-22 the
  tools come from the nix profile (`~/.nix-profile/bin`): LibreLane 3.0.16
  (`01ddb25`), yosys 0.69+post, OpenROAD 26Q2, KLayout 0.30.12, Verilator
  5.048, ngspice-45. yosys 0.69 maps `lock_ctrl` to 345 cells (LEC PASS), so
  the next `make models` regenerates `lock_ctrl/simulations/lock_ctrl.spice`.
  Commit it together with the layouts re-hardened from the same netlist.
- **`.PARAM TEMP=28`** in the testbenches is only a parameter. ngspice runs at
  27 °C unless `.TEMP` is set.
