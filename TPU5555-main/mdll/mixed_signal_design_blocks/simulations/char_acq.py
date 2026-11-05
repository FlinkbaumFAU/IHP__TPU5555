#!/usr/bin/env python3
"""Open-loop acquisition timing: what the TDC measures when wired to clk_gen.

The coarse loop needs the frequency error as a time: the gap between clk_gen's
div edge (N=4 DCO periods after injection) and the next clk_ref edge,

    e = T_REF - 4*T_DCO          (> 0: ring too fast)

This drives test_acq.sch -- clk_gen at a fixed CODE feeding the TDC, no
feedback -- over a set of codes, one deck per code, and prints per TDC run:

    e       the true error, measured in the deck (div rise -> next clk_ref rise)
    dt      what the TDC's rings actually saw (slow start -> fast start)
    t_est   what the TDC reported: tdc_s*T_s - tdc_f*T_f

--clk / --sel rewire the TDC's Clk_out / Sel inputs to another clk_gen net in
the netlist copy, so candidate connections can be compared without redrawing
the schematic. Defaults are the connection mdll.sch uses.

Result at tt (2026-09-28): with Clk_out <- div, Sel <- clk_ref the TDC reads
dt = e - 30 ps at every fast code (0x00..0x40), slope 1, and R = T_s/LSB ~ 60.
With Clk_out <- clk_out, Sel <- sel it measures nothing: the gated ring does
not toggle between div and the injection, so the slow ring always starts late
and every run reports hit. On the slow side (0x48+) a run armed on a skipped
injection edge gives a large bogus reading -- why lock_ctrl arms on inj.
"""

import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tdc", "simulations"))
import rawread  # noqa: E402

BUILD = os.path.join(ROOT, "build", "char_acq")
V = 1.2
TH = V / 2
THREADS = 2
CODES = [0x00, 0x10, 0x20, 0x30, 0x40, 0x48, 0x50, 0x60]


def template():
    path = os.path.join(ROOT, "build", "test_acq.spice")
    if not os.path.exists(path):
        raise SystemExit(f"missing {path} -- run `make build/test_acq.spice`")
    return open(path).read()


def deck(code, tag, clk, sel):
    txt = template()
    subs = [(".PARAM CODE=0", f".PARAM CODE={code}"),
            ("  write $rawfile", f"  write {BUILD}/{tag}.raw"),
            # OSDI device evaluation is multithreaded and ignores
            # OMP_NUM_THREADS; cap it so parallel decks don't oversubscribe.
            ("  tran 5p", f"  set num_threads={THREADS}\n  tran 5p"),
            ("x2 div clk_ref clk_ref Start ", f"x2 {clk} clk_ref {sel} Start ")]
    for a, b in subs:
        if a not in txt:
            raise SystemExit(f"test_acq.spice no longer contains {a!r}")
        txt = txt.replace(a, b)
    return txt


def run(code, clk, sel, analyse_only=False):
    tag = f"{clk}_{sel}_{code:02x}"
    if not analyse_only:
        os.makedirs(BUILD, exist_ok=True)
        sp = os.path.join(BUILD, tag + ".spice")
        open(sp, "w").write(deck(code, tag, clk, sel))
        with open(sp[:-6] + ".log", "w") as log:
            subprocess.run(["ngspice", "-b", sp], stdout=log,
                           stderr=subprocess.STDOUT,
                           env=dict(os.environ, OMP_NUM_THREADS="1"), check=False)
    return analyse(code, tag)


def analyse(code, tag):
    raw = os.path.join(BUILD, tag + ".raw")
    if not os.path.exists(raw):
        return dict(code=code, err="no raw file")
    d = {(k[2:-1] if k.startswith("v(") else k).lower(): v
         for k, v in rawread.read(raw).items()}
    t = d["time"]
    ref = rawread.edges(t, d["clk_ref"], TH)
    div = rawread.edges(t, d["div"], TH)
    out = rawread.edges(t, d["clk_out"], TH)
    per = sorted(b - a for a, b in zip(out, out[1:]))
    t_dco = per[len(per) // 2] if per else float("nan")

    runs = []
    for tr in rawread.edges(t, d["x2.reset"], TH):
        tf_ = [x for x in rawread.edges(t, d["x2.reset"], TH, False) if x > tr]
        end = tf_[0] if tf_ else t[-1]
        os_ = [x for x in rawread.edges(t, d["x2.os"], TH) if tr < x < end]
        of_ = [x for x in rawread.edges(t, d["x2.of"], TH) if tr < x < end]
        # true error: the div edge after arming, to the clk_ref edge after it
        dv = [x for x in div if x > tr]
        rf = [x for x in ref if dv and x > dv[0]]
        e = (rf[0] - dv[0]) if dv and rf else float("nan")
        tq = end + 0.5e-9
        if tq > t[-1]:
            continue
        bus = {k: v for k, v in d.items() if k.startswith("tdc_")}
        s = rawread.word(bus, t, "tdc_s", 8, tq, TH)
        f = rawread.word(bus, t, "tdc_f", 8, tq, TH)
        hit = rawread.value_at(t, d["hit"], tq) > TH

        def period(ed):
            p = sorted(b - a for a, b in zip(ed, ed[1:]))
            return p[len(p) // 2] if p else float("nan")
        ts, tf = period(os_), period(of_)
        dt = (of_[0] - os_[0]) if os_ and of_ else float("nan")
        runs.append(dict(e=e, dt=dt, s=s, f=f, hit=hit, ts=ts, tf=tf,
                         t_est=s * ts - f * tf))
    return dict(code=code, t_dco=t_dco, runs=runs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--codes", type=lambda s: int(s, 0), nargs="*", default=CODES)
    ap.add_argument("--clk", default="div", help="net driving TDC Clk_out")
    ap.add_argument("--sel", default="clk_ref", help="net driving TDC Sel")
    ap.add_argument("-j", type=int, default=max(1, (os.cpu_count() or 2) // THREADS))
    ap.add_argument("--analyse-only", action="store_true")
    a = ap.parse_args()
    with ThreadPoolExecutor(a.j) as ex:
        res = list(ex.map(lambda c: run(c, a.clk, a.sel, a.analyse_only), a.codes))

    print(f"TDC Clk_out <- {a.clk}, Sel <- {a.sel}\n")
    print(f"{'code':>5} {'T_dco/ps':>8} {'4T/ps':>6} {'e/ps':>7} {'dt/ps':>7} "
          f"{'hit':>3} {'s':>4} {'f':>4} {'t_est/ps':>8} {'dt-e/ps':>8}")
    for r in res:
        if "err" in r:
            print(f"{r['code']:>#5x} {r['err']}")
            continue
        for x in r["runs"] or [{}]:
            if not x:
                print(f"{r['code']:>#5x} no completed TDC run")
                continue
            print(f"{r['code']:>#5x} {r['t_dco']*1e12:>8.0f} {4*r['t_dco']*1e12:>6.0f} "
                  f"{x['e']*1e12:>7.0f} {x['dt']*1e12:>7.0f} {int(x['hit']):>3} "
                  f"{x['s']:>4} {x['f']:>4} {x['t_est']*1e12:>8.0f} "
                  f"{(x['dt']-x['e'])*1e12:>8.0f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
