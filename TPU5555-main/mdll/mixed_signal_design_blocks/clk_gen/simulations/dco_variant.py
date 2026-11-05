#!/usr/bin/env python3
"""DCO free-running period at chosen codes, for range studies: SPICE corner,
the extracted ring-node wire load, and sizing variants of the delay cell.

Built from gen_char_dco.py's deck (ring + thermometer nodes driven directly,
no decoder). Writes one deck; run it with ngspice in its own directory, it
appends "code freq" lines to res.csv. Free-running: the gated-mode overhead
(injection, div path) is not in it. See TAPEOUT.md, "DCO range at the slow
corner".

  dco_variant.py --corner slow --wire 1 --drv sg13g2_inv_2 --cap custom_cap_8 \
                 --codes 0,63 --out d/d.spice && (cd d && ngspice -b d.spice)
"""
import sys, os, re, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_char_dco as g
# Wire C per ring node (fF, to ground + coupling, nearly all of it to the rails)
# from the Calibre xRC of CMOS5L_2026-10-29_14-31-13; dco net -> char deck net.
WIRE = {"net7": 6.51, "net6": 6.39, "net5": 6.28, "net1": 6.15,   # real: net6 net5 net4 net1
        "net2": 6.67, "net4": 6.29, "ring_p": 6.25, "ring_n": 6.08}  # real: net2 net3 ring_p ring_n
COR = {"typ": ("mos_tt", 1.2, 27), "slow": ("mos_ss", 1.08, 125), "fast": ("mos_ff", 1.32, -40)}
ap = argparse.ArgumentParser()
ap.add_argument("--corner", default="typ"); ap.add_argument("--wire", type=float, default=0.0,
                help="scale of the extracted ring wire C (0 = schematic)")
ap.add_argument("--drv", default="sg13g2_inv_2", help="delay cell forward inverter (x13/x14)")
ap.add_argument("--latch", default="sg13g2_inv_1", help="cross-coupled pair (x11/x12)")
ap.add_argument("--cap", default="custom_cap_8")
ap.add_argument("--codes", default="0,63"); ap.add_argument("--out", required=True)
a = ap.parse_args()
codes = [int(c) for c in a.codes.split(",")]
txt = g.build(0, 0, "res.csv")
lib, vdd, temp = COR[a.corner]
txt = txt.replace("cornerMOSlv.lib mos_tt", f"cornerMOSlv.lib {lib}")
txt = txt.replace(".PARAM VDD=1.2", f".PARAM VDD={vdd}").replace(".TEMP 27", f".TEMP {temp}")
txt = re.sub(r"x13 out in VDD VSS \S+", f"x13 out in VDD VSS {a.drv}", txt)
txt = re.sub(r"x14 outb inb VDD VSS \S+", f"x14 outb inb VDD VSS {a.drv}", txt)
txt = txt.replace("x11 out outb VDD VSS sg13g2_inv_1", f"x11 out outb VDD VSS {a.latch}")
txt = txt.replace("x12 outb out VDD VSS sg13g2_inv_1", f"x12 outb out VDD VSS {a.latch}")
txt = re.sub(r" custom_cap_\w+\b", " " + a.cap, txt)
if a.wire:
    txt = txt.replace('Vcode code 0 DC 0', 'Vcode code 0 DC 0\n' + "\n".join(
        f"Cw_{n} {n} 0 {c * a.wire:.3f}f" for n, c in WIRE.items()))
txt = txt.replace(".ic v(M_out)=0 v(M_outb)=1.2", f".ic v(M_out)=0 v(M_outb)={vdd}")
txt = txt.replace("when v(M_out)=0.6", f"when v(M_out)={vdd/2}")
# loop over the chosen codes only
txt = re.sub(r"let code = 0\nwhile code <= 0\n", "foreach cc " + " ".join(map(str, codes)) + "\n  let code = $cc\n", txt)
txt = txt.replace("  let code = code + 1\nend", "end")
# (gen_char_dco sets num_threads=1)
open(a.out, "w").write(txt)
