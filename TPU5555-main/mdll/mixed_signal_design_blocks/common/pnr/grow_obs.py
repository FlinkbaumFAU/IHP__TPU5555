#!/usr/bin/env python3
"""Grow every OBS rectangle of an abstract LEF by DELTA (um), clipped to the macro.

OpenROAD's write_abstract_lef (write_lef.tcl) puts a block's wires into OBS but
not the enclosures of its vias, and a via's metal reaches past the end of the
wire it sits on: lock_ctrl's tdc_f[7] stub ends at x 4.42 on Metal3, its Via2
enclosure at 4.465. The top level then routed tdc_f[6] 0.19 um from it -- legal
against the LEF, an M3.b (0.21 um) violation in the GDS (2026-11-02).
0.1 um covers the IHP via enclosures' overhang; growing everything keeps the
margins between core and die edge open (see write_lef.tcl for why that matters).

Usage: grow_obs.py <lef> [delta]   (rewrites the file in place)
"""
import re
import sys

lef = sys.argv[1]
delta = float(sys.argv[2]) if len(sys.argv) > 2 else 0.1
lines = open(lef).read().split("\n")

size = next(re.match(r"\s*SIZE\s+(\S+)\s+BY\s+(\S+)\s*;", l) for l in lines
            if re.match(r"\s*SIZE\s+\S+\s+BY", l))
w, h = float(size.group(1)), float(size.group(2))

out, in_obs, n = [], False, 0
for l in lines:
    if re.match(r"\s*OBS\b", l):
        in_obs = True
    elif in_obs and re.match(r"\s*END\b", l):
        in_obs = False
    m = re.match(r"(\s*)RECT\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*;", l) if in_obs else None
    if m:
        x0, y0, x1, y1 = (float(v) for v in m.groups()[1:])
        x0, y0 = max(0.0, x0 - delta), max(0.0, y0 - delta)
        x1, y1 = min(w, x1 + delta), min(h, y1 + delta)
        l = f"{m.group(1)}RECT  {x0:g} {y0:g} {x1:g} {y1:g} ;"
        n += 1
    out.append(l)

if n == 0:
    sys.exit(f"grow_obs.py: no OBS rectangles in {lef}")
open(lef, "w").write("\n".join(out))
print(f"grow_obs.py: {n} OBS rectangles in {lef} grown by {delta:g} um")
