#!/usr/bin/env python3
"""Open-loop check of clk_gen's gating: does the ring stop and wait for clk_ref?

clk_gen is a gated ring. After each injection it should run exactly 4 DCO
periods, arm the selector (divn1, after the 3rd edge), raise sel, hold at the
injection mux until the next rising clk_ref, and restart on it. div marks the
4th edge (the one clock edge inside the sel window).

Whether that works depends on WHERE in the reference period the selector arms:
  * in the low half of clk_ref: the ring gates and waits -- the intended case
  * in the high half: sel rises, the mux feeds clk_refb (low), M_out is forced
    low at once, M_out/M_outb clear sel again -- a glitch, one shortened
    period, and the ring free-runs. Correct for a ring that is LATE (the edge
    it was heading for has passed), wrong for a ring so fast that 3.5 periods
    end in the first half of the SAME reference period (code 0 at tt).

This drives the netlisted test_clk_gen.sch (build/test_clk_gen.spice) at a
few fixed codes and reports per reference period: clk_out rising edges, every
sel pulse (start relative to the clk_ref edge, width, clk_ref level at its
rise), divn1 and div edges.

    ./simulations/gate_check.py                 # default codes
    ./simulations/gate_check.py --codes 0 72    # just these

Findings (2026-09-30, tt, the divn1-armed selector with the ICG divider)
------------------------------------------------------------------------
    code  case                 before the guard
       0  too fast             8 clk_out edges per reference period; sel
                               rises with clk_ref HIGH (4.74 ns, 394 ps
                               glitch), a 2nd sel gates at 9.54 ns; two div
                               pulses per period
      72  lock, slightly fast  4 edges, one sel in the low half, one div  OK
      80  lock, slightly slow  4 edges, div 0.6 ns after clk_ref (late)   OK
     104  clearly slow         sel only a ~390 ps glitch in the high half;
                               the ring realigns but NO div edge at all

Consequences found in the closed loop: at code 0 lock_ctrl's premise (the
fastest ring gates and is measurable) fails, and its `inj` input (this sel)
glitches -- the transistor-level `make mdll_sim` handed over at cycle 4 with
an empty TDC reading. The mixed-signal run did not show it: Verilator samples
the glitching input cleanly.

Fix adopted: the M_out guard (clk_gen.sch x7..x10). The selector sees
M_out * armed, armed = "clk_ref fell since the last injection", sampled on
M_out's falling edges. Sweep at tt with it (build/gate_check_mout.txt):
    code      edges/period  sel                           div
     0, 16    6, 5          one hold in the low half      2.1 ns early
    32..72    4             one hold in the low half      2.7 .. 0.06 ns early
    76, 80    4             one hold in the low half      0.29, 0.62 ns late
    88, 96    3/4 mixed     ~460 ps glitch (H) + holds    every 2nd/3rd period, late
    104..160  2..3          ~460 ps glitch (H)            none (160: one EARLY div)
Below code ~32 the ring runs 5..6 periods before it may gate, so the TDC reads
less error than lock_ctrl's 4-period model: under-correction, the safe side.
From ~88 up div went missing, and in the closed fine loop a slightly slow
ring's 4th edge, arriving after sel fell, was counted as #1 of the next run:
that run came up a period short, read "early", and the loop parked at a false
lock near code 98. Two fixes:
  * divider reset release synchronous to clk_out falling (clk_gen.sch x12,
    x13; assertion still one gate from Selb). The late edge stays in the
    reset/ICG window, is not counted, and leaves as a late div -- 88..120 now
    give a div in most periods (gate_check_sync.txt), 0..80 are unchanged.
  * bbpd's late flag (bbpd/src/pd.sch x4): with this guard sel can only rise
    while clk_ref is HIGH if the ring is late, so comp = comp_raw OR late.
A slow ring that arms in the high half is injected at its own hold point, not
re-aligned to clk_ref, so its div drifts through the period and some read
early; the flag outvotes them. Rings more than ~T_REF/2 late (160) can still
alias; acquisition never gets there.

Divider gate (clk_gen/src/divider.sch x6, x7). With the ICG enabled by sel,
div at fast codes came with the 6th edge, not the 4th: the TDC read about two
DCO periods less error than lock_ctrl's 4-period model and the closed-loop
handover slipped to cycle 63. x6 is now armed by divn1 and cleared by div
itself through x7 -- and by the global reset (rstb_g), NOT by the counter
reset, because in lock sel rises before the injected edge. Exactly the 4th
edge passes the ICG, whatever sel does (build/gate_check_divgate_*.txt):
    code 0: div at 5.36 ns (4th edge 5.28), 16: 6.36 ns, 32..80 unchanged;
    88..104 lose div in 1 of 6 periods, 120 and 160 in 2 of 6;
    never two div in one period.
This also removes the under-read below code ~32 noted above. mdll_mixed_sim:
handover back at cycle 41. Side effect: div stays low during global reset
(it used to follow clk_out).

Dither (2026-10-29, build/gate_check_dither*.txt). The divider counts in Gray
(Johnson counter, x4 a nor2b) and dco_decode adds unit N for the last
code[1:0] periods. div at tt, ns after clk_ref:
    code   72    73    74    75    76    77    78    79    80
    div   0.10  0.14  0.215 0.275 0.38  0.44  0.52  0.60  0.71
Monotonic quarter steps of 40..110 ps (mean ~75): +-1/2 LSB of DNL, as the
extra unit sits on a different ring node for each N and switches at a fixed
time after the DCO edge; the carry step (75->76, 79->80) is the largest. Every
code up to 80 still gates in the low half; 88 and 104 as before. Code 0: x12
leads unchanged (250 / 411 / 152 ps tt / ss / ff); ff still runs 8 edges.

Tried and dropped (each added gates between the selector and the DCO):
  * on divn1 -- Div = divn1 * ("clk_ref fell" sampled on clk_out): glitch
    gone, but the blocked divn1 returns only after the counter wraps, so at
    code 0 div lands 0.41 ns AFTER clk_ref and reads as a SLOW ring.
  * injection guard -- DCO sees clk_ref * !used (used: set by sel falling,
    cleared while clk_ref low): code 0 fixed with 4 edges, 104 unchanged.
  * holding sel until the ring's own edge returns (clk_out): fixes 104's div,
    but a ring more than half a period late has that edge cancelled by an
    injection 0.44 ns behind it -- deadlock until clk_ref falls.
  * injecting only once the ring's edge is back (held * clk_out): no
    deadlock, but slow rings are no longer phase-reset, drift, and alias the
    bbpd; +250 ps on the injection path near lock.
"""

