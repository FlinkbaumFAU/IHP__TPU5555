#!/usr/bin/env python3
"""TDC arming vs. a nearby Clk_out edge: which edge starts the slow ring?

The TDC arms on Sel: x8 toggles, x9 raises Reset (= busy), and x6 -- clocked by
Clk_out (div in the MDLL), held in reset until then -- starts the slow ring on
the FIRST Clk_out edge after Reset rises. An edge just before the release must
be ignored, one just after it taken; in between x6 sees a recovery/removal
race. In the closed loop that matters for a stale div near lock_ctrl's arming:
taken by mistake, it starts the slow ring early, reads a too-large error and
over-corrects onto the slow side.

This sweeps where a Clk_out edge falls relative to the arming, per corner:

    Sel      rises at 1.15 ns (one pulse), Start long high before
    Clk_out  first rise at D, then every 2.5 ns       D is swept
    Clk_ref  rises at 7 ns, well after every candidate edge

and reports, relative to Reset's rise (busy follows it through one buf_1):

    tau*     the edge offset where the TDC switches from ignoring the edge at
             D (and starting on D + 2.5 ns) to starting on it; bisected
    start    Clk_out edge -> first slow-ring edge, which grows near tau* if x6
             goes metastable

Compare tau* with how far the closed loop's div edges are from busy's rise
(--closed-loop RAW...): the margin is that distance minus tau*.
"""

import argparse
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import rawread  # noqa: E402

BUILD = os.path.join(ROOT, "build", "arm_margin")
# SPICE twins of the STA signoff corners, as in simulations/gen_mixed.py.
CORNERS = {"typ": ("mos_tt", 1.20, 27), "slow": ("mos_ss", 1.08, 125),
           "fast": ("mos_ff", 1.32, -40)}
T_SEL = 1.15e-9
T_CO = 2.5e-9


def template():
    path = os.path.join(ROOT, "build", "test_tdc.spice")
    if not os.path.exists(path):
        raise SystemExit(f"missing {path} -- run `make build/test_tdc.spice`")
    return open(path).read()


def tag(corner, d):
    return f"{corner}_{round(d * 1e15)}fs"


def deck(corner, d):
    lib, vdd, temp = CORNERS[corner]
    txt = template()
    for pat, new in [
            (r"(?m)^\.LIB cornerMOSlv\.lib mos_tt$", f".LIB cornerMOSlv.lib {lib}"),
            (r"(?m)^\.PARAM VDD=1\.2$", f".PARAM VDD={vdd:g}"),
            (r"(?m)^\.TEMP 27$", f".TEMP {temp:g}"),
            (r"(?m)^(VCO Clk_out VSS PULSE\(0 \{VDD\}) 1n ",
             rf"\g<1> {d * 1e9:.4f}n "),
            (r"(?m)^(VREF Clk_ref VSS PULSE\(0 \{VDD\}) \{3\.5n\+DT\} ", r"\g<1> 7n "),
            (r"(?m)^(VSEL Sel VSS PULSE\(0 \{VDD\} 1\.15n \{CT\} \{CT\} 0\.4n) 10n\)$",
             r"\g<1> 100n)"),
            (r"(?m)^  tran 5p \S+$", "  set num_threads=1\n  tran 2p 9n"),
            (r"(?m)^  write \$rawfile$", f"  write {BUILD}/{tag(corner, d)}.raw")]:
        txt, n = re.subn(pat, new, txt)
        if n != 1:
            raise SystemExit(f"test_tdc.spice: expected one line matching {pat} -- "
                             "update arm_margin.py to match test_tdc.sch")
    return txt


def run(corner, d):
    os.makedirs(BUILD, exist_ok=True)
    sp = os.path.join(BUILD, tag(corner, d) + ".spice")
    open(sp, "w").write(deck(corner, d))
    with open(sp[:-6] + ".log", "w") as log:
        subprocess.run(["ngspice", "-b", sp], stdout=log, stderr=subprocess.STDOUT,
                       env=dict(os.environ, OMP_NUM_THREADS="1"), check=False)
    raw = sp[:-6] + ".raw"
    if not os.path.exists(raw):
        raise SystemExit(f"no raw file for {sp} -- see its .log")
    d_ = {(k[2:-1] if k.startswith("v(") else k).lower(): v
          for k, v in rawread.read(raw).items()}
    t = d_["time"]
    th = CORNERS[corner][1] / 2
    rst = rawread.edges(t, d_["x1.reset"], th)
    busy = rawread.edges(t, d_["busy"], th)
    co = rawread.edges(t, d_["clk_out"], th)
    if not rst:
        raise SystemExit(f"{sp}: the TDC never armed")
    os_ = [x for x in rawread.edges(t, d_["x1.os"], th) if x > rst[0]]
    if not os_:
        raise SystemExit(f"{sp}: the slow ring never started")
    trig = max(x for x in co if x < os_[0])
    return dict(d=d, t_rst=rst[0], t_busy=busy[0] if busy else float("nan"),
                edge=co[0], taken=abs(trig - co[0]) < 1e-12,
                start=os_[0] - trig)


