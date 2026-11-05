#!/usr/bin/env python3
"""div vs. clk_ref_g matching in the hardened MDLL top level.

The tdc and the bbpd compare clk_gen's div against clk_ref_g, which clk_ref
reaches through a replica of the gates div leaves clk_gen through, so that
their delay cancels. Whatever does NOT cancel is a static offset: in the TDC's
reading of e, and in the bbpd's lock point (the ring's 4th edge vs. the
injecting clk_ref edge).

This reports, per STA corner, the two paths from where they split (the clk_ref
net) to the tdc and bbpd pins:

    div        clk_ref -> clk_gen pin ... ring ... ICG x11.x5 -> buf_4 x11.x9
               -> div (+ x11.x7, the divider's self-clear) -> pins
    clk_ref_g  clk_ref -> x5 (lgcp_1) -> x7 (buf_4) -> clk_ref_g (+ x8, a
               nor2b_1 input standing in for x11.x7) -> pins

as the parts that are supposed to cancel:

    gates   x11.x5 + x11.x9 (clk_gen alone, its own SPEF, the top-level div
            net's load on its div port) vs. x5 + x7 (top level, real loads)
    routes  Elmore delay of the top-level div / clk_ref_g nets to each pin, and
            of clk_ref to clk_gen's pin vs. to x5/CLK, from the top-level SPEF
            plus the pins' capacitances

The ring between clk_gen's clk_ref pin and its ICG is the thing being measured,
not a mismatch, and is left out. Gate (TAPEOUT.md): |delta| <~ 20 ps per pin,
rising edges (both comparisons are on rising edges).

Usage: pnr/match_report.py [--cmos5l] [pnr/runs/<RUN>]   (default: the latest run)
Needs `sta` (OpenSTA) on PATH and build/macros/ from `make macros` -- with
--cmos5l, the SG13CMOS5L top level: CMOS5L_* runs, build/sg13cmos5l/macros/
from `make macros_cmos5l`, sg13cmos5l_stdcell.
"""

import glob
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDK_ROOT = os.environ.get("PDK_ROOT", "/opt/IHP-Open-PDK/")
# tech -> (run-tag prefix, macro views); set by main()
TECHS = {"sg13g2": ("RUN", "build/macros"), "sg13cmos5l": ("CMOS5L", "build/sg13cmos5l/macros")}
TECH = "sg13g2"


def stdcell_lib(corner):
    return f"{PDK_ROOT}/ihp-{TECH}/libs.ref/{TECH}_stdcell/lib/{TECH}_stdcell_{corner}.lib"


def macros():
    return TECHS[TECH][1]
CUSTOM_LIB = os.path.join(os.path.dirname(ROOT), "custom_stdcell", "custom_stdcell.lib")
CORNERS = ["typ_1p20V_25C", "slow_1p08V_125C", "fast_1p32V_m40C"]
BLOCKS = ["clk_gen", "tdc", "bbpd", "lock_ctrl"]
GATE_PS = 20
# clk_ref's edge at the macro pin: x5's delay depends on it, the ring-driven
# ICG's does not. 50 ps 0-100 % is what test_mdll.sch drives (CT) and so what
# every closed-loop run assumes; OpenSTA takes it as the port's transition.
CLK_REF_SLEW_NS = 0.05


def sta(script):
    with tempfile.NamedTemporaryFile("w", suffix=".tcl", delete=False) as f:
        f.write(script)
    try:
        r = subprocess.run(["sta", "-no_init", "-exit", f.name], cwd=ROOT,
                           capture_output=True, text=True)
    finally:
        os.unlink(f.name)
    if "Error" in r.stdout + r.stderr:
        sys.exit("sta failed:\n" + r.stdout + r.stderr)
    return r.stdout


def sections(out):
    """'@@ NAME' markers -> {NAME: [rise_ps, fall_ps]} from report_dcalc."""
    res = {}
    for blk in out.split("@@ ")[1:]:
        d = [float(x) * 1e3 for x in re.findall(r"^Delay = ([0-9.eE+-]+)", blk, re.M)]
        res[blk.split()[0]] = d[:2]
    return res


