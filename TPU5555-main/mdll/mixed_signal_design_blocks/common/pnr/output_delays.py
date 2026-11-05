#!/usr/bin/env python3
"""Clock-to-output delay of every output port of a hardened block.

Verilator is a zero-delay simulator: in the mixed-signal MDLL run
(simulations/gen_mixed.py) a registered output of lock_ctrl or dlf changes at
the very clock event that launched it. Every output of those blocks is
registered (or a few gates behind a register), so its whole clock-pin-to-port
path collapses to one number per edge -- clock insertion + Tco + logic + wire
-- which post-PnR STA reports as the data arrival time at the port, referenced
to the clock source with propagated clocks. An XSPICE d_buffer with those
rise/fall delays ahead of the dac_bridge reproduces the port timing the
transistor-level netlist would have; no SDF is needed.

Adapted from passionateV's hardware/output_delays.py. Rather than re-derive the
liberty / SPEF / SDC lists, it replays what LibreLane's post-PnR STA step read
(each corner's sta.log names every file) in one multi-corner OpenSTA session:

    typ   nom_typ_1p20V_25C
    slow  nom_slow_1p08V_125C
    fast  nom_fast_1p32V_m40C

and reports, per output port and corner, the late (-path_delay max) arrival of
a rising and of a falling transition. Ports with no clocked path (tie-offs,
purely combinational feed-throughs) are listed with null delays.

--from-launch-clock reports the arrival minus that of the launching flop's
clock pin instead: clock-to-Q + logic + wire, without the clock's insertion
delay. That is the right number when the Verilator model is clocked from a
node INSIDE the block's clock network rather than from its clock port --
bbpd's dlf runs on clk_dlf, clk_ref after pd.sch's ~1.2 ns delay chain, and
in the mixed deck that chain is transistor-level already; measured from the
clock source it would count twice.

Needs OpenSTA's `sta` on PATH (the nix profile, or a LibreLane dev shell):

    common/pnr/output_delays.py [--from-launch-clock] <block>/pnr/runs/<RUN> <out.json>
"""

import json
import os
import re
import subprocess
import sys
import tempfile

CORNERS = {"typ": "typ", "slow": "slow", "fast": "fast"}

_READ_RE = {
    "libs": re.compile(r"Reading cell library .* at '([^']+)'"),
    "verilog": re.compile(r"Reading Verilog model at '([^']+)'"),
    "sdc": re.compile(r"Reading design constraints file at '([^']+)'"),
    "spef": re.compile(r"parasitics for the .* corner at '([^']+)'"),
}


def sta_step_dir(run_dir):
    steps = sorted(d for d in os.listdir(run_dir)
                   if "stapostpnr" in d and os.path.isdir(os.path.join(run_dir, d)))
    if not steps:
        sys.exit(f"no *stapostpnr* step under {run_dir} -- did the run finish?")
    return os.path.join(run_dir, steps[-1])


def corner_dirs(sta_dir):
    dirs = [d for d in os.listdir(sta_dir)
            if os.path.exists(os.path.join(sta_dir, d, "sta.log"))]
    out = {}
    for key, kw in CORNERS.items():
        cands = sorted(d for d in dirs if kw in d)
        if not cands:
            sys.exit(f"no STA corner matching '{kw}' in {sta_dir}")
        out[key] = cands[0]
    return out


def scrape(sta_dir, cdir):
    found = {k: [] for k in _READ_RE}
    for line in open(os.path.join(sta_dir, cdir, "sta.log")):
        for k, rx in _READ_RE.items():
            m = rx.search(line)
            if m:
                found[k].append(m.group(1))
    return found


