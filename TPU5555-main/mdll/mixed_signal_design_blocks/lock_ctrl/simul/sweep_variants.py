#!/usr/bin/env python3
"""Compare loop variants in tb_acq over sim_acq's PVT/TDC grid.

Each variant is a set of tb_acq plusargs (see the header of tb_acq.v). Every
variant runs over the same grid as `make sim_acq` and is summarised by its
PASS count, the runs that end with the code at 0x00/0xFF (only the forced
coarse overshoots, TDC_PCT=160: a ring more than T_REF/2 late aliases to
"early" in the pd), and the lock error after handover, div - clk_ref over the
last locked cycles: the peak-to-peak per run, then median, p90 and worst over
the TDC_PCT=100 runs.

Delays given in ps for tt (D_DLF, D_X2, MISS_PS) scale with DCO_PCT, as a
gate delay line would track the ring over PVT.

    simul/sweep_variants.py            # the standard variant table
    simul/sweep_variants.py --faults   # fault injection: DCO step after lock

Findings (2026-10-28, tb_acq with the ring model corrected to gate_check)
-------------------------------------------------------------------------
Lock error div - clk_ref, peak-to-peak, worst over the TDC_PCT=100 grid
at DCO 80 / 100 / 125 %:

    today (code[1:0] dropped, dlf on clk_ref)        256 / 315 / 376 ps
    dither alone                                      190 / 237 / 276
    dither + dlf 1.0 ns after clk_ref, first k periods 64 /  79 / 149
    dither + dlf 1.0 ns after clk_ref, LAST k periods  64 /  79 /  94

Today's 315 ps at tt matches the mixed-signal run (+110 / +380 ps, ~280).
Dithering alone gains little: the decision still reaches the code two runs
later and the loop cycles over 3 LSB. With the update early in the next run
it cycles over 1 LSB: one quarter DCO step. The dithered periods must be the
LAST k of the run: an LSB step k -> k+1 changes period 3-k only, so with the
first k it changes period k, which a later update misses (the 2-run cycle
returns). Some step has to change period 0 -- the 6-bit carry -- so the
update must land early in period 0: D_DLF <= ~1.2 ns at tt (scaled with
PVT). At 1.5 ns the carry is already weak (worst 119 ps at tt), at 2.25 ns
232 ps.

Out of lock (FAULT_PCT: the DCO steps after lock, inj = clk_gen's sel):

    fault    none / rail 8   inj 2   bbpd late flag
     70 %       108/108     108/108     108/108     (faster: walks back)
    115 %        57/108     108/108     108/108
    125 %         0/108     108/108      57/108
    140 %         0/108     108/108       0/108
    160 %         0/108      72/108       0/108     (the 36: 200 % total,
                                                     out of range at 0x00)

A slowed ring mostly does NOT run to a rail: it finds a false lock (e.g.
4*T_DCO ~ 1.5*T_REF, divs alternating between rising and falling edges, the
pd split between early and late) anywhere mid-range. The late flag only
fixes small steps. What does identify it: in a real lock every clk_ref edge
injects; a ring late by more than ~T_DCO/2 only glitches sel in the high
half. "inj 2" restarts acquisition after 2 locked edges without injection,
counted until 16 consecutive edges inject (in a false lock every other edge
still injects, so consecutive misses are not enough). It relocks in 15..32
cycles, never fires in the normal grid (0 of 108 restarted), and needs
nothing but lock_ctrl's existing inj input. The rail check is still needed
for a ring out of range at either end, where every edge injects. Both are now
lock_ctrl's FINE-state restart (rtl/lock_ctrl.v: MISS=2, CLR=16, RAIL=8), and
--faults runs against it; the table above came from the same detector
modelled in tb_acq, and the RTL reproduces it (relock in 17..33 cycles).
"""

import argparse
import itertools
import os
import re
import statistics
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.join(HERE, "..", "build", "obj_tb_acq", "tb_acq")
SCALED = ("D_DLF", "D_X2", "MISS_PS", "D_CODE")

# The loop as built (step 3/4): tail dither; x2 0.42 ns and dlf 1.2 ns after
# clk_ref, code at the cap bank 1.3 ns after dlf's clock (tt; all scale with
# DCO_PCT). Step 1 had settled on dlf at 1.0 ns, x2 at 0.5 ns, no D_CODE.
CANDIDATE = {"DITHER": 2, "D_X2": 420, "D_DLF": 1200, "D_CODE": 1300}

VARIANTS = [
    ("today",                       {}),
    ("dither",                      {"DITHER": None}),
    ("D_DLF=2250",                  {"D_DLF": 2250}),
    ("dither D_DLF=1500",           {"DITHER": None, "D_DLF": 1500}),
    ("dither D_DLF=2250",           {"DITHER": None, "D_DLF": 2250}),
    ("dither D_DLF=3000",           {"DITHER": None, "D_DLF": 3000}),
    ("tail dither",                 {"DITHER": 2}),
    ("tail dither D_DLF=1500",      {"DITHER": 2, "D_DLF": 1500}),
    ("tail dither D_DLF=2250",      {"DITHER": 2, "D_DLF": 2250}),
    ("tail dither D_DLF=3000",      {"DITHER": 2, "D_DLF": 3000}),
    ("tail dither D_DLF=4000",      {"DITHER": 2, "D_DLF": 4000}),
    ("tail dither D_DLF=5000",      {"DITHER": 2, "D_DLF": 5000}),
    ("tail dither D_DLF=1000 D_X2=500", {"DITHER": 2, "D_DLF": 1000, "D_X2": 500}),
    ("as built (CANDIDATE)",        CANDIDATE),
]


