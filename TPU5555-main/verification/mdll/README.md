# Verification of the MDLL hard macro

The chip LVS compares the MDLL (`mdll`, `Flow/scripts/LibreLane/ip/mdll/`) as a black box:
its pins and the chip nets on them only. Its insides were verified on their own. These
files are copies of those results, from the build the macro was packaged from (cae02,
mixed_signal_design_blocks `a6808fa`, IHP-Open-PDK `3f66c91`; `top/ip_SOURCE.txt`).

| Check | Result | File |
| --- | --- | --- |
| Blocks (clk_gen, tdc, bbpd, lock_ctrl), LibreLane: KLayout DRC, LVS, routing DRC, antenna, setup/hold | all 0 violations, timing met | `blocks_cmos5l.txt` |
| Top level `CMOS5L_2026-11-04_14-21-44`, LibreLane: KLayout DRC, LVS, antenna, setup/hold | 0 / match / 0 / met (+3.00 / +0.21 ns) | `top/metrics.json`, `top/klayout-drc.log`, `top/reports/drc.klayout.lyrdb`, `top/klayout-lvs.log`, `top/reports/lvs.klayout.lvsdb.xz`, `top/sta/summary.rpt` |
| Full PDK DRC (`run_drc.py`, maximal deck, flat, without density) | 0 items | `top/drc_full/` |
| Replica matching: `div` vs `clk_ref_g` at the tdc/bbpd pins, all corners | worst 8.6 ps (gate 20 ps) | `build_log/match.log` |
| Calibre LVS of the macro GDS against its CDL (IHP sg13g2 deck: the stack is identical up to Metal4, the macro's top layer) | CORRECT | `calibre_lvs.report` |
| Reproducibility: the same build on two machines with different PDK checkouts | KLayout XOR: 0 differing layers in every block and the top level | `reproducibility_xor.txt` |
| In the chip: the `mdll` cell of `release/v.2.0.0/gds/TPU5555.gds` against `ip/mdll/gds/mdll.gds` | see `../lvs/release_v.2.0.0/hard_ip_vs_pdk.txt` | |
| Closed loop on the Calibre RC netlist (R+C+CC), 100 MHz and a 70–150 MHz sweep at tt/ss/ff | in progress, state in `pex_status_2026-11-05.txt` | |

The design history, earlier simulation results (transistor level, layout-extracted,
mixed-signal) and the open points are in `../../mdll/mixed_signal_design_blocks/TAPEOUT.md`.

## Known limitations at tape-out

- **Lock range at the slow corner.** The PEX sweep fails at ss (mos_ss, 1.08 V, 125 °C) for
  134–150 MHz. The ring is already too slow at the start code (0x18): the TDC hands over at
  once, and the missed-injection restart fires before the bang-bang loop has walked the code
  down, so acquisition restarts every 9–12 cycles. tt and ff lock up to 150 MHz (ff at 139 and
  150 MHz: PASS, swing about 70 ps pp). The ss limit lies between the last runs that handed
  over (118–123 MHz) and 134 MHz. The runs still going will narrow it down. At 100 MHz
  every corner locks.
- **Chip fill inside the MDLL outline.** The chip's KLayout filler placed metal fill
  (16–35 % on Metal1–TopMetal1) and Activ/GatPoly fill inside the macro's area. The Calibre
  extraction above is of the macro without that fill, so on the chip the ring nodes see
  some extra capacitance. That slows the ring and lowers the ss limit further. The macro
  carries no fill-blocking layers; adding them needs a new chip run.