def main():
    args = sys.argv[1:]
    from_launch = "--from-launch-clock" in args
    args = [a for a in args if a != "--from-launch-clock"]
    if len(args) != 2:
        sys.exit("usage: output_delays.py [--from-launch-clock] <run_dir> <out.json>")
    run_dir, out_path = args

    nls = [f for f in os.listdir(os.path.join(run_dir, "final", "nl"))
           if f.endswith(".nl.v")]
    if len(nls) != 1:
        sys.exit(f"expected one final/nl/*.nl.v, found {nls}")
    netlist = os.path.join(run_dir, "final", "nl", nls[0])
    design = nls[0][:-len(".nl.v")]

    sta_dir = sta_step_dir(run_dir)
    cdirs = corner_dirs(sta_dir)
    scraped = {k: scrape(sta_dir, d) for k, d in cdirs.items()}
    for k, s in scraped.items():
        if not (s["libs"] and s["sdc"] and s["spef"]):
            sys.exit(f"could not recover libs/sdc/spef from {cdirs[k]}/sta.log")

    L = ["define_corners " + " ".join(CORNERS)]
    for c in CORNERS:
        for lib in scraped[c]["libs"]:
            L.append(f"read_liberty -corner {c} {{{lib}}}")
    L.append(f"read_verilog {{{netlist}}}")
    L.append(f"link_design {design}")
    for c in CORNERS:
        L.append(f"read_spef -corner {c} {{{scraped[c]['spef'][0]}}}")
    L += [f"read_sdc {{{scraped['typ']['sdc'][0]}}}",
          "set_propagated_clock [all_clocks]",
          "foreach out [all_outputs] {",
          "  set nm [get_full_name $out]",
          "  puts \"PORT $nm\"",
          "  foreach c {" + " ".join(CORNERS) + "} {",
          "    foreach edge {rise fall} {",
          "      set paths [find_timing_paths -${edge}_to $out -path_delay max"
          " -corner $c -group_path_count 1]",
          "      if { [llength $paths] } {",
          # The arrival at the path's last point: the output port itself.
          "        set pts [get_property [lindex $paths 0] points]",
          "        set arr [get_property [lindex $pts end] arrival]",
          # The first point is the launching flop's clock pin.
          ("        set arr [expr {$arr - [get_property [lindex $pts 0] arrival]}]"
           if from_launch else ""),
          "        puts \"TCO $c $edge $nm $arr\"",
          "      }",
          "    }",
          "  }",
          "}",
          "exit"]

    with tempfile.NamedTemporaryFile("w", suffix=".tcl", delete=False) as f:
        f.write("\n".join(L) + "\n")
        tcl = f.name
    res = subprocess.run(["sta", "-no_splash", "-exit", tcl],
                         capture_output=True, text=True)
    os.unlink(tcl)
    if res.returncode != 0:
        sys.stderr.write(res.stdout + res.stderr)
        sys.exit(f"sta failed (exit {res.returncode})")

    outputs = {}
    for line in res.stdout.splitlines():
        tok = line.split()
        if tok[:1] == ["PORT"]:
            outputs.setdefault(tok[1], {c: {"rise": None, "fall": None} for c in CORNERS})
        elif tok[:1] == ["TCO"]:
            _, c, edge, port, arr = tok
            outputs[port][c][edge] = round(float(arr), 4)
    if not outputs:
        sys.stderr.write(res.stdout + res.stderr)
        sys.exit("sta reported no output ports")

    report = {
        "design": design,
        "run": os.path.basename(os.path.normpath(run_dir)),
        "corners": cdirs,
        "units": ("ns, arrival at the port from the launching flop's clock pin "
                  "(clock-to-Q + logic + wire), late (max) path" if from_launch else
                  "ns, arrival at the port from the clock source edge, "
                  "propagated clocks, late (max) path"),
        "outputs": dict(sorted(outputs.items())),
    }
    with open(out_path, "w") as f:
        json.dump(report, f, indent=2)
    timed = sum(1 for v in outputs.values() if v["typ"]["rise"] is not None)
    print(f"wrote {out_path}: {len(outputs)} outputs ({timed} timed) from {report['run']}")


if __name__ == "__main__":
    main()