def top_design(run, corner):
    libs = [stdcell_lib(corner)] + [
        f"{macros()}/{b}/lib/nom_{corner}/{b}__nom_{corner}.lib" for b in BLOCKS]
    return ("".join(f"read_liberty {l}\n" for l in libs)
            + f"read_verilog {run}/final/nl/mdll.nl.v\nlink_design mdll\n"
            + f"read_spef {run}/final/spef/nom/mdll.nom.spef\n"
            + f"set_input_transition {CLK_REF_SLEW_NS} [get_ports clk_ref]\n")


def gate_delays(run, corner):
    # The top-level div net's capacitance includes clk_gen's own output pin
    # (its .lib: the internal div wire and x11.x7), which clk_gen's SPEF
    # already holds -- only the rest is the load outside the block.
    div_load = pin_caps(run, corner, "div", total=True) - pin_caps(run, corner, "div", driver=True)
    clk = sta(f"read_liberty {stdcell_lib(corner)}\n"
              f"read_liberty {CUSTOM_LIB}\n"
              f"read_verilog {macros()}/clk_gen/nl/clk_gen.nl.v\nlink_design clk_gen\n"
              f"read_spef {macros()}/clk_gen/spef/nom/clk_gen.nom.spef\n"
              f"set_load {div_load} [get_ports div]\n"
              "puts {@@ ICG}\nreport_dcalc -from [get_pins x11.x5/CLK] -to [get_pins x11.x5/GCLK] -digits 4\n"
              "puts {@@ BUF}\nreport_dcalc -from [get_pins x11.x9/A] -to [get_pins x11.x9/X] -digits 4\n")
    top = sta(top_design(run, corner)
              + "puts {@@ X5}\nreport_dcalc -from [get_pins x5/CLK] -to [get_pins x5/GCLK] -digits 4\n"
              + "puts {@@ X7}\nreport_dcalc -from [get_pins x7/A] -to [get_pins x7/X] -digits 4\n")
    s = sections(clk) | sections(top)
    return [a + b for a, b in zip(s["ICG"], s["BUF"])], [a + b for a, b in zip(s["X5"], s["X7"])]


_caps = {}


def pin_caps(run, corner, net, total=False, driver=False):
    """{load pin: pF} of a top-level net (from STA, so macro pins come from
    their .lib), the net's total capacitance, or its driver pin's."""
    key = (run, corner, net)
    if key not in _caps:
        out = sta(top_design(run, corner) + f"report_net -digits 5 {net}\n")
        loads = dict((p.replace("/", ":"), float(c)) for p, c in
                     re.findall(r"^ (\S+) input \([^)]*\) ([0-9.]+)", out, re.M))
        tot = float(re.search(r"Total capacitance: ([0-9.]+)", out).group(1))
        drv = re.search(r"^ \S+ output \([^)]*\) ([0-9.]+)", out, re.M)
        _caps[key] = (loads, tot, float(drv.group(1)) if drv else 0.0)
    loads, tot, drv = _caps[key]
    return drv if driver else tot if total else loads


