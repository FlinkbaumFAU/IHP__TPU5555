#!/usr/bin/env python3
"""Copy a LibreLane run's netlist/timing/layout views into the repository layout,
with the top name hdc_chip_top replaced by TPU5555.

    rename_views.py <run>/final <out_dir>

The replacement is textual and global, as for v.1.0.0 (its views are exactly the
full-test-v7 files with the name replaced). Each file must contain the old name
exactly as often as listed in VIEWS (the module/subckt/design header lines and,
in Liberty/SDF, the library/design name), so nothing else can be renamed by
accident. The GDS is not handled here: make_release.py renames its top cell.
"""
import hashlib
import os
import sys

OLD, NEW = "hdc_chip_top", "TPU5555"
CORNERS = ("nom_fast_1p32V_m40C", "nom_slow_1p08V_125C", "nom_typ_1p20V_25C")
# (path in <run>/final, path in the repository below TPU5555-main/ or release/, occurrences)
VIEWS = [
    (f"cdl/{OLD}.cdl", f"cdl/{NEW}.cdl", 2),
    (f"pnl/{OLD}.pnl.v", f"PlaceAndRoute/netlist/{NEW}.pnl.v", 1),
    (f"nl/{OLD}.nl.v", f"synthesis/netlist/{NEW}.nl.v", 1),
    (f"def/{OLD}.def", f"PlaceAndRoute/def/{NEW}.def", 1),
    (f"spef/nom/{OLD}.nom.spef", f"PlaceAndRoute/parasitics/spef/nom/{NEW}.nom.spef", 1),
] + [
    (f"lib/{c}/{OLD}__{c}.lib", f"PlaceAndRoute/timing/lib/{c}/{NEW}__{c}.lib", 2) for c in CORNERS
] + [
    (f"sdf/{c}/{OLD}__{c}.sdf", f"PlaceAndRoute/timing/sdf/{c}/{NEW}__{c}.sdf", 2) for c in CORNERS
]


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1:]
    for s, d, n in VIEWS:
        data = open(os.path.join(src, s), "rb").read()
        found = data.count(OLD.encode())
        if found != n:
            sys.exit(f"{s}: {OLD} occurs {found} times, expected {n}")
        if NEW.encode() in data:
            sys.exit(f"{s}: already contains {NEW}")
        out = data.replace(OLD.encode(), NEW.encode())
        os.makedirs(os.path.dirname(os.path.join(dst, d)), exist_ok=True)
        open(os.path.join(dst, d), "wb").write(out)
        print(f"{hashlib.sha256(out).hexdigest()}  {d}  ({n} x {OLD} -> {NEW}, from {s})")


if __name__ == "__main__":
    main()