import argparse
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
BLOCK = os.path.dirname(HERE)
ROOT = os.path.dirname(BLOCK)
sys.path.insert(0, os.path.join(ROOT, "tdc", "simulations"))
import rawread  # noqa: E402

DECK = os.path.join(BLOCK, "build", "test_clk_gen.spice")
OUT = os.path.join(BLOCK, "build", "gate_check")   # + "_<tag>" with --tag
V = 1.2
TH = V / 2
T_STOP = 90e-9
THREADS = 2          # per deck; ngspice's OSDI threads spin, more buys little

# 8-bit code -> what it is meant to exercise (tt, 1.2 V; lock_ctrl/simul/dco_period.vh)
CODES = {
    0:   "too fast: 4*T_DCO = 5.0 ns, arms in the high half",
    72:  "lock, slightly fast: 4*T_DCO = 9.7 ns",
    80:  "lock, slightly slow: 4*T_DCO = 10.3 ns",
    104: "clearly slow: 4*T_DCO = 12.0 ns",
}
SAVE = ("clk_out clk_ref div sel x2.divn1 x2.div_rstb x2.M_out x2.x4.net3 "
        "x2.div_rstb_s x2.clk_outb")

# --corner: the three STA signoff corners of clk_gen's LibreLane run
# (nom_typ_1p20V_25C, nom_slow_1p08V_125C, nom_fast_1p32V_m40C), as SPICE
# corners. test_clk_gen.sch sets `.PARAM TEMP=28`, which is only a parameter --
# ngspice then runs at its default 27 C -- so the temperature is set with .TEMP.
CORNERS = {"typ": ("mos_tt", 1.20, 27), "slow": ("mos_ss", 1.08, 125),
           "fast": ("mos_ff", 1.32, -40)}
CORNER = "typ"


def deck(code):
    txt = open(DECK).read()
    lib, vdd, temp = CORNERS[CORNER]
    # RSHUNT next to KLU, as gen_mixed.py has it: the typ code-0 deck stopped at
    # 30 ns with "timestep too small" (vvss#branch) under KLU alone; with the
    # shunt it runs through and gives the same x12 margins (2026-10-23).
    for pat, rep in [(r"(?m)^\.LIB cornerMOSlv\.lib mos_tt$", f".LIB cornerMOSlv.lib {lib}"),
                     (r"(?m)^\.OPTIONS KLU$", ".OPTIONS KLU\n.OPTIONS RSHUNT=1e12"),
                     (r"(?m)^\.PARAM VDD=1\.2$", f".PARAM VDD={vdd}\n.TEMP {temp}")]:
        txt, n = re.subn(pat, rep, txt)
        if n != 1:
            sys.exit(f"{DECK}: expected one line matching {pat}")
    for b in range(8):
        pat = rf"(?m)^(V\w+ C\[{b}\] VSS) \S+$"
        txt, n = re.subn(pat, rf"\1 {vdd if code >> b & 1 else 0}", txt)
        if n != 1:
            sys.exit(f"{DECK}: no single source on C[{b}]")
    txt, n = re.subn(r"(?m)^  save all$", f"  set num_threads={THREADS}\n"
                     f"  set filetype=ascii\n  save {SAVE}", txt)
    if n != 1:
        sys.exit(f"{DECK}: expected one '  save all' line")
    txt, n = re.subn(r"(?m)^  tran \S+ \S+$", f"  tran 5p {T_STOP:g}", txt)
    if n != 1:
        sys.exit(f"{DECK}: expected one '  tran' line")
    txt, n = re.subn(r"(?m)^  write \S+$", f"  write {OUT}/code_{code}.raw", txt)
    if n != 1:
        sys.exit(f"{DECK}: expected one '  write' line")
    return txt


