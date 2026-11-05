#!/usr/bin/env python3
"""Acceptance gate for the DCO cap bank: the period must rise with every code.

The bank this replaced was non-monotonic at the major carry (code 120 -> 128 in
the old 8-bit sweep, where frequency went UP), because custom_cap_16 was worth
less than cap_1+cap_2+cap_4+cap_8. With 63 identical custom_cap_4 units under a
thermometer code there is no ratio left to be wrong, so any violation here means
a real regression -- not a tolerance to be widened.

Usage: check_monotonic.py [dco_char.csv]
"""

import sys


def main(path):
    rows = []
    with open(path) as f:
        header = next(f)
        for line in f:
            parts = line.split()
            if len(parts) != 2:
                continue
            code, freq = parts
            if freq == "FAIL":
                print(f"FAIL: code {code} did not oscillate")
                return 1
            rows.append((int(code), float(freq)))

    if not rows:
        print(f"FAIL: no usable data in {path}")
        return 1
    rows.sort()

    expected = list(range(64))
    if [c for c, _ in rows] != expected:
        missing = sorted(set(expected) - {c for c, _ in rows})
        print(f"FAIL: expected all 64 codes, missing {missing}")
        return 1

    violations = [(c0, f0, c1, f1)
                  for (c0, f0), (c1, f1) in zip(rows, rows[1:]) if f1 >= f0]

    f_hi, f_lo = rows[0][1], rows[-1][1]
    steps = [f0 - f1 for (_, f0), (_, f1) in zip(rows, rows[1:])]

    print(f"codes          : {len(rows)} (0..63)")
    print(f"range          : {f_hi/1e6:.1f} -> {f_lo/1e6:.1f} MHz  ({f_hi/f_lo:.2f}:1)")
    print(f"step size      : {max(steps)/1e6:.2f} MHz max, {min(steps)/1e6:.2f} MHz min")

    if violations:
        print(f"\nFAIL: {len(violations)} non-monotonic step(s)")
        for c0, f0, c1, f1 in violations:
            print(f"  code {c0} -> {c1}: {f0/1e6:.3f} -> {f1/1e6:.3f} MHz  "
                  f"(+{(f1-f0)/1e6:.3f})")
        return 1

    print("\nPASS: frequency strictly decreases across all 63 steps")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "dco_char.csv"))
