#!/usr/bin/env python3
"""Metastability of the pd's flops: clock-to-Q vs. data-to-clock offset.

Why: pd.sch's x1 samples clk_ref on div, and at lock the two edges coincide by
design, so x1 sits in its metastability window as a matter of routine. x2
retimes x1 before dlf's eight flops use it. Today x2 waits half a reference
period (~5 ns). Updating the code within the next run (lock_ctrl's
simul/sweep_variants.py, step 1) needs x2 and dlf's clock ~0.5..1.5 ns after
clk_ref instead, so the resolution time becomes the design constraint.

What: N copies of one flop, each with a data edge at its own offset dt from
the clock edge (dt < 0: data first). Each round finds the pair of offsets
between which Q stops capturing, then the next round spreads N new points
across that bracket, so the bracket shrinks by ~N per round down to the
femtoseconds. Clock-to-Q of every capture is kept. In the metastable region

    t_cq(dt) = t_r - tau * ln|dt - dt0|

and tau (the resolution time constant) and the aperture follow from a fit.
Tolerances are tightened (RELTOL 1e-7; ABSTOL 1e-16 stops the deck at its first
timepoint): the difference between neighbouring
points ends up as micro- to nanovolts on the sampling node, which the
latch then amplifies.

    ./simulations/char_meta.py                     # dfrbpq_1, dfrbpq_2; typ, slow
    ./simulations/char_meta.py --cells dfrbpq_1 --corners slow
    make meta_char                                 # the same, into build/char_meta.txt

Findings (2026-10-29)
---------------------
                  t_cq nominal   switching point     tau
    tt  1.20 V       150..160 ps   data 91..94 ps    52..61 ps
    ss  1.08 V       230..250 ps   data 150..155 ps  100..110 ps
                                   before the clock

Both flop sizes alike; the fits are clean log-linear over ten decades of
|dt - dt0| (local slope 55..56 ps at tt). That tau is long: a binary dlf
clocked ~1.5 ns after clk_ref would see an unresolved comp ~10^2..10^3 times
a second at lock, and in binary a half-resolved +-1 can land anywhere (0x7F ->
0x00..0xFF). Hence rtl/dlf.v's Gray state, which bounds that to +-2 LSB.
"""

import argparse
import math
import os
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "simulations"))
from gen_mixed import CORNERS  # noqa: E402

PDK = os.environ.get("PDK_ROOT", "/opt/IHP-Open-PDK/").rstrip("/") + "/ihp-sg13g2"
T_C = 1e-9          # the clock edge under test (50 % point)
CT = 50e-12         # clock and data 0-100 % ramps: buffer-driven nets
N = 16              # copies per round
ROUNDS = 13
T_END = 3e-9


def deck(cell, corner, dts, edge):
    lib, vdd, temp = CORNERS[corner]
    hi, lo = (vdd, 0) if edge == "rise" else (0, vdd)
    L = [f"* {cell} metastability, {corner}, data {edge}",
         f".LIB {PDK}/libs.tech/ngspice/models/cornerMOSlv.lib {lib}",
         ".OPTIONS KLU RELTOL=1e-7 VNTOL=1e-9 ABSTOL=1e-14",
         f".INCLUDE {PDK}/libs.ref/sg13g2_stdcell/spice/sg13g2_stdcell.spice",
         f".TEMP {temp}",
         f"VDD vdd 0 {vdd}",
         # a first clock at 0.3 ns captures data's initial level, so Q
         # starts opposite to the level under test
         f"VCK ck 0 PWL(0 0 0.28n 0 0.33n {vdd} 0.6n {vdd} 0.65n 0 "
         f"{T_C - CT / 2:.6e} 0 {T_C + CT / 2:.6e} {vdd})",
         f"VRB rb 0 {vdd}"]
    for i, dt in enumerate(dts):
        t0 = T_C + dt - CT / 2
        L += [f"VD{i} d{i} 0 PWL(0 {lo} {t0:.15e} {lo} {t0 + CT:.15e} {hi})",
              f"X{i} q{i} ck d{i} rb vdd 0 sg13g2_{cell}",
              # Q drives one more flop's D in the pd (x1 -> x2)
              f"XL{i} ql{i} ck q{i} rb vdd 0 sg13g2_dfrbpq_1"]
    L += [".control", "  set num_threads=1", f"  tran 0.5p {T_END:g} 0 0.5p"]
    want = "RISE" if edge == "rise" else "FALL"
    for i in range(len(dts)):
        L.append(f"  meas tran t{i} WHEN v(q{i})={vdd / 2} {want}=LAST")
    L += ["  quit", ".endc", ".end"]
    return "\n".join(L) + "\n"


