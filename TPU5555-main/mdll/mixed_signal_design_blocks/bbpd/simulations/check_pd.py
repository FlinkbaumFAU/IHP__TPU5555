#!/usr/bin/env python3
"""Check the phase-comparator sweep: polarity, clean sign step, static offset.

Reads the `meas` output of build/char_pd.spice (see gen_char_pd.py) and
reports, as an acceptance gate:

  * POLARITY -- comp must be 0 for div leading and 1 for div lagging. The loop
    filter's direction is keyed to that; inverted, the MDLL runs away.
  * MONOTONE STEP -- exactly one transition across the swept range. More than
    one would mean the comparator is responding to something other than the
    edge under test.
  * STATIC OFFSET -- the delay at which comp flips. A D flip-flop needs setup
    time and clk_ref arrives as a ramp, so this is not zero, and the loop will
    settle to whatever it is. This number IS the residual phase error at lock.
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

sys.path.insert(0, HERE)
from gen_char_pd import deltas, T_MEAS        # single source of truth


def read_meas(path):
    """{(meas_index, point_index): volts}"""
    out = {}
    for line in open(path):
        m = re.match(r"^m(\d+)_(\d+)\s*=\s*(\S+)", line.strip())
        if m:
            out[(int(m.group(1)), int(m.group(2)))] = float(m.group(3))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "char_pd.out"))
    ap.add_argument("--vth", type=float, default=0.6)
    ap.add_argument("--fine-ps", nargs=3, type=float, metavar=("LO", "HI", "STEP"),
                    help="must match whatever gen_char_pd.py --fine-ps was given; "
                         "the point list is reconstructed, not stored in the deck")
    a = ap.parse_args()

    fine = None
    if a.fine_ps:
        lo, hi, st = a.fine_ps
        n = int(round((hi - lo) / st))
        fine = [(lo + k * st) * 1e-12 for k in range(n + 1)]
    dts = deltas(fine)
    meas = read_meas(a.out)
    missing = [(j, i) for j in range(len(T_MEAS)) for i in range(len(dts))
               if (j, i) not in meas]
    if missing:
        sys.exit(f"ERROR: {len(missing)} measurement(s) absent from {a.out}")

    bits, unstable = [], []
    for i, dt in enumerate(dts):
        vals = [meas[(j, i)] for j in range(len(T_MEAS))]
        b = [1 if v > a.vth else 0 for v in vals]
        # Anything not within 5% of a rail has not resolved.
        if any(a.vth * 0.1 < v < 1.2 - a.vth * 0.1 for v in vals):
            unstable.append((dt, vals))
        if len(set(b)) != 1:
            unstable.append((dt, vals))
        bits.append(b[-1])

    print(f"points        : {len(dts)}  "
          f"({dts[0]*1e12:+.0f} ps .. {dts[-1]*1e12:+.0f} ps)")

    edges = [i for i in range(1, len(bits)) if bits[i] != bits[i - 1]]
    print(f"transitions   : {len(edges)}")

    ok = True

    if unstable:
        ok = False
        print(f"\nFAIL: {len(unstable)} point(s) did not resolve to a rail "
              f"or disagreed between the two sample cycles:")
        for dt, vals in unstable[:8]:
            print(f"  dt = {dt*1e12:+8.1f} ps  ->  "
                  + ", ".join(f"{v:.4f} V" for v in vals))

    if len(edges) != 1:
        ok = False
        print(f"\nFAIL: expected exactly one sign transition, found {len(edges)}")
    else:
        i = edges[0]
        lo, hi = dts[i - 1], dts[i]
        offset = 0.5 * (lo + hi)
        print(f"crossing      : between {lo*1e12:+.0f} and {hi*1e12:+.0f} ps")
        print(f"static offset : {offset*1e12:+.1f} ps  "
              f"(+/- {(hi-lo)*1e12/2:.0f} ps grid)")
        print(f"polarity      : comp={bits[0]} at {dts[0]*1e12:+.0f} ps "
              f"(div leads), comp={bits[-1]} at {dts[-1]*1e12:+.0f} ps (div lags)")

        if not (bits[0] == 0 and bits[-1] == 1):
            ok = False
            print("\nFAIL: polarity is inverted. rtl/dlf.v assumes comp=1 means "
                  "'div late, ring too slow, decrement'.")
        else:
            print("\n  comp = 0 for div leading, 1 for div lagging -- matches "
                  "rtl/dlf.v.")
            print("  At lock the loop drives t_div - t_clk_ref to the offset "
                  "above, not to zero.")

    print("\nPASS" if ok else "\nFAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
