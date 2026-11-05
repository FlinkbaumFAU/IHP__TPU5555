#!/usr/bin/env python3
"""Retarget a flat P&R netlist from sg13g2 standard cells to another IHP SG13
variant's (sg13cmos5l_*), by renaming the cell types.

The schematics, the RTL synthesis and its LEC are all done once, against
sg13g2. SG13CMOS5L's standard-cell library is the same library under another
prefix: its Verilog models, UDPs, cell LEF and CDL are identical to sg13g2's
once the prefix is renamed (checked when this was written; `--check` repeats
it). So the renamed netlist is the same circuit, and the equivalence proven
against sg13g2 carries over -- re-synthesising against the other library would
instead give a different mapping that nothing has proven.

Only instance cell types are renamed (`sg13g2_buf_1 x1 (...)` at the start of
a statement); net and instance names are left alone. Every renamed cell must
exist in the target library's LEF, so a cell the variant lacks fails here
rather than as an unresolved master halfway through P&R.

Usage: retarget.py --pdk-root /opt/IHP-Open-PDK --to sg13cmos5l IN.v OUT.v
"""

import argparse
import os
import re
import sys

SRC = "sg13g2"
CELL_RE = re.compile(rf"^(\s*){SRC}_(\w+)(\s)", re.M)


def lib_dir(pdk_root, tech):
    return os.path.join(pdk_root, f"ihp-{tech}", "libs.ref", f"{tech}_stdcell")


def lef_macros(pdk_root, tech):
    path = os.path.join(lib_dir(pdk_root, tech), "lef", f"{tech}_stdcell.lef")
    return set(re.findall(r"^MACRO (\S+)", open(path).read(), re.M))


def check_identical(pdk_root, tech):
    """The premise of this script: same library, other prefix."""
    bad = []
    for sub, ext in (("verilog", "_stdcell.v"), ("verilog", "_udp.v"),
                     ("lef", "_stdcell.lef"), ("cdl", "_stdcell.cdl")):
        texts = []
        for t in (SRC, tech):
            s = open(os.path.join(lib_dir(pdk_root, t), sub, t + ext)).read()
            s = s.replace(f"{t}_", "X_")
            # Header comments name the technology; they are not the cells.
            s = re.sub(r"^//\s*technology\s*:.*$", "", s, flags=re.M)
            texts.append(s)
        if texts[0] != texts[1]:
            bad.append(sub + "/" + "X" + ext)
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--pdk-root", default=os.environ.get("PDK_ROOT", "/opt/IHP-Open-PDK"))
    ap.add_argument("--to", required=True, help="target variant, e.g. sg13cmos5l")
    ap.add_argument("--check", action="store_true",
                    help="also verify the two libraries differ only in the prefix")
    ap.add_argument("inp")
    ap.add_argument("out")
    a = ap.parse_args()

    if a.check:
        bad = check_identical(a.pdk_root, a.to)
        if bad:
            sys.exit(f"{SRC} and {a.to} libraries differ beyond the prefix: {', '.join(bad)}")

    have = lef_macros(a.pdk_root, a.to)
    text = open(a.inp).read()
    used = set(m.group(2) for m in CELL_RE.finditer(text))
    missing = sorted(c for c in used if f"{a.to}_{c}" not in have)
    if missing:
        sys.exit(f"{a.to} has no " + ", ".join(f"{a.to}_{c}" for c in missing))
    out, n = CELL_RE.subn(rf"\g<1>{a.to}_\g<2>\g<3>", text)
    if re.search(rf"\b{SRC}_", out):
        left = sorted(set(re.findall(rf"\b{SRC}_\w+", out)))
        sys.exit(f"{SRC} names left that are not cell types: {', '.join(left)}")
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "w").write(out)
    print(f"{a.out}: {n} instances of {len(used)} cells renamed {SRC}_* -> {a.to}_*")


if __name__ == "__main__":
    main()
