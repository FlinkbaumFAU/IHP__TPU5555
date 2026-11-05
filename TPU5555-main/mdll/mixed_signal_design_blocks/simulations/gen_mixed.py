#!/usr/bin/env python3
"""Build the mixed-signal MDLL deck: lock_ctrl and dlf in Verilator, the rest
at transistor level.

Why: in the transistor-level closed loop (make mdll_sim) the two synthesised
controllers are two thirds of the transistors, and a 30 ns benchmark ran 5.7x
faster per time step with them stubbed out -- matrix factorisation grows faster
than linearly with circuit size. Here they run as their RTL inside ngspice
instead, through the XSPICE d_cosim code model (Verilator backend, the pattern
passionateV's sim/ngspice/link_tb_dcosim.spice uses).

What is kept exact, and what is not:

  * Everything analog or timing-critical stays at transistor level: clk_gen,
    the whole TDC (rings, edge lock, phase detector, counters, the capture
    race), bbpd's comparator and the clk_ref replica gate.
  * Verilator is zero-delay, so every output would change at the clock event
    that launched it. Each output goes through a d_buffer with the rise/fall
    clock-to-port delay post-PnR STA reports for the hardened block
    (<block>/simulations/output_delays.json, `make -C <block> delays`) at the
    chosen corner, then a dac_bridge. The port timing the loop sees is
    therefore the hardened netlist's.
  * NOT modelled: setup/hold and metastability at the Verilator inputs. Every
    input is a clean event at its V_DD/2 crossing. lock_ctrl samples inj and
    busy asynchronously on purpose, and dlf samples comp half a period after
    it settles; those are covered by lock_ctrl's `make formal` / `sim_acq`
    and by STA, not by this run.
  * The RTL is simulated, not the mapped netlist; lec_lock_ctrl.tcl and
    lec_dlf.tcl prove the two equivalent.

The deck is the netlisted test_mdll.sch (build/test_mdll.spice) with the two
.INCLUDEs of the structural models swapped for the co-simulation wrappers and
the raw file renamed, so the stimulus, the save list and the acceptance gate
(simulations/check_mdll.py) are exactly those of the transistor-level run.

Corners. --corner picks the STA output delays, --spice-corner (default: the
same) the transistor models, supply and temperature, as the SPICE twins of the
blocks' LibreLane signoff corners (see CORNERS). Everything in the deck that
depends on V_DD follows it: the supply and stimulus through .PARAM VDD, and
the three places that carry a number -- the d_cosim output bridge's high
level, the input bridge's thresholds and the behavioural dco_decode's
vhi/vth instance parameters.
"""

import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUILD = os.path.join(ROOT, "build", "mixed")
DECK_IN = os.path.join(ROOT, "build", "test_mdll.spice")
DECK_OUT = os.path.join(ROOT, "build", "test_mdll_mixed.spice")
RAW_IN = "/simulations/test_mdll.raw"
RAW_OUT = "/simulations/test_mdll_mixed.raw"

# SPICE twins of the STA signoff corners (nom_typ_1p20V_25C,
# nom_slow_1p08V_125C, nom_fast_1p32V_m40C): MOS models, V_DD, temperature.
# Same table as clk_gen/simulations/gate_check.py. ngspice runs at its default
# 27 C unless .TEMP says otherwise; test_mdll.sch's `.TEMP 27` is replaced.
CORNERS = {"typ": ("mos_tt", 1.20, 27), "slow": ("mos_ss", 1.08, 125),
           "fast": ("mos_ff", 1.32, -40)}
# Bridge thresholds: a CMOS input switches near V_DD/2; a narrow window keeps
# the bridge from adding its own delay. adc_bridge defaults to 1 ns rise/fall
# delay and d_cosim to a nonzero output delay -- both are pinned to 1 ps so the
# STA-derived d_buffers carry all of the timing.
IN_WIN = 0.05            # V on either side of V_DD/2
T_EDGE = 50e-12          # dac_bridge output rise/fall: a lightly loaded cell
T_MIN = 1e-12

