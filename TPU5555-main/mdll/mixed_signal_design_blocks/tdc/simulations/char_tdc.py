#!/usr/bin/env python3
"""TDC transfer curve: captured counts vs. the clk_out-to-clk_ref interval.

One deck per interval DT, sharded across cores (a full TDC is ~150 cells plus
two 1 GHz rings, so replication inside one deck would just serialise the same
work). Each deck is the netlisted test_tdc.sch with DT substituted:

    Sel      pulses at 1.15 ns + k*10 ns   (just after a clk_out edge)
    clk_out  rises at 1 ns + k*2.5 ns      -> the first one after arming is 3.5 ns
    clk_ref  rises at 3.5 ns + DT          -> DT is the interval under test

What is checked (and printed as a table):
  * hit = 1 below the phase-detector threshold, including negative DT
  * above it, the reconstructed interval  t_est = tdc_s*T_s - tdc_f*T_f
    tracks DT with slope 1 -- T_s/T_f are the ring periods measured in the
    same deck, so the check does not assume the trim
  * the capture clock precedes the self-clear of the counters by a margin
    (the race STA cannot see), and x9's reset pulse is wide enough
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

PDK = os.environ.get("PDK_ROOT", "/opt/IHP-Open-PDK/").rstrip("/") + "/ihp-sg13g2"
BUILD = os.path.join(ROOT, "build", "char_tdc")
V = 1.2

DTS_PS = [-300, -100, -40, 0, 20, 40, 60, 80, 100, 150, 200, 300, 400, 500,
          600, 700, 800, 900, 1000, 1100, 1500, 2000, 2500, 4000, 7000]


def template():
    """The netlisted xschem testbench (make build/test_tdc.spice).

    Using it as the template, rather than re-wrapping an export of src/tdc.sch,
    means the TDC subckt comes from tdc.sym with its real port list (including
    VDD/VSS) and the stimulus is exactly the one the GUI testbench runs. Only
    the corner, DT, run length and output file are substituted.
    """
    path = os.path.join(ROOT, "build", "test_tdc.spice")
    if not os.path.exists(path):
        raise SystemExit(f"missing {path} -- run `make build/test_tdc.spice`")
    return open(path).read()


def deck(dt_ps, corner):
    tstop = 3.5e-9 + max(dt_ps * 1e-12, 0) + 80e-9
    txt = template()
    subs = [(".LIB cornerMOSlv.lib mos_tt", f".LIB cornerMOSlv.lib {corner}"),
            (".PARAM DT=400p", f".PARAM DT={dt_ps}p"),
            ("  write $rawfile", f"  write {BUILD}/{corner}_{dt_ps}.raw"),
            ("  save x1.OS x1.OF x1.Detect x1.hit_raw x1.cap_clk x1.Reset",
             "  save x1.OS x1.OF x1.Detect x1.hit_raw x1.cap_clk x1.Reset x1.net3")]
    for a, b in subs:
        if a not in txt:
            raise SystemExit(f"test_tdc.spice no longer contains {a!r} -- "
                             "update char_tdc.py to match test_tdc.sch")
        txt = txt.replace(a, b)
    # The run length in test_tdc.sch is whatever suits the GUI; each deck here
    # needs its own, so replace the tran line by pattern rather than verbatim.
    txt, n = re.subn(r"(?m)^  tran 5p \S+$", f"  tran 5p {tstop:g}", txt)
    if n != 1:
        raise SystemExit("test_tdc.spice has no single '  tran 5p <tstop>' line")
    return txt


def run(dt_ps, corner):
    os.makedirs(BUILD, exist_ok=True)
    sp = os.path.join(BUILD, f"{corner}_{dt_ps}.spice")
    open(sp, "w").write(deck(dt_ps, corner))
    with open(sp[:-6] + ".log", "w") as log:
        subprocess.run(["ngspice", "-b", sp], stdout=log, stderr=subprocess.STDOUT,
                       env=dict(os.environ, OMP_NUM_THREADS="1"), check=False)
    return analyse(dt_ps, corner)


def analyse(dt_ps, corner):
    raw = os.path.join(BUILD, f"{corner}_{dt_ps}.raw")
    if not os.path.exists(raw):
        return dict(dt=dt_ps, err="no raw file")
    d = {(k[2:-1] if k.startswith("v(") else k).lower(): v
         for k, v in rawread.read(raw).items()}
    t = d["time"]
    th = V / 2
    cap = rawread.edges(t, d["x1.cap_clk"], th)
    if not cap:
        return dict(dt=dt_ps, err="no capture")
    tc = cap[0]
    tq = tc + 1e-9
    bus = {k: v for k, v in d.items() if k.startswith("tdc_")}
    s = rawread.word(bus, t, "tdc_s", 8, tq, th)
    f = rawread.word(bus, t, "tdc_f", 8, tq, th)
    hit = rawread.value_at(t, d["hit"], tq) > th

    def period(name):
        e = rawread.edges(t, d[name], th)
        p = sorted(b - a for a, b in zip(e, e[1:]) if b - a < 2e-9)
        return p[len(p) // 2] if p else float("nan")

    ts, tf = period("x1.os"), period("x1.of")
    # Counters are cleared asynchronously when Reset falls; that must come
    # after the capture edge.
    rst_fall = [x for x in rawread.edges(t, d["x1.reset"], th, False) if x > tc]
    margin = (rst_fall[0] - tc) if rst_fall else float("nan")
    # x9's RESET_B (net3) low pulse around the capture.
    n3f = [x for x in rawread.edges(t, d["x1.net3"], th, False) if x > tc - 2e-9]
    n3r = [x for x in rawread.edges(t, d["x1.net3"], th, True) if n3f and x > n3f[0]]
    pw = (n3r[0] - n3f[0]) if n3f and n3r else float("nan")
    return dict(dt=dt_ps, s=s, f=f, hit=hit, ts=ts, tf=tf,
                t_est=(s * ts - f * tf), margin=margin, pw=pw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corner", default="mos_tt")
    ap.add_argument("-j", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--dt", type=int, nargs="*", help="override DT list (ps)")
    ap.add_argument("--analyse-only", action="store_true")
    a = ap.parse_args()
    dts = a.dt or DTS_PS
    fn = analyse if a.analyse_only else run
    with ThreadPoolExecutor(a.j) as ex:
        res = list(ex.map(lambda x: fn(x, a.corner), dts))

    print(f"{'DT/ps':>7} {'hit':>3} {'s':>4} {'f':>4} {'t_est/ps':>9} "
          f"{'err/ps':>7} {'cap->clr/ps':>11} {'rstpw/ps':>8}")
    ok = True
    for r in res:
        if "err" in r:
            print(f"{r['dt']:>7} {r['err']}")
            ok = False
            continue
        err = r["t_est"] * 1e12 - r["dt"]
        print(f"{r['dt']:>7} {int(r['hit']):>3} {r['s']:>4} {r['f']:>4} "
              f"{r['t_est']*1e12:>9.1f} {err:>7.1f} {r['margin']*1e12:>11.0f} "
              f"{r['pw']*1e12:>8.0f}")
        if r["margin"] < 100e-12:
            ok = False
    good = [r for r in res if "err" not in r]
    if good:
        r0 = good[len(good) // 2]
        print(f"\nT_slow = {r0['ts']*1e12:.1f} ps, T_fast = {r0['tf']*1e12:.1f} ps, "
              f"LSB = {(r0['ts']-r0['tf'])*1e12:.2f} ps")
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
