#!/usr/bin/env python3
"""Structural check of the dither path in the mapped dco_decode netlist.

g[1:0] -- the divider's Gray count -- changes on DCO edges while the ring
runs, so any glitch on a cap enable it reaches disturbs a running node.
rtl/dco_decode.v builds the path so that none can occur: each signal passes
single gates with one changing input. That is a property of the netlist, not of
the logic function, so LEC cannot see it. This checks it:

  * g[0], g[1] drive only the period decoders (nor2b, or2) and a DATA input of
    the mux4 -- never a select;
  * the mux4's selects are code[0], code[1] (static while the ring runs), and
    its output, frac_on, drives only a21o/or2 cells;
  * each of those drives a cap-enable output (co*/cob*) directly.

    synth/check_dither_cone.py build/01-synth/dco_decode.v
"""

import re
import sys

OUTS = {"X", "Y", "Q"}
CAPS = ("co0", "cob0", "co1", "cob1", "co2", "cob2", "co3", "cob3")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/01-synth/dco_decode.v"
    v = open(path).read()
    cells = []
    for typ, name, body in re.findall(r"(sg13g2_\w+)\s+(\S+)\s*\((.*?)\);", v, re.S):
        cells.append((typ, name, {k: x.strip() for k, x in re.findall(r"\.(\w+)\(([^()]*)\)", body)}))

    def users(net):
        return [(t, n, p) for t, n, c in cells for p, x in c.items() if x == net and p not in OUTS]

    def out_of(name):
        return next(x for t, n, c in cells if n == name for k, x in c.items() if k in OUTS)

    errs = []
    for g in ("g[0]", "g[1]"):
        for t, n, p in users(g):
            ok = (t in ("sg13g2_nor2b_1", "sg13g2_or2_1")
                  or (t == "sg13g2_mux4_1" and p.startswith("A")))
            if not ok:
                errs.append(f"{g} drives {t} {n}/{p}")
    mux = [(n, c) for t, n, c in cells if t == "sg13g2_mux4_1"]
    if len(mux) != 1:
        errs.append(f"expected one mux4 (frac_on), found {len(mux)}")
    else:
        n, c = mux[0]
        if {c.get("S0"), c.get("S1")} != {"code[0]", "code[1]"}:
            errs.append(f"mux4 selects are {c.get('S0')}, {c.get('S1')}, not code[1:0]")
        fr = out_of(n)
        fu = users(fr)
        if len(fu) != 63:
            errs.append(f"frac_on drives {len(fu)} inputs, expected 63 (one per unit)")
        for t, n2, p in fu:
            if t not in ("sg13g2_a21o_1", "sg13g2_or2_1"):
                errs.append(f"frac_on drives {t} {n2}/{p}")
                continue
            o = out_of(n2)
            if not any(o.startswith(cap + "[") for cap in CAPS):
                errs.append(f"{t} {n2} (on frac_on) drives {o}, not a cap enable")
    for e in errs:
        print("FAIL: " + e)
    print("dither cone: g -> period gate -> mux4 -> frac_on -> 63 enables" if not errs
          else "DITHER CONE: FAIL")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
