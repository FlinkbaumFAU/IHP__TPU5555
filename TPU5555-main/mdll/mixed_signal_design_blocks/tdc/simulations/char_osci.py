#!/usr/bin/env python3
"""Vernier ring characterisation: T_slow, T_fast and the LSB at the STA corners.

The ring subckts are taken verbatim from the xschem export of src/tdc.sch
(build/01-synth/tdc.spice), so this measures what is drawn, not a model of it.
Each ring gets the load it sees in the TDC: its counter's clock pin plus the
edge-lock detector pins it drives (slow: one D pin; fast: two CLK pins).

Acceptance: the LSB (T_slow - T_fast) must be a near-constant FRACTION of the
period across corners. The two rings are the same cells with only the trim
caps' tie cells differing, so their delays scale together; if LSB/T drifts,
the matching argument behind the whole design is broken.
"""

import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PDK = os.environ.get("PDK_ROOT", "/opt/IHP-Open-PDK/").rstrip("/") + "/ihp-sg13g2"
BUILD = os.path.join(ROOT, "build", "char_osci")
# The three PVTs LibreLane signs off at (nom_slow_1p08V_125C, nom_typ_1p20V_25C,
# nom_fast_1p32V_m40C). pnr/base.sdc takes each corner's ring period from this
# table, so the counters are timed against the ring they actually see there.
CORNERS = [("slow", "mos_ss", 1.08, 125),
           ("typ",  "mos_tt", 1.20, 25),
           ("fast", "mos_ff", 1.32, -40)]
LSB_FRAC_TOL = 0.15      # LSB/T may vary by at most +-15 % across corners


def subckts(names):
    path = os.path.join(ROOT, "build", "01-synth", "tdc.spice")
    if not os.path.exists(path):
        raise SystemExit(f"missing {path} -- run `make build/01-synth/tdc.spice`")
    out, keep = [], False
    for line in open(path):
        s = line.rstrip("\n")
        m = re.match(r"^\.subckt\s+(\S+)", s)
        if m and m.group(1) in names:
            keep = True
        if keep and not s.startswith("*"):
            out.append(s)
        if keep and s.startswith(".ends"):
            keep = False
    return out


def run(pvt):
    corner, model, vdd, temp = pvt
    os.makedirs(BUILD, exist_ok=True)
    L = [f"** Vernier ring characterisation ({corner})",
         f".LIB {PDK}/libs.tech/ngspice/models/cornerMOSlv.lib {model}",
         ".OPTIONS KLU",
         f".INCLUDE {PDK}/libs.ref/sg13g2_stdcell/spice/sg13g2_stdcell.spice",
         ".INCLUDE custom_stdcell.spice",
         f".INCLUDE {ROOT}/simulations/counter.spice",
         f".TEMP {temp}"]
    L += subckts({"slow_osci", "fast_osci"})
    L += [f"VVDD VDD 0 DC {vdd}", "VVSS VSS 0 0",
          f"VEN en 0 PWL(0 0 1n 0 1.03n {vdd})",
          f"VRST rstn 0 DC {vdd}",
          "xs os en VDD VSS slow_osci",
          "xf of en VDD VSS fast_osci",
          # the loads each ring drives inside tdc.sch
          "xcs cs7 cs6 cs5 cs4 cs3 cs2 cs1 cs0 os rstn VDD VSS counter",
          "xcf cf7 cf6 cf5 cf4 cf3 cf2 cf1 cf0 of rstn VDD VSS counter",
          "xel3 q1 q1n of os rstn VDD VSS sg13g2_dfrbp_1",
          "xel4 q2 q2n of q1 rstn VDD VSS sg13g2_dfrbp_1",
          ".control",
          "  tran 2p 70n",   # slow corner: ~1.5 ns/period, 30 edges
          f"  meas tran s1 when v(os)={vdd/2} rise=5",
          f"  meas tran s2 when v(os)={vdd/2} rise=30",
          f"  meas tran f1 when v(of)={vdd/2} rise=5",
          f"  meas tran f2 when v(of)={vdd/2} rise=30",
          "  echo RES $&s1 $&s2 $&f1 $&f2",
          "  quit", ".endc", ".end"]
    sp = os.path.join(BUILD, f"{corner}.spice")
    open(sp, "w").write("\n".join(L) + "\n")
    out = subprocess.run(["ngspice", "-b", sp], capture_output=True, text=True,
                         env=dict(os.environ, OMP_NUM_THREADS="1")).stdout
    open(sp[:-6] + ".log", "w").write(out)
    m = re.search(r"^RES\s+([-\d.eE+]+)\s+([-\d.eE+]+)\s+([-\d.eE+]+)\s+([-\d.eE+]+)\s*$", out, re.M)
    if not m:
        return corner, None
    s1, s2, f1, f2 = map(float, m.groups())
    return corner, ((s2 - s1) / 25, (f2 - f1) / 25)


def main():
    with ThreadPoolExecutor(len(CORNERS)) as ex:
        res = dict(ex.map(run, CORNERS))
    print(f"{'corner':>7} {'T_slow/ps':>10} {'T_fast/ps':>10} {'LSB/ps':>7} {'LSB/T':>7} "
          f"{'range/ns':>8}")
    fracs = []
    for c, *_ in CORNERS:
        if res[c] is None:
            print(f"{c:>7} no result -- see {BUILD}/{c}.log")
            return 1
        ts, tf = res[c]
        lsb = ts - tf
        fracs.append(lsb / ts)
        # Fine range before the rings coincide: one slow period's worth of LSBs.
        print(f"{c:>7} {ts*1e12:>10.1f} {tf*1e12:>10.1f} {lsb*1e12:>7.2f} "
              f"{lsb/ts*100:>6.2f}% {ts/lsb*ts*1e9:>8.1f}")
    mid = fracs[1]
    ok = all(abs(f / mid - 1) <= LSB_FRAC_TOL for f in fracs)
    print(f"LSB/T spread: {min(fracs)/mid-1:+.1%} .. {max(fracs)/mid-1:+.1%} "
          f"of tt (limit +-{LSB_FRAC_TOL:.0%})")
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