def run(cell, corner, dts, edge):
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "m.spice")
        open(p, "w").write(deck(cell, corner, dts, edge))
        out = subprocess.run(["ngspice", "-b", p], stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, cwd=d).stdout
    res = []
    for i, dt in enumerate(dts):
        m = re.search(rf"^t{i}\s*=\s*([-+0-9.eE]+)", out, re.M)
        t = float(m.group(1)) if m else None
        res.append((dt, t - T_C if t is not None and t > T_C else None))
    return res


def characterise(cell, corner, edge):
    lo, hi = -300e-12, 300e-12     # captured at lo, missed at hi
    pts = []
    for _ in range(ROUNDS):
        dts = [lo + (hi - lo) * k / (N - 1) for k in range(N)]
        r = run(cell, corner, dts, edge)
        pts += [x for x in r if x[1] is not None]
        cap = [dt for dt, t in r if t is not None]
        miss = [dt for dt, t in r if t is None]
        if not cap or not miss:
            break
        lo = max(cap)
        hi = min(x for x in miss if x > lo) if any(x > lo for x in miss) else hi
    dt0 = (lo + hi) / 2
    pts.sort()
    t_nom = min(t for _, t in pts)
    # Fit the metastable part: t_cq more than 30 ps above nominal, below where
    # the bracket stopped resolving.
    fit = [(math.log(dt0 - dt), t) for dt, t in pts if dt < dt0 and t > t_nom + 30e-12]
    if len(fit) >= 3:
        n = len(fit)
        mx = sum(x for x, _ in fit) / n
        my = sum(y for _, y in fit) / n
        sxx = sum((x - mx) ** 2 for x, _ in fit)
        sxy = sum((x - mx) * (y - my) for x, y in fit)
        tau = -sxy / sxx
        t_r = my + tau * mx     # t_cq at |dt - dt0| = 1 s (extrapolated constant)
    else:
        tau = t_r = float("nan")
    return dict(cell=cell, corner=corner, edge=edge, dt0=dt0, bracket=hi - lo,
                t_nom=t_nom, t_max=max(t for _, t in pts), tau=tau, t_r=t_r, npts=len(fit),
                pts=pts)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cells", nargs="+", default=["dfrbpq_1", "dfrbpq_2"])
    ap.add_argument("--corners", nargs="+", default=["typ", "slow"])
    ap.add_argument("--edges", nargs="+", default=["rise", "fall"])
    ap.add_argument("-v", action="store_true", help="print every point")
    a = ap.parse_args()
    jobs = [(c, k, e) for c in a.cells for k in a.corners for e in a.edges]
    with ThreadPoolExecutor(min(len(jobs), os.cpu_count())) as ex:
        res = list(ex.map(lambda j: characterise(*j), jobs))
    print(f"{'cell':10s} {'corner':6s} {'data':5s} {'dt0 ps':>8s} {'t_cq nom':>9s} "
          f"{'t_cq max':>9s} {'tau ps':>7s}  points  bracket")
    for r in res:
        print(f"{r['cell']:10s} {r['corner']:6s} {r['edge']:5s} {r['dt0'] * 1e12:8.1f} "
              f"{r['t_nom'] * 1e12:8.0f}p {r['t_max'] * 1e12:8.0f}p {r['tau'] * 1e12:7.1f}  "
              f"{r['npts']:6d}  {r['bracket']:.1e}")
        if a.v:
            for dt, t in r["pts"]:
                print(f"    dt-dt0 {dt - r['dt0']:+.3e}  t_cq {t * 1e12:7.1f} ps")


if __name__ == "__main__":
    main()