def sweep(corner, j, step=100e-12, lo=0.2e-9, hi=1.6e-9, res=2e-12):
    """Grid of edge offsets from Sel, then bisection between the last edge
    ignored and the first taken."""
    offs = [lo + i * step for i in range(round((hi - lo) / step) + 1)]
    with ThreadPoolExecutor(j) as ex:
        grid = list(ex.map(lambda o: run(corner, T_SEL + o), offs))
    flip = [(a, b) for a, b in zip(grid, grid[1:]) if not a["taken"] and b["taken"]]
    if len(flip) != 1 or any(g["taken"] for g in grid[:grid.index(flip[0][0])]):
        print(f"{corner}: no single ignore->take transition on the grid:")
        for g in grid:
            print(f"  edge {((g['d'] - T_SEL) * 1e12):7.0f} ps after Sel: "
                  f"{'taken' if g['taken'] else 'ignored'}")
        return None, grid
    a, b = flip[0]
    pts = [a, b]
    while b["d"] - a["d"] > res:
        m = run(corner, (a["d"] + b["d"]) / 2)
        pts.append(m)
        a, b = (m, b) if not m["taken"] else (a, m)
    return (a, b), grid + pts


def closed_loop(path, tau_busy):
    """div edges nearest each arming (busy rise) in a closed-loop raw."""
    d_ = {(k[2:-1] if k.startswith("v(") else k).lower(): v
          for k, v in rawread.read(path).items()}
    t = d_["time"]
    th = max(d_["clk_ref"]) / 2
    div = rawread.edges(t, d_["x1.div"], th)
    print(f"\n{os.path.relpath(path, ROOT)}: div edges around each arming "
          "(busy rise), and the distance to tau*")
    for tb in rawread.edges(t, d_["x1.busy"], th):
        before = [x for x in div if x <= tb]
        after = [x for x in div if x > tb]
        pb = (before[-1] - tb) * 1e12 if before else float("nan")
        pa = (after[0] - tb) * 1e12 if after else float("nan")
        line = (f"  busy rises {tb * 1e9:8.2f} ns: div {pb:+8.0f} ps before, "
                f"{pa:+8.0f} ps after")
        if tau_busy is not None:
            # the edge before must stay ignored, the edge after be taken
            line += (f"   margins: {tau_busy - pb:+7.0f} / {pa - tau_busy:+7.0f} ps")
        print(line)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corners", nargs="*", default=list(CORNERS), choices=list(CORNERS))
    ap.add_argument("-j", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--closed-loop", nargs="*", default=[], metavar="RAW",
                    help="closed-loop raw files (test_mdll*.raw) to measure; "
                         "compared against the first corner's tau*")
    a = ap.parse_args()

    taus = {}
    for c in a.corners:
        res, pts = sweep(c, a.j)
        if res is None:
            continue
        ign, take = res
        lat = ign["t_rst"] - T_SEL
        buf = ign["t_busy"] - ign["t_rst"]
        tau = (ign["edge"] + take["edge"]) / 2 - take["t_rst"]
        taus[c] = tau - buf  # relative to busy instead of Reset
        near = sorted(pts, key=lambda p: abs(p["edge"] - take["edge"]))[:6]
        print(f"{c:4s} ({CORNERS[c][0]}, {CORNERS[c][1]:g} V, {CORNERS[c][2]:g} C): "
              f"Sel -> Reset {lat * 1e12:.0f} ps, Reset -> busy {buf * 1e12:.0f} ps")
        print(f"     tau* = {tau * 1e12:+.0f} ps after Reset rises "
              f"({taus[c] * 1e12:+.0f} ps after busy): an edge earlier is ignored, "
              "later is taken")
        far = [p["start"] for p in pts if abs(p["edge"] - take["edge"]) > 50e-12 and p["taken"]]
        print(f"     edge -> slow-ring start: {min(far) * 1e12:.0f} ps away from tau*, "
              + ", ".join(f"{p['start'] * 1e12:.0f}" for p in near if p["taken"])
              + " ps at it")
    for r in a.closed_loop:
        closed_loop(r, taus[a.corners[0]] * 1e12 if a.corners[0] in taus else None)
    return 0


if __name__ == "__main__":
    sys.exit(main())
