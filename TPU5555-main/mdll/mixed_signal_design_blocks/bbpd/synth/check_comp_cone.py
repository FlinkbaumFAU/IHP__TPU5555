#!/usr/bin/env python3
"""Structural check of dlf's comp input in the mapped netlist.

rtl/dlf.v holds its state in Gray code so that an unresolved comp can only
move the code by +-2 LSB: comp may reach only the (at most two) bits in which
code+1 and code-1 differ, through an AND whose other input says "this bit
differs" -- with that input at 0 the cell's output is a solid 0 whatever level
comp sits at. That is a property of the netlist, not of the logic function, so
LEC cannot see it. This checks it: comp drives nothing but sg13g2_and2_1
inputs, each AND drives exactly one sg13g2_xor2_1, and each XOR reaches exactly
one flop's D, directly or through inverters only.

    synth/check_comp_cone.py build/01-synth/dlf.v
"""

import re
import sys


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/01-synth/dlf.v"
    v = open(path).read()
    cells = []
    for typ, name, body in re.findall(r"(sg13g2_\w+)\s+(\S+)\s*\((.*?)\);", v, re.S):
        conns = {k: x.strip() for k, x in re.findall(r"\.(\w+)\(([^()]*)\)", body)}
        cells.append((typ, name, conns))
    outs = {"X", "Y", "Q"}

    def users(net):
        return [(t, n, p) for t, n, c in cells for p, x in c.items() if x == net and p not in outs]

    def out_of(name):
        return next(x for t, n, c in cells if n == name for k, x in c.items() if k in outs)

    errs = []
    cu = users("comp")
    if not cu:
        errs.append("comp drives nothing")
    for t, n, p in cu:
        if t != "sg13g2_and2_1":
            errs.append(f"comp drives {t} {n}/{p}, not an and2")
            continue
        nxt = users(out_of(n))
        if len(nxt) != 1 or nxt[0][0] != "sg13g2_xor2_1":
            errs.append(f"and2 {n} drives {nxt}, not exactly one xor2")
            continue
        net, hops = out_of(nxt[0][1]), 0
        while True:
            d = users(net)
            if len(d) == 1 and d[0][0].startswith("sg13g2_inv") and hops < 2:
                net, hops = out_of(d[0][1]), hops + 1
                continue
            if not (len(d) == 1 and d[0][0].startswith("sg13g2_dfrbpq") and d[0][2] == "D"):
                errs.append(f"xor2 {nxt[0][1]} reaches {d}, not one flop D")
            break
    for e in errs:
        print("FAIL: " + e)
    print(f"comp cone: {len(cu)} and2 -> xor2 -> D" if not errs else "COMP CONE: FAIL")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