# name: structural model it replaces, RTL, ports in the model's order, and
# where each output's delay comes from in the hardened block's STA.
BLOCKS = {
    "lock_ctrl": dict(
        model="lock_ctrl/simulations/lock_ctrl.spice",
        rtl=["lock_ctrl/rtl/lock_ctrl.v"],
        delays="lock_ctrl/simulations/output_delays.json",
        ins=["clk", "resetb", "inj", "busy", "hit", "tdc_s[7:0]", "tdc_f[7:0]", "code[7:0]"],
        outs=["start", "sel", "load", "seed[7:0]", "locked"],
        sta_port=lambda p: p,
    ),
    # dlf lives inside bbpd; its code[] leaves the macro as bbpd's C[].
    "dlf": dict(
        model="bbpd/simulations/dlf.spice",
        rtl=["bbpd/rtl/dlf.v"],
        delays="bbpd/simulations/output_delays.json",
        ins=["clk_ref", "clk", "resetb", "comp", "load", "seed[7:0]"],
        outs=["code[7:0]"],
        sta_port=lambda p: p.replace("code[", "C["),
    ),
}


def bits(p):
    m = re.fullmatch(r"(\w+)\[(\d+):(\d+)\]", p)
    if not m:
        return [p]
    hi, lo = int(m.group(2)), int(m.group(3))
    return [f"{m.group(1)}[{i}]" for i in range(hi, lo - 1, -1)]


def model_ports(path, name):
    txt = open(path).read().replace("\n+", " ")
    for line in txt.splitlines():
        t = line.split()
        if t[:2] == [".subckt", name]:
            return t[2:]
    sys.exit(f"no .subckt {name} in {path}")


def ident(p):
    """A bus bit as a Verilog/XSPICE-safe identifier: seed[3] -> seed_3."""
    return p.replace("[", "_").replace("]", "")


# All co-simulated blocks share ONE Verilator library and ONE d_cosim instance.
# Two separately built libraries in one ngspice process crash it (segfault
# right after "Duplicate value 1 in cm_irreversible()"): both export the same
# Verilator runtime symbols, and linking with -Bsymbolic does not help. So the
# instance lives in the first block's wrapper, and every other block's wrapper
# only forwards its ports to it over .GLOBAL nodes (cosim_<block>_<n>). That
# is sound only while each block is instantiated exactly once in the deck,
# which main() checks.
HOST = "lock_ctrl"


def sname(name, p):
    """Shim port for bit p of block name. Single underscores only: Verilator
    escapes a double one (__ -> ___05F) in the names it writes to inputs.h."""
    return f"{name}_{ident(p)}"


def port_order(kind):
    """The order d_cosim really uses: Verilator's generated inputs.h /
    outputs.h, NOT the Verilog declaration order -- Verilator moves clocks and
    resets to the front. Positional connections built from the declaration
    order silently cross-wire the blocks (dlf's clk landed on lock_ctrl's inj)."""
    path = os.path.join(BUILD, "mixed_shim_obj_dir", f"{kind}.h")
    names = re.findall(r"VL_DATA\(\d+,(\w+),", open(path).read())
    if not names:
        sys.exit(f"no ports found in {path}")
    return names


def expand(blk):
    return ([p for b in blk["ins"] for p in bits(b)],
            [p for b in blk["outs"] for p in bits(b)])


def write_shim():
    """One scalar-port module around all blocks; d_cosim maps positionally:
    every block's inputs (block order), then every block's outputs."""
    decl, body = [], []
    for name, blk in BLOCKS.items():
        ins, _ = expand(blk)
        decl += [f"  input  wire {sname(name, p)}" for p in ins]
    for name, blk in BLOCKS.items():
        _, outs = expand(blk)
        decl += [f"  output wire {sname(name, p)}" for p in outs]
    for name, blk in BLOCKS.items():
        conns = []
        for p in blk["ins"] + blk["outs"]:
            b = [sname(name, x) for x in bits(p)]
            base = re.sub(r"\[.*", "", p)
            conns.append(f"    .{base}({b[0] if len(b) == 1 else '{' + ', '.join(b) + '}'})")
        body.append(f"  {name} u_{name} (\n" + ",\n".join(conns) + "\n  );")
    L = ["// Generated by simulations/gen_mixed.py -- do not edit.",
         "// Every co-simulated block behind one scalar-port module, for ONE",
         "// ngspice d_cosim instance (see gen_mixed.py on why only one).",
         "`timescale 1ns/1ps",
         "module mixed_shim (", ",\n".join(decl), ");"] + body + ["endmodule"]
    path = os.path.join(BUILD, "mixed_shim.v")
    open(path, "w").write("\n".join(L) + "\n")
    return path


