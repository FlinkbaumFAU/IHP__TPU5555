#!/usr/bin/env python3
"""Extract TDC readings, lock time, div counts and lock offset from a test_mdll raw
(any closed-loop run: mdll_sim, mdll_mixed_sim, layout_sim, pex_sim).

Usage: simulations/analyse_mdll.py <raw>
"""
import sys, os, statistics as st
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tdc", "simulations"))
import rawread

raw = sys.argv[1]
d = {(k[2:-1] if k.startswith("v(") else k).lower(): v for k, v in rawread.read(raw).items()}
t = d["time"]; TH = max(d["clk_ref"]) / 2
ns = lambda x: f"{x*1e9:8.3f}"
rst = rawread.edges(t, d["resetb"], TH)[0]
refs = [x for x in rawread.edges(t, d["clk_ref"], TH) if x > rst]
divs = rawread.edges(t, d["x1.div"], TH)
print(f"VDD~{2*TH:.3f}  resetb rises {ns(rst)} ns, {len(refs)} ref edges after reset, end {ns(t[-1])} ns")

def cyc(x):  # reference cycle index (ref edges after reset, 0-based) at or before x
    return sum(1 for r in refs if r <= x) - 1

print("\nTDC readings (sampled 20 ps before each tdc_start falling edge):")
print(" t_fall(ns)  cyc   tdc_s tdc_f  s-f  hit  code(hex/dec)  code 200ps later")
for x in rawread.edges(t, d["x1.tdc_start"], TH, rising=False):
    tq = x - 20e-12
    s = rawread.word(d, t, "x1.tdc_s", 8, tq, TH); f = rawread.word(d, t, "x1.tdc_f", 8, tq, TH)
    h = int(rawread.value_at(t, d["x1.hit"], tq) > TH)
    c = rawread.word(d, t, "code", 8, tq, TH)
    c2 = rawread.word(d, t, "code", 8, min(x + 2e-9, t[-1]), TH)
    print(f" {ns(x)} {cyc(x):4d}   {s:5d} {f:5d} {s-f:4d}  {h:3d}   0x{c:02x}/{c:3d}     0x{c2:02x}/{c2:3d}")

lr = rawread.edges(t, d["locked"], TH); lf = rawread.edges(t, d["locked"], TH, rising=False)
print(f"\nlocked rises at: {[round(x*1e9,3) for x in lr]} ns (ref cycle {[cyc(x) for x in lr]}); falls: {[round(x*1e9,3) for x in lf]}")

print("\ndiv rising edges per reference period (period k = [ref_k, ref_k+1)), first 12 after reset:")
print(" before first ref edge after reset:", sum(1 for x in divs if rst < x < refs[0]))
for k in range(min(12, len(refs) - 1)):
    n = sum(1 for x in divs if refs[k] <= x < refs[k + 1])
    print(f"  k={k:2d} ref {ns(refs[k])}  div edges {n}  code 0x{rawread.word(d, t, 'code', 8, refs[k+1]-0.5e-9, TH):02x}")

N = 30
off = []
for r in refs[-N - 1:-1] if refs[-1] > t[-1] - 1e-9 else refs[-N:]:
    near = min(divs, key=lambda x: abs(x - r))
    off.append(near - r)
print(f"\nlock offset div - clk_ref (nearest div rise to each of last {len(off)} ref rises), ps:")
print(f"  mean {st.mean(off)*1e12:+.1f}  sd {st.pstdev(off)*1e12:.1f}  min {min(off)*1e12:+.1f}  max {max(off)*1e12:+.1f}")
print("  values:", " ".join(f"{x*1e12:+.0f}" for x in off))
codes = [rawread.word(d, t, "code", 8, r - 0.5e-9, TH) for r in refs[-N:]]
print("  codes (8b):", " ".join(str(c) for c in codes))