# Fault injection: lock, then step the DCO by FAULT_PCT (70: faster). With MISS_PS the
# slowed ring loses div; x1 keeps its last decision. The bbpd is modelled
# without a late flag; lock_ctrl's own restart (rtl/lock_ctrl.v) recovers.
DETECTORS = [
    ("lock_ctrl restart",            {}),
    ("lock_ctrl restart + late flag", {"LATE_FLAG": None}),
]
FAULTS = [
    (f"fault {f:3d}% at +{c}, detector: {dn}",
     dict(CANDIDATE, MISS_PS=3500, FAULT_PCT=f, FAULT_CYC=c, **dv))
    for f in (115, 125, 140, 160, 70) for dn, dv in DETECTORS for c in (40,)
]


def grid():
    """The sim_acq grid (lock_ctrl/Makefile)."""
    for pct, lsb, dinj, tbuf, tdc in itertools.product(
            (80, 100, 125), (14, 17, 21), (200, 330, 500), (30, 60, 150, 300), (100, 160)):
        ts = 1064 * pct // 100
        yield dict(DCO_PCT=pct, T_S=ts, T_F=ts - lsb * pct // 100,
                   D_INJ=dinj, T_BUF=tbuf, TDC_PCT=tdc)


def run(args):
    out = subprocess.run([BIN] + args, capture_output=True, text=True).stdout
    res = re.search(r"^(PASS|FAIL):", out, re.M)
    st = re.search(r"^STAT: code8 (\d+)\.\.(\d+) err (-?\d+)\.\.(-?\d+) ps pp (-?\d+), (\d+) restarts, settled at (-?\d+)(.*)$", out, re.M)
    fails = re.findall(r"^FAIL: (?!D_INJ).*$", out, re.M)
    return dict(ok=res and res.group(1) == "PASS", fails=fails,
                pp=int(st.group(5)) if st else None,
                code=(int(st.group(1)), int(st.group(2))) if st else None,
                restarts=int(st.group(6)) if st else 0,
                settle=int(st.group(7)) if st else -1,
                tail=st.group(8).strip(" |") if st else "")


def plusargs(base, var):
    a = [f"+{k}={v}" for k, v in base.items()]
    for k, v in var.items():
        if v is None:
            a.append(f"+{k}")
        else:
            a.append(f"+{k}={v * base['DCO_PCT'] // 100 if k in SCALED else v}")
    if "D_DLF" in var and "D_X2" not in var:
        a.append(f"+D_X2={1000 * base['DCO_PCT'] // 100}")
    return a


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--faults", action="store_true", help="run the fault-injection table")
    ap.add_argument("-j", type=int, default=os.cpu_count())
    a = ap.parse_args()
    if not os.path.exists(BIN):
        sys.exit(f"missing {BIN} -- run `make -C lock_ctrl {os.path.relpath(BIN, os.path.join(HERE, '..'))}`")

    table = FAULTS if a.faults else VARIANTS
    pts = list(grid())
    if a.faults:      # TDC over-reporting is an acquisition test, not needed here
        pts = [p for p in pts if p["TDC_PCT"] == 100]
    with ThreadPoolExecutor(a.j) as ex:
        for name, var in table:
            rs = list(ex.map(run, [plusargs(p, var) for p in pts]))
            npass = sum(r["ok"] for r in rs)
            rail = [r for r in rs if r["code"] and {0, 255} & set(r["code"])]
            # Swing statistics: TDC_PCT=100 runs that locked off the rails.
            pps = sorted(r["pp"] for r, q in zip(rs, pts)
                         if r["pp"] is not None and r not in rail and q["TDC_PCT"] == 100)
            nrst = sum(r["restarts"] > 0 for r in rs)
            line = f"{name:44s} {npass:3d}/{len(rs)} pass {len(rail):3d} at a rail {nrst:3d} restarted"
            if pps:
                line += (f"  err pp median {statistics.median(pps):4.0f} ps"
                         f"  p90 {pps[int(0.9 * (len(pps) - 1))]:4d}  worst {pps[-1]:4d}")
            print(line, flush=True)
            reasons = {}
            for r in rs:
                for f in r["fails"]:
                    f = re.sub(r"\d+", "#", f)
                    reasons[f] = reasons.get(f, 0) + 1
            for f, n in sorted(reasons.items(), key=lambda x: -x[1]):
                print(f"    {n:3d}x {f}")
            if a.faults:
                tails = [r["tail"] for r in rs if r["tail"]]
                if tails:
                    rec = [int(m.group(1)) for t in tails if (m := re.search(r"relocked (-?\d+)", t))]
                    rst = [r["restarts"] for r in rs]
                    print(f"    restarts {min(rst)}..{max(rst)}, relock after "
                          f"{min(rec)}..{max(rec)} cycles (pass runs counted only if relocked)")


if __name__ == "__main__":
    main()