def run(code):
    sp = os.path.join(OUT, f"code_{code}.spice")
    open(sp, "w").write(deck(code))
    with open(sp[:-6] + ".log", "w") as f:
        subprocess.run(["ngspice", "-b", sp], stdout=f, stderr=subprocess.STDOUT)
    return code


def report(code):
    raw = os.path.join(OUT, f"code_{code}.raw")
    if not os.path.exists(raw):
        print(f"== code {code}: no raw file, see {raw[:-4]}.log")
        return
    d = {(k[2:-1] if k.startswith("v(") else k).lower(): v
         for k, v in rawread.read(raw).items()}
    t = d["time"]
    E = lambda n, rise=True: rawread.edges(t, d[n], TH, rise)
    refs = [x for x in E("clk_ref") if x > 12e-9]
    co, dv, dn = E("clk_out"), E("div"), E("x2.divn1")
    sr, sf = E("sel"), E("sel", False)
    rr, cb, qs = E("x2.div_rstb"), E("x2.clk_outb"), E("x2.div_rstb_s")
    print(f"== code {code} (6-bit {code >> 2}): {CODES.get(code, '')}")
    for a, b in zip(refs, refs[1:]):
        rel = lambda xs: [round((x - a) * 1e9, 2) for x in xs if a <= x < b]
        sels = []
        for x in sr:
            if a <= x < b:
                w = min((y for y in sf if y > x), default=float("nan")) - x
                lvl = "H" if rawread.value_at(t, d["clk_ref"], x) > TH else "L"
                sels.append(f"{(x - a) * 1e9:.2f}+{w * 1e12:.0f}ps({lvl})")
        print(f"  ref@{a * 1e9:5.1f}: {len(rel(co))} clk_out rises {rel(co)}")
        print(f"             sel {sels}  divn1 {rel(dn)}  div {rel(dv)}")
        # x12 (div_rstb_s): released by div_rstb rising (sel falling), then
        # clocked by clk_outb. Intended: the release precedes the injection's
        # own clk_outb edge, and div_rstb_s rises on that edge. Report the
        # release, the first clk_outb edge after it (and its margin), and
        # when div_rstb_s actually rose.
        for x in [x for x in rr if a <= x < b]:
            ck = min((y for y in cb if y > x), default=float("nan"))
            q = min((y for y in qs if y > x), default=float("nan"))
            print(f"             x12: release {(x - a) * 1e9:.3f}  clk_outb^ "
                  f"{(ck - a) * 1e9:.3f} (margin {(ck - x) * 1e12:.0f} ps)  "
                  f"Q^ {(q - a) * 1e9:.3f}{'  <- on that edge' if abs(q - ck) < 0.3e-9 else '  <- NOT on that edge'}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--codes", type=int, nargs="*", default=list(CODES))
    ap.add_argument("--report-only", action="store_true")
    ap.add_argument("--tag", help="keep this run's decks/raws apart (build/gate_check_<tag>)")
    ap.add_argument("--save", nargs="*", default=[], help="extra nodes to save")
    ap.add_argument("--corner", choices=list(CORNERS), default="typ")
    a = ap.parse_args()
    global OUT, SAVE, CORNER, TH
    CORNER = a.corner
    TH = CORNERS[CORNER][1] / 2
    SAVE = " ".join([SAVE] + a.save)
    if a.tag:
        OUT = f"{OUT}_{a.tag}"
    if CORNER != "typ":
        OUT = f"{OUT}_{CORNER}"
    if not os.path.exists(DECK):
        sys.exit(f"missing {DECK} -- run `make build/test_clk_gen.spice`")
    os.makedirs(OUT, exist_ok=True)
    if not a.report_only:
        with ThreadPoolExecutor(len(a.codes)) as ex:
            list(ex.map(run, a.codes))
    for c in a.codes:
        report(c)


if __name__ == "__main__":
    main()
