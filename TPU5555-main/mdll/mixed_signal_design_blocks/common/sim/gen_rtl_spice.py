#!/usr/bin/env python3
"""Emit a SPICE subckt from a synthesised sg13g2 gate netlist.

Shared by every block with synthesised RTL in the SPICE path (bbpd's dlf,
tdc's counter, lock_ctrl). Each block used to carry its own near-identical
copy differing only in the port list.

Schematics instantiate these modules through a symbol, so any SPICE netlist
containing them needs a `.subckt`. Yosys' own SPICE backend cannot supply one:
it writes a flat netlist with no .subckt wrapper, dotted net names, and cell
instances missing VDD/VSS (the PDK's sg13g2_inv_1 is "Y A VDD VSS").

This is a STRUCTURAL translation, not a behavioural model: the cells are the
ones P&R places, so a transient exercises their real timing. The translation is
mechanical -- named port connections are read out of the Verilog, the
positional order is looked up in the PDK's own SPICE library, and bit-level
`assign` aliases that yosys leaves behind are resolved to their driving net.
Nothing is transcribed by hand, so the model cannot drift from the netlist.

--ports must match the pin order xschem emits for the module's symbol; buses
are written as name[msb:lsb]. --supply-ports appends VDD VSS, for symbols that
pass the supplies explicitly (counter.sym); without it the cells use the
global VDD/VSS nets.

Example (bbpd/Makefile):
    gen_rtl_spice.py --module dlf --nl build/01-synth/dlf.v \\
        --ports clk resetb comp load 'seed[7:0]' 'code[7:0]' \\
        --title "8-bit saturating bang-bang accumulator" -o simulations/dlf.spice
"""

import argparse
import os
import re
import sys

PDK = os.environ.get("PDK_ROOT", "/opt/IHP-Open-PDK/").rstrip("/") + "/ihp-sg13g2"
SCL = f"{PDK}/libs.ref/sg13g2_stdcell/spice/sg13g2_stdcell.spice"


def cell_pinorder():
    """{cell: [pin, ...]} straight out of the PDK SPICE library."""
    order = {}
    for line in open(SCL):
        m = re.match(r"^\.subckt\s+(sg13g2_\w+)\s+(.*)$", line.strip())
        if m:
            order[m.group(1)] = m.group(2).split()
    return order


def bits(ref):
    """'a[3:1]' -> ['a[3]', 'a[2]', 'a[1]'];  'a[0]' / 'a' unchanged."""
    m = re.fullmatch(r"(\S+?)\[(\d+):(\d+)\]", ref.strip())
    if not m:
        return [ref.strip()]
    hi, lo = int(m.group(2)), int(m.group(3))
    step = -1 if hi >= lo else 1
    return [f"{m.group(1)}[{i}]" for i in range(hi, lo + step, step)]


def aliases(src):
    """{alias_bit: driving_bit} from `assign lhs = rhs;` lines."""
    amap = {}
    for lhs, rhs in re.findall(r"^\s*assign\s+(\S+)\s*=\s*(\S+?)\s*;", src, re.M):
        lb, rb = bits(lhs), bits(rhs)
        if len(lb) != len(rb):
            sys.exit(f"cannot resolve assign {lhs} = {rhs}")
        for a, b in zip(lb, rb):
            amap[a] = b
    return amap


def resolve(net, amap, ports):
    seen = set()
    # Prefer the port name when a port is on either side of the alias.
    while net in amap and net not in ports and net not in seen:
        seen.add(net)
        net = amap[net]
    return net


def build(a):
    src = open(a.nl).read()
    order = cell_pinorder()
    ports = [b for p in a.ports for b in bits(p)]
    pset = set(ports)
    amap = aliases(src)
    # An alias whose target is internal but whose source is a port: point the
    # internal name at the port instead, so the port net is the one used.
    for x, y in list(amap.items()):
        if x in pset and y not in pset:
            amap[y] = x
            del amap[x]

    supplies = " VDD VSS" if a.supply_ports else ""
    L = [f"** {a.module}: {a.title}" if a.title else f"** {a.module}",
         f"** Generated from {os.path.relpath(a.nl)} by common/sim/gen_rtl_spice.py",
         "** -- do not edit by hand; regenerate through make.",
         "",
         f".subckt {a.module} {' '.join(ports)}{supplies}"]
    n = 0
    for m in re.finditer(r"^\s*(sg13g2_\w+)\s+(\S+)\s*\((.*?)\);", src, re.S | re.M):
        cell, name = m.group(1), m.group(2)
        conns = dict(re.findall(r"\.(\w+)\(\s*([^)]*?)\s*\)", m.group(3)))
        pins = order.get(cell)
        if pins is None:
            sys.exit(f"{cell} has no .subckt in {SCL}")
        nets = []
        for p in pins:
            if p in ("VDD", "VSS"):
                nets.append(p)
            elif p in conns:
                nets.append(resolve(conns[p], amap, pset))
            else:
                sys.exit(f"{name} ({cell}) has no connection for pin {p}")
        L.append(f"x{name} {' '.join(nets)} {cell}")
        n += 1
    if not n:
        sys.exit(f"no sg13g2 instances in {a.nl} -- has its synthesis run?")
    L += [".ends", ""]
    return "\n".join(L), n


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--module", required=True)
    ap.add_argument("--nl", required=True, help="synthesised gate netlist (.v)")
    ap.add_argument("--ports", nargs="+", required=True,
                    help="symbol pin order; buses as name[msb:lsb]")
    ap.add_argument("--supply-ports", action="store_true",
                    help="append VDD VSS to the subckt ports")
    ap.add_argument("--title", default="", help="one-line description for the header")
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()
    text, n = build(a)
    open(a.out, "w").write(text)
    print(f"wrote {a.out} ({n} sg13g2 cells)")


if __name__ == "__main__":
    main()