def spef_nets(path):
    s = open(path).read()
    names = dict(re.findall(r"^(\*\d+)\s+(\S+)$", s, re.M))
    expand = lambda t: re.sub(r"\*\d+", lambda m: names.get(m.group(0), m.group(0)), t)
    nets = {}
    for m in re.finditer(r"^\*D_NET (\S+) \S+\n(.*?)^\*END", s, re.M | re.S):
        body = m.group(2)
        conn = re.search(r"\*CONN\n(.*?)(?=^\*CAP|^\*RES|\Z)", body, re.M | re.S).group(1)
        driver = None
        for line in conn.splitlines():
            t = line.split()
            if not t:
                continue
            if (t[0] == "*I" and t[2] == "O") or (t[0] == "*P" and t[2] == "I"):
                driver = expand(t[1])
        caps, res = defaultdict(float), []
        for sec, rows in re.findall(r"^\*(CAP|RES)\n(.*?)(?=^\*[A-Z]|\Z)", body, re.M | re.S):
            for line in rows.splitlines():
                t = line.split()
                if sec == "CAP" and len(t) == 3:
                    caps[expand(t[1])] += float(t[2])
                elif sec == "CAP" and len(t) == 4:      # coupling: count it grounded
                    caps[expand(t[1])] += float(t[3])
                elif sec == "RES" and len(t) == 4:
                    res.append((expand(t[1]), expand(t[2]), float(t[3])))
        nets[expand(m.group(1))] = dict(driver=driver, caps=caps, res=res)
    return nets


def elmore(net, loads):
    """Elmore delay (ps) from the driver to every node of an RC tree."""
    adj = defaultdict(list)
    for a, b, r in net["res"]:
        adj[a].append((b, r))
        adj[b].append((a, r))
    cap = defaultdict(float, net["caps"])
    for p, c in loads.items():
        cap[p] += c
    parent, order, seen = {}, [], {net["driver"]}
    stack = [net["driver"]]
    while stack:
        n = stack.pop()
        order.append(n)
        for m, r in adj[n]:
            if m not in seen:
                seen.add(m)
                parent[m] = (n, r)
                stack.append(m)
    down = defaultdict(float)
    for n in reversed(order):
        down[n] += cap[n]
        if n in parent:
            down[parent[n][0]] += down[n]
    t = {net["driver"]: 0.0}
    for n in order:
        if n in parent:
            p, r = parent[n]
            t[n] = t[p] + r * down[n]              # ohm * pF = ps
    return t


def main():
    global TECH
    args = sys.argv[1:]
    if "--cmos5l" in args:
        args.remove("--cmos5l")
        TECH = "sg13cmos5l"
    runs = sorted(glob.glob(os.path.join(ROOT, f"pnr/runs/{TECHS[TECH][0]}_*")))
    run = os.path.relpath(args[0] if args else runs[-1], ROOT)
    print(f"{run}  (macros: {macros()}/RUNS.txt)\n")
    nets = spef_nets(os.path.join(ROOT, run, "final/spef/nom/mdll.nom.spef"))
    worst = 0.0
    for c in CORNERS:
        g_div, g_ref = gate_delays(run, c)
        r = {}
        for name in ("div", "clk_ref_g", "clk_ref"):
            r[name] = elmore(nets[name], pin_caps(run, c, name))
        in_skew = r["clk_ref"]["x5:CLK"] - r["clk_ref"]["x1:clk_ref"]
        print(f"{c}:  gates (rise/fall)  div x11.x5+x11.x9 {g_div[0]:.0f}/{g_div[1]:.0f} ps,"
              f"  clk_ref_g x5+x7 {g_ref[0]:.0f}/{g_ref[1]:.0f} ps")
        print(f"{'':16s}clk_ref to x5/CLK minus to x1/clk_ref: {in_skew:+.1f} ps")
        for sink_div, sink_g, what in (("x2:Clk_out", "x2:Clk_ref", "tdc "),
                                       ("x3:div", "x3:clk_ref", "bbpd")):
            rd, rg = r["div"][sink_div], r["clk_ref_g"][sink_g]
            delta = in_skew + (g_ref[0] - g_div[0]) + (rg - rd)
            worst = max(worst, abs(delta))
            print(f"{'':16s}{what}: routes div {rd:5.1f} / clk_ref_g {rg:5.1f} ps;"
                  f"  clk_ref_g - div = {delta:+6.1f} ps (rising)")
    print(f"\nworst |clk_ref_g - div| = {worst:.1f} ps; gate {GATE_PS} ps: "
          + ("PASS" if worst <= GATE_PS else "FAIL"))
    return 0 if worst <= GATE_PS else 1


if __name__ == "__main__":
    sys.exit(main())