def build_so(shim):
    so = os.path.join(BUILD, "mixed_shim.so")
    srcs = [shim] + [os.path.join(ROOT, r) for blk in BLOCKS.values() for r in blk["rtl"]]
    if os.path.exists(so) and all(os.path.getmtime(so) > os.path.getmtime(s) for s in srcs):
        return so
    if os.path.exists(so):
        os.remove(so)
    cmd = ["ngspice", "vlnggen", "--", "-Wno-fatal", "--top-module", "mixed_shim"] + srcs
    log = os.path.join(BUILD, "vlnggen.log")
    with open(log, "w") as f:
        subprocess.run(cmd, cwd=BUILD, stdout=f, stderr=subprocess.STDOUT)
    if not os.path.exists(so):
        sys.exit(f"vlnggen did not produce {so} -- see {log}")
    return so


def node(name, i):
    """Plain node for port i of a block: local in the host, global elsewhere."""
    return f"n{i}" if name == HOST else f"cosim_{name}_{i}"


def wrappers(so, corner, vdd):
    L = ["** Co-simulation wrappers: every block below runs in ONE Verilator model",
         f"** ({so}), with {corner}-corner STA output delays.",
         "** Generated by simulations/gen_mixed.py -- do not edit.", ""]
    glob = []
    for name, blk in BLOCKS.items():
        if name != HOST:
            glob += [node(name, i) for i in range(len(blk["ports"]))]
    if glob:
        L.append(".GLOBAL " + " ".join(glob))
    in_node, out_node, dly = {}, {}, []
    for name, blk in BLOCKS.items():
        d = json.load(open(os.path.join(ROOT, blk["delays"])))
        ins, outs = expand(blk)
        idx = {p: i for i, p in enumerate(blk["ports"])}
        for p in ins:
            in_node[sname(name, p)] = node(name, idx[p])
        for p in outs:
            tco = d["outputs"][blk["sta_port"](p)][corner]
            if tco["rise"] is None or tco["fall"] is None:
                sys.exit(f"{blk['delays']}: no {corner} delay for {p}")
            sp = sname(name, p)
            q, qd = f"q_{sp}", f"qd_{sp}"
            out_node[sp] = node(name, idx[p])
            dly += [f"a_{qd} {q} {qd} m_{qd}",
                    f".model m_{qd} d_buffer rise_delay={tco['rise']}n fall_delay={tco['fall']}n"]
        blk["run"] = d["run"]
    order_in, order_out = port_order("inputs"), port_order("outputs")
    if sorted(order_in) != sorted(in_node) or sorted(order_out) != sorted(out_node):
        sys.exit("Verilator's port list does not match the blocks' -- rebuild the shim")
    a_in = [in_node[x] for x in order_in]
    d_in = [f"d_{x}" for x in order_in]
    q_out = [f"q_{x}" for x in order_out]
    n_out = [(f"qd_{x}", out_node[x]) for x in order_out]
    for name, blk in BLOCKS.items():
        formal = [f"p{i}" for i in range(len(blk["ports"]))]
        L += [f"* {name}: delays from {blk['delays']} (run {blk['run']}); replaces {blk['model']}",
              f".subckt {name} {' '.join(formal)}",
              f"* pN = {' '.join(blk['ports'])}",
              # XSPICE's [ ... ] vector syntax cannot take node names that
              # contain brackets, and after subckt expansion pN IS the parent's
              # net (seed[7], ...). A 0 V source moves each port onto a plain
              # node -- local nN in the host, global cosim_<block>_N elsewhere.
              *[f"v_p{i} p{i} {node(name, i)} 0" for i in range(len(formal))]]
        if name == HOST:
            L += [f"a_in [ {' '.join(a_in)} ] [ {' '.join(d_in)} ] cosim_adc",
                  f".model cosim_adc adc_bridge in_low={vdd / 2 - IN_WIN:g}"
                  f" in_high={vdd / 2 + IN_WIN:g}"
                  f" rise_delay={T_MIN} fall_delay={T_MIN}",
                  f"a_dut [ {' '.join(d_in)} ] [ {' '.join(q_out)} ] cosim_rtl",
                  f'.model cosim_rtl d_cosim simulation="{so}" delay={T_MIN}',
                  *dly,
                  f"a_out [ {' '.join(q for q, _ in n_out)} ] [ {' '.join(n for _, n in n_out)} ] cosim_dac",
                  f".model cosim_dac dac_bridge out_low=0 out_high={vdd:g}"
                  f" t_rise={T_EDGE} t_fall={T_EDGE}"]
        L += [".ends", ""]
    path = os.path.join(BUILD, "cosim.spice")
    open(path, "w").write("\n".join(L))
    return path


def set_corner(deck, lib, vdd, temp):
    """Switch the netlisted tt / 1.2 V / 27 C deck to another SPICE corner."""
    for pat, new in [
            (r"(?m)^\.LIB cornerMOSlv\.lib mos_tt$", f".LIB cornerMOSlv.lib {lib}"),
            (r"(?m)^\.PARAM VDD=1\.2$", f".PARAM VDD={vdd:g}"),
            (r"(?m)^\.TEMP 27$", f".TEMP {temp:g}"),
            # dco_decode's outputs are B-sources at a fixed level: an instance
            # parameter overrides its 1.2 V subckt default.
            # (xschem wraps the instance line or not, depending on its length)
            (r"(?m)^(\+ dco_decode|x\S* .* dco_decode)$", rf"\1 vhi={vdd:g} vth={vdd / 2:g}")]:
        deck, n = re.subn(pat, new, deck)
        if n != 1:
            sys.exit(f"{DECK_IN}: expected one line matching {pat}")
    return deck


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--corner", choices=["typ", "slow", "fast"], default="typ",
                    help="which STA corner's output delays to inject")
    ap.add_argument("--spice-corner", choices=list(CORNERS),
                    help="MOS models, V_DD and temperature (default: --corner)")
    a = ap.parse_args()
    a.spice_corner = a.spice_corner or a.corner
    lib, vdd, temp = CORNERS[a.spice_corner]
    if not os.path.exists(DECK_IN):
        sys.exit(f"missing {DECK_IN} -- run `make build/test_mdll.spice`")
    os.makedirs(BUILD, exist_ok=True)

    deck = open(DECK_IN).read()
    for name, blk in BLOCKS.items():
        blk["ports"] = model_ports(os.path.join(ROOT, blk["model"]), name)
        ins, outs = expand(blk)
        if blk["ports"] != ins + outs:
            sys.exit(f"{name}: port order in {blk['model']} is\n  {blk['ports']}\n"
                     f"but gen_mixed.py expects\n  {ins + outs}")
        # One instance only (the shared d_cosim / .GLOBAL nodes assume it).
        uses = re.findall(rf"(?m)^x\S+ .* {name}\s*$", deck.replace("\n+", " "))
        if len(uses) != 1:
            sys.exit(f"{name} is instantiated {len(uses)} times in {DECK_IN}; "
                     "the shared co-simulation instance supports exactly one")
    so = build_so(write_shim())
    wrap = wrappers(so, a.corner, vdd)
    for name, blk in BLOCKS.items():
        inc = f".INCLUDE {os.path.join(ROOT, blk['model'])}"
        if deck.count(inc) != 1:
            sys.exit(f"{DECK_IN} does not include {blk['model']} exactly once")
        deck = deck.replace(inc, f".INCLUDE {wrap}" if name == HOST
                            else f"* {name}: see {os.path.basename(wrap)}")
        print(f"{name:10s} -> Verilator, delays: {a.corner} ({blk['delays']})")

    if deck.count(RAW_IN) != 1:
        sys.exit(f"{DECK_IN}: expected one raw path ending in {RAW_IN}")
    deck = deck.replace(RAW_IN, RAW_OUT)

    # This deck's operating point is marginal under KLU: adding one flop to
    # bbpd (the late flag) made it fail with "singular matrix" on internal
    # flop/PSP nodes in the TDC and "Transient op failed, timestep too small",
    # while the same deck converged without KLU or with a shunt. 1 TOhm from
    # every node to ground (~1 pA at VDD) keeps KLU's speed and the OP solid.
    if deck.count(".OPTIONS KLU\n") != 1:
        sys.exit(f"{DECK_IN}: expected one '.OPTIONS KLU' line")
    deck = deck.replace(".OPTIONS KLU\n", ".OPTIONS KLU\n.OPTIONS RSHUNT=1e12\n")
    deck = set_corner(deck, lib, vdd, temp)
    print(f"SPICE corner: {a.spice_corner} ({lib}, {vdd:g} V, {temp:g} C)")
    head = ("** Mixed-signal variant of test_mdll -- generated by simulations/gen_mixed.py.\n"
            f"** {', '.join(BLOCKS)} run in Verilator with {a.corner}-corner STA output delays;\n"
            f"** transistors at {lib}, {vdd:g} V, {temp:g} C.\n")
    open(DECK_OUT, "w").write(head + deck)
    print(f"wrote {os.path.relpath(DECK_OUT, ROOT)}")


if __name__ == "__main__":
    main()
