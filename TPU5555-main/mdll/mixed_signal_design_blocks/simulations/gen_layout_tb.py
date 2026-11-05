#!/usr/bin/env python3
"""The MDLL closed loop on the layout: full-chip LVS and its extracted netlist.

Three subcommands, driven by the root Makefile (`make lvs_full`,
`make layout_sim`, `make pex_sim`):

  cdl   Concatenates the complete LVS reference: the top-level CDL, the four
        blocks' CDLs (build/macros/<block>/cdl), custom_stdcell.cdl and the
        PDK's sg13g2 standard-cell CDL. Fails on a duplicate or missing subckt,
        and re-reads the written file to prove it is complete (LibreLane
        3.0.16's own concatenation lost its last <= 8 KiB, see CLAUDE.md).
        --no-fill leaves out the instances of device-less cells (the filler
        cells), for Calibre LVS: they have nothing in the layout to match.

  tb    Builds the layout testbench from the netlisted schematic deck
        (build/test_mdll.spice):
          - keeps the testbench part (header, stimulus, .GLOBAL, .OPTIONS,
            .control) and drops every subckt definition the schematic `mdll`
            brings along, plus the .INCLUDEs of the stdcell libraries and of
            the generated RTL models (dco_decode, dlf, counter, lock_ctrl):
            in the layout those are real transistors;
          - includes the extracted top cell instead, converted for ngspice
            (KLayout's `M` devices become `X` instances of the PDK's
            sg13_lv_nmos/pmos subckts, `$` leaves the names);
          - re-instantiates x1 with the extracted port order, mapped BY NAME
            from the schematic instance; a missing or extra port fails;
          - ties the extracted power pins to the deck's VDD/VSS;
          - names the extracted top cell's internal nets after the schematic's
            (load, div, tdc_*, ...): the layout labels only the pins, so
            KLayout calls them $NNN; the LVS cross-reference pairs them. The
            .control `save` lines and check_mdll.py then work unchanged, and
            every name they use is checked to exist;
          - leaves out the antenna cells' diodes (see --keep-antenna).

  pex   The same testbench on a Calibre xRC netlist (R+C+CC, flat, written
        with SOURCENAMES): its .pex/.pxi includes inlined, MOS devices as X
        instances, '\' and '@' left out of names. The schematic names
        survive, but each net is a network of nodes, so every net the .control
        `save` lines name gets a 0 V probe from a node of that name to its
        first gate (receiver) node. --ideal-supply leaves out the VPWR/VGND
        networks (~70% of the resistors) and ties their nodes to the ports.
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from gen_mixed import CORNERS  # noqa: E402  -- one table for every closed-loop deck
BLOCKS = ["clk_gen", "tdc", "bbpd", "lock_ctrl"]


def die(msg):
    sys.exit(f"gen_layout_tb.py: ERROR: {msg}")


# --- CDL ----------------------------------------------------------------------

def logical_lines(text):
    """SPICE lines with '+' continuations joined."""
    out = []
    for ln in text.splitlines():
        if ln.startswith("+") and out:
            out[-1] += " " + ln[1:]
        else:
            out.append(ln)
    return out


def subckts(text):
    """{name: [instance master names]} of a CDL/SPICE file (case-folded)."""
    res, cur = {}, None
    for ln in logical_lines(text):
        w = ln.split()
        if not w:
            continue
        k = w[0].lower()
        if k == ".subckt":
            cur = w[1].lower()
            if cur in res:
                die(f"subckt {w[1]} defined twice in one file")
            res[cur] = []
        elif k == ".ends":
            cur = None
        elif cur and k[0] == "x":
            # the master is the last word that is not a parameter
            m = [x for x in w[1:] if "=" not in x]
            res[cur].append(m[-1].lower())
    return res


def empty_subckts(text):
    """Names (case-folded) of the subckts with no device or instance at all."""
    res, cur = set(), None
    for ln in logical_lines(text):
        w = ln.split()
        if not w or w[0].startswith("*"):
            continue
        k = w[0].lower()
        if k == ".subckt":
            cur = w[1].lower()
            res.add(cur)
        elif k == ".ends":
            cur = None
        elif cur:
            res.discard(cur)
    return res


def drop_instances(text, masters):
    """text without the instances of `masters`; returns (text, count)."""
    out, n = [], 0
    for ln in logical_lines(text):
        w = ln.split()
        if w and w[0][0] in "xX" and \
                [x for x in w[1:] if "=" not in x][-1].lower() in masters:
            n += 1
        else:
            out.append(ln)
    return "\n".join(out) + "\n", n


def cmd_cdl(a):
    srcs = [a.top] + [os.path.join(a.macros, b, "cdl", f"{b}.cdl") for b in BLOCKS] \
        + [a.custom, a.stdcell]
    texts = {s: open(s).read() for s in srcs}
    if a.no_fill:
        # KLayout's LVS ignores device-less cells; Calibre reports every
        # instance of one as unmatched, since the layout has nothing there.
        fill = set().union(*(empty_subckts(t) for t in texts.values()))
        dropped = 0
        for s in srcs:
            texts[s], n = drop_instances(texts[s], fill)
            dropped += n
        print(f"--no-fill: left out {dropped} instances of {sorted(fill)}")
    defined, parts = {}, []
    for s in srcs:
        txt = texts[s]
        for name in subckts(txt):
            if name in defined:
                die(f"subckt {name} in both {defined[name]} and {s}")
            defined[name] = s
        parts.append(f"* ===== {s}\n{txt.rstrip()}\n")
    body = "\n".join(parts) + "\n* ===== end of the concatenated CDL\n"
    with open(a.out, "w") as f:
        f.write(body)

    # Re-read what is on disk: every subckt there, every master defined.
    back = subckts(open(a.out).read())
    if set(back) != set(defined):
        die(f"{a.out} lost subckts: {sorted(set(defined) - set(back))}")
    if not open(a.out).read().rstrip().endswith("end of the concatenated CDL"):
        die(f"{a.out} is truncated")
    used = {m for ms in back.values() for m in ms}
    missing = sorted(used - set(back))
    if missing:
        die(f"masters used but not defined: {missing}")
    top = subckts(texts[a.top])
    if len(top) != 1:
        die(f"{a.top}: expected exactly one subckt, found {sorted(top)}")
    unused = sorted(set(back) - used - set(top))
    print(f"{a.out}: {len(back)} subckts from {len(srcs)} files, "
          f"{os.path.getsize(a.out)} bytes; all {len(used)} masters defined; "
          f"{len(unused)} library cells unused")


# --- extracted netlist -> ngspice --------------------------------------------

def parse_extracted(path):
    """KLayout's extracted netlist: {name: (ports, body lines)}, top-down."""
    cells, cur = {}, None
    for ln in logical_lines(open(path).read()):
        w = ln.split()
        if not w or ln.startswith("*"):
            continue
        k = w[0].lower()
        if k == ".subckt":
            cur = w[1]
            cells[cur] = (w[2:], [])
        elif k == ".ends":
            cur = None
        elif cur is not None:
            cells[cur][1].append(ln)
        else:
            die(f"{path}: statement outside a subckt: {ln}")
    return cells


def unesc(n):
    """KLayout escapes '$' (and '[', ']' in some names) with a backslash."""
    return re.sub(r"\\(.)", r"\1", n)


def ngname(n):
    """A net/instance name ngspice reads: '$' (KLayout's unnamed nets, and a
    variable sigil in .control) becomes '_'."""
    return unesc(n).replace("$", "_")


SI = {"T": 1e12, "G": 1e9, "MEG": 1e6, "K": 1e3, "M": 1e-3, "U": 1e-6,
      "N": 1e-9, "P": 1e-12, "F": 1e-15}


def si(v):
    m = re.fullmatch(r"([-+0-9.eE]+)(MEG|[TGKMUNPF])?", v.upper())
    if not m:
        die(f"cannot read value {v}")
    return float(m.group(1)) * SI.get(m.group(2) or "", 1.0)


def params(words):
    return {x.split("=", 1)[0].lower(): si(x.split("=", 1)[1]) for x in words if "=" in x}


def convert(cells, top, rename, keep_antenna=False):
    """ngspice text of the extracted hierarchy, and the flattened device count
    by model. `rename` maps nets of `top` (unescaped layout names) to the names
    the testbench should see."""
    out, local = [], {}
    for name, (ports, body) in cells.items():
        nm = (lambda n: rename.get(unesc(n), ngname(n))) if name == top else ngname
        out.append(f".subckt {ngname(name)} {' '.join(nm(p) for p in ports)}")
        local[name] = {}
        for ln in body:
            w = ln.split()
            k = w[0][0].upper()
            iname = ngname(w[0][1:])
            if k == "X":
                nets = [x for x in w[1:] if "=" not in x]
                out.append(f"X{iname} {' '.join(nm(x) for x in nets[:-1])} {ngname(nets[-1])}")
            elif k == "M":
                # M<name> D G S B <model> L= W= AS= AD= PS= PD= rfmode=
                d, g, s, b, model = w[1:6]
                if model not in ("sg13_lv_nmos", "sg13_lv_pmos"):
                    die(f"unexpected MOS model {model} in {name}")
                p = params(w[6:])
                ps = " ".join(f"{q}={p[q]:.6g}" for q in ("w", "l", "as", "ad", "ps", "pd")
                              if q in p)
                out.append(f"XM{iname} {nm(d)} {nm(g)} {nm(s)} {nm(b)} {model} {ps} "
                           f"ng=1 m={p.get('m', 1):g} rfmode={p.get('rfmode', 0):g}")
                local[name][model] = local[name].get(model, 0) + 1
            elif k == "D":
                # antenna diodes; the PDK subckts take l, w (area l*w,
                # perimeter 2(l+w)); KLayout gives A and P.
                an, ca, model = w[1:4]
                if model not in ("dantenna", "dpantenna"):
                    die(f"unexpected diode model {model} in {name}")
                p = params(w[4:])
                hp = p["p"] / 2
                disc = max(hp * hp - 4 * p["a"], 0.0) ** 0.5
                l_, w_ = (hp + disc) / 2, (hp - disc) / 2
                inst = f"XD{iname} {nm(an)} {nm(ca)} {model} l={l_:.6g} w={w_:.6g}"
                if keep_antenna:
                    out.append(inst)
                    local[name][model] = local[name].get(model, 0) + 1
                else:
                    out.append("* antenna diode left out (see --keep-antenna): " + inst)
            else:
                die(f"unexpected element in {name} (want transistors only): {ln}")
        out.append(".ends\n")

    flat = {}

    def count(cell, mult):
        for m, n in local[cell].items():
            flat[m] = flat.get(m, 0) + n * mult
        for ln in cells[cell][1]:
            if ln[0].upper() == "X":
                count([x for x in ln.split()[1:] if "=" not in x][-1], mult)
    count(top, 1)
    return "\n".join(out), flat


# --- testbench ---------------------------------------------------------------

XREF_RB = """
lvs = RBA::LayoutVsSchematic.new
lvs.read($lvsdb)
xref = lvs.xref
xref.each_circuit_pair do |cp|
  next unless cp.first && cp.first.name == $top
  xref.each_net_pair(cp) do |np|
    next unless np.first && np.second
    puts "XREF\\t#{np.first.expanded_name}\\t#{np.second.expanded_name}\\t#{np.status}"
  end
end
"""


def read_xref(lvsdb, top, workdir):
    """{layout net: schematic net} of circuit `top`, from the LVS run's
    cross-reference (KLayout's own reader, run in batch mode). The CDL reader
    upper-cases names; the schematic deck's are lower case."""
    import subprocess
    rb = os.path.join(workdir, "xref.rb")
    with open(rb, "w") as f:
        f.write(XREF_RB)
    r = subprocess.run(["klayout", "-b", "-r", rb, "-rd", f"lvsdb={lvsdb}", "-rd", f"top={top}"],
                       capture_output=True, text=True)
    pairs, bad = {}, []
    for ln in r.stdout.splitlines():
        if ln.startswith("XREF\t"):
            _, l_, s_, st = ln.split("\t")
            pairs[l_] = s_.lower()
            if st != "Match":
                bad.append(ln)
    if r.returncode or not pairs:
        die(f"reading {lvsdb} failed:\n{r.stdout}{r.stderr}")
    if bad:
        die("LVS cross-reference has non-matching nets:\n" + "\n".join(bad))
    return pairs


def testbench_part(deck):
    """The netlisted schematic deck split up: (all lines, index of the first
    expanded subckt, the testbench part without the library/model .INCLUDEs)."""
    lines = open(deck).read().splitlines()

    # the testbench part: everything before the first expanded subckt
    try:
        cut = next(i for i, ln in enumerate(lines) if ln.startswith("* expanding   symbol:"))
    except StopIteration:
        die(f"{deck}: no '* expanding symbol' marker -- not an xschem deck?")
    tb = lines[:cut]
    if not any(re.match(r"\.subckt\s+mdll\s", ln) for ln in lines[cut:]):
        die(f"{deck}: no .subckt mdll")
    if any(re.match(r"\s*\.subckt\s", ln, re.I) for ln in tb):
        die(f"{deck}: a subckt definition before the first expanded symbol")

    # The library and model .INCLUDEs go: in the layout these are transistors,
    # and the extracted netlist defines every standard cell it uses itself.
    drop_inc = re.compile(r"^\.INCLUDE\s+\S*?(sg13g2_stdcell|custom_stdcell|dco_decode|dlf|"
                          r"counter|lock_ctrl)\.spice\s*$", re.I)
    dropped = [ln for ln in tb if drop_inc.match(ln)]
    if len(dropped) != 6:
        die(f"expected the 6 library/model .INCLUDEs, found {dropped}")
    tb = [ln for ln in tb if not drop_inc.match(ln)]
    left = [ln for ln in tb if re.match(r"\.INCLUDE", ln, re.I)]
    if left:
        die(f"unexpected .INCLUDEs left in the testbench part: {left}")
    return lines, cut, tb


POWER = {"VPWR": "VDD", "VGND": "VSS"}


def place_instance(tb, lines, cut, ports, top):
    """Re-instantiates x1 in `tb` with the extracted port order, mapped by name
    from the schematic instance; returns the signal ports."""
    inst = [i for i, ln in enumerate(tb) if re.match(r"x1\s.*\smdll\s*$", ln)]
    if len(inst) != 1:
        die(f"want one 'x1 ... mdll' instance in the testbench, found {len(inst)}")
    inst = inst[0]
    # xschem names each instance net after the testbench net; check the
    # schematic subckt's port list maps 1:1 to it by position, i.e. that
    # testbench net == schematic port name for every port.
    sch_ports = next(ln.split()[2:] for ln in lines[cut:] if re.match(r"\.subckt\s+mdll\s", ln))
    tbnets = tb[inst].split()[1:-1]
    if sch_ports != tbnets:
        die(f"testbench nets {tbnets} are not the schematic's port names {sch_ports}: "
            f"mapping by name would need the positional map")
    sig = [p for p in ports if p not in POWER]
    if set(ports) - set(sig) != set(POWER):
        die(f"power pins: expected {sorted(POWER)}, extracted has {sorted(set(ports) - set(sig))}")
    if sorted(sig) != sorted(sch_ports) or len(set(sig)) != len(sig):
        die(f"port mismatch: extracted-only {sorted(set(sig) - set(sch_ports))}, "
            f"schematic-only {sorted(set(sch_ports) - set(sig))}")
    tb[inst] = "x1 " + " ".join(POWER.get(p, p) for p in ports) + f" {ngname(top)}"
    return sig


def check_saves(tb, sig, top_nets, top):
    """Every x1.<net> the save lines name must exist in the extracted top."""
    for ln in tb:
        if re.match(r"\s*save\s", ln):
            for w in ln.split()[1:]:
                if w.startswith("x1.") and w[3:] not in top_nets:
                    die(f"save list names {w}: not a net of the extracted {top}")
                if not w.startswith("x1.") and w not in sig:
                    die(f"save list names {w}: not a port of {top}")


def saved_nets(tb):
    return [w[3:] for ln in tb if re.match(r"\s*save\s", ln)
            for w in ln.split()[1:] if w.startswith("x1.")]


def set_corner(tb, corner):
    """Switch the netlisted tt / 1.2 V / 27 C testbench to another SPICE corner,
    as gen_mixed.py does: MOS models, .PARAM VDD (supply and stimulus) and
    .TEMP. Unlike there, no dco_decode level to follow: in the layout the
    decoder is transistors. The extracted R and C stay as Calibre wrote them
    (25 C nominal); the netlist carries no temperature coefficients."""
    lib, vdd, temp = CORNERS[corner]
    tb = list(tb)
    for pat, new in [(r"\.LIB cornerMOSlv\.lib mos_tt$", f".LIB cornerMOSlv.lib {lib}"),
                     (r"\.PARAM VDD=1\.2$", f".PARAM VDD={vdd:g}"),
                     (r"\.TEMP 27$", f".TEMP {temp:g}")]:
        hits = [i for i, ln in enumerate(tb) if re.match(pat, ln)]
        if len(hits) != 1:
            die(f"--corner: expected one line matching {pat}, found {len(hits)}")
        tb[hits[0]] = new
    return tb


def write_deck(a, tb, lines, cut, header, cir):
    out = list(header) + [f"* SPICE corner: {a.corner} ({', '.join(f'{x:g}' if not isinstance(x, str) else x for x in CORNERS[a.corner])})"]
    tb = set_corner(tb, a.corner)
    seen_lib = seen_raw = seen_tran = seen_tref = False
    for ln in tb:
        m = re.match(r"\.LIB\s+cornerMOSlv\.lib\s+mos_(\w+)\s*$", ln, re.I)
        if m:
            out.append(ln)
            if a.keep_antenna:
                # the antenna diodes of the layout's sg13g2_antennanp cells
                out.append(f".LIB cornerDIO.lib dio_{m.group(1)}")
            seen_lib = True
            continue
        if ln.startswith(".OPTIONS KLU"):
            out.append(ln)
            if a.rshunt:
                out.append(".OPTIONS RSHUNT=1e12")
            out.append(f".INCLUDE {os.path.abspath(cir)}")
            continue
        if getattr(a, "tref", None) and re.match(r"\.PARAM T_REF=", ln, re.I):
            out.append(f".PARAM T_REF={a.tref}")
            seen_tref = True
            continue
        m = re.match(r"(\s*setcs rawfile\s*=\s*)\S+", ln)
        if m:
            ln = m.group(1) + os.path.abspath(a.raw)
            seen_raw = True
        if re.match(r"\s*tran\s", ln):
            if a.tstop:
                ln = re.sub(r"^(\s*)tran\s+(\S+)\s+\S+", rf"\1tran \2 {a.tstop}", ln)
            out.append(f"  set num_threads={a.threads}")
            seen_tran = True
        out.append(ln)
    if getattr(a, "tref", None) and not seen_tref:
        die("--tref: no .PARAM T_REF= line in the deck")
    if not (seen_lib and seen_raw and seen_tran):
        die(f"anchor lines missing: .LIB mos {seen_lib}, setcs rawfile {seen_raw}, tran {seen_tran}")
    if not any(ln.startswith(".OPTIONS KLU") for ln in out):
        die("no .OPTIONS KLU")
    # xschem puts .GLOBAL VDD/VSS after the last subckt (see CLAUDE.md)
    glob = [ln for ln in lines[cut:] if re.match(r"\.GLOBAL\s", ln, re.I)]
    if sorted(g.split()[1] for g in glob) != ["VDD", "VSS"]:
        die(f"expected .GLOBAL VDD and VSS in {a.deck}, found {glob}")
    out += [""] + glob + [".end"]
    with open(a.out, "w") as f:
        f.write("\n".join(out) + "\n")


def cmd_tb(a):
    lines, cut, tb = testbench_part(a.deck)

    # the extracted cell, its internal nets named from the LVS xref
    cells = parse_extracted(a.extracted)
    if a.top not in cells:
        die(f"{a.extracted}: no subckt {a.top}")
    ports = [unesc(p) for p in cells[a.top][0]]
    xref = read_xref(a.lvsdb, a.top, os.path.dirname(os.path.abspath(a.cir)))
    rename = {}
    for l_, s_ in xref.items():
        if l_ in ports:
            if l_.lower() != s_:
                die(f"top-level pin {l_} matched schematic net {s_}")
            continue
        rename[l_] = s_
    taken = set(ports)
    for s_ in rename.values():
        if s_ in taken:
            die(f"schematic net name {s_} used twice")
        taken.add(s_)
    text, flat = convert(cells, a.top, rename, a.keep_antenna)

    sig = place_instance(tb, lines, cut, ports, a.top)
    top_nets = set(sig) | set(POWER) | set(rename.values())
    for ln in cells[a.top][1]:
        top_nets.update(ngname(x) for x in ln.split()[1:] if "=" not in x)
    check_saves(tb, sig, top_nets, a.top)

    with open(a.cir, "w") as f:
        f.write(f"* {a.top} as extracted from the layout by the KLayout SG13G2 LVS runset\n"
                f"* ({a.extracted}), converted for ngspice by\n"
                f"* simulations/gen_layout_tb.py: M/D devices as X instances of the PDK\n"
                f"* subckts, '$' -> '_', {a.top}'s internal nets named from the LVS\n"
                f"* cross-reference. Transistors only, no parasitics.\n"
                f"* flat device count: {dict(sorted(flat.items()))}\n\n" + text + "\n")
    write_deck(a, tb, lines, cut, [
        f"* Layout closed loop: {os.path.relpath(a.deck, ROOT)} with the schematic mdll",
        f"* replaced by the netlist extracted from the layout ({os.path.basename(a.cir)}).",
        "* Generated by simulations/gen_layout_tb.py -- do not edit.",
        f"* x1's ports by name: {' '.join(ports)}; VPWR = VDD, VGND = VSS."], a.cir)
    print(f"{a.out}: x1 = extracted {a.top}, {sum(flat.values())} devices "
          f"{dict(sorted(flat.items()))}; {len(rename)} internal nets named from the xref")


# --- Calibre xRC netlist -> ngspice ------------------------------------------

def pexname(tok):
    """A Calibre net/instance token as ngspice reads it: the bus brackets lose
    their backslash escapes, and '@' (Calibre's split-device suffix; ngspice
    reads it as a device-parameter reference) becomes '_'."""
    return tok.replace("\\", "").replace("@", "_")


def read_pex(path):
    """Calibre's main PEX netlist with its .include files inlined, as logical
    lines (continuations joined, comments and blank lines dropped)."""
    out = []
    for ln in logical_lines(open(path).read()):
        w = ln.split()
        if not w or ln.startswith("*"):
            continue
        if w[0].lower() == ".include":
            inc = os.path.join(os.path.dirname(os.path.abspath(path)), w[1].strip('"'))
            out += read_pex(inc)
        else:
            out.append(ln)
    return out


def cmd_pex(a):
    lines, cut, tb = testbench_part(a.deck)
    pex = read_pex(a.pex)

    # The top cell: devices, then the .pxi's per-net parasitic instances
    # (x_PM_<top>_<net>) and coupling capacitors. Each PM_<top>_<net> subckt is
    # the R/C network of one net; its ports are that net's device-pin nodes.
    tops = [i for i, ln in enumerate(pex) if re.match(rf"\.subckt\s+{re.escape(a.top)}\s", ln, re.I)]
    if len(tops) != 1:
        die(f"{a.pex}: want one .subckt {a.top}, found {len(tops)}")
    ports = [pexname(p) for p in pex[tops[0]].split()[2:]]
    sig = place_instance(tb, lines, cut, ports, a.top)

    # --ideal-supply: the power nets' own RC networks (PM_<top>_VPWR/VGND, most
    # of the netlist) go, and every node of theirs becomes the ideal port.
    supply = {}
    if a.ideal_supply:
        for ln in pex:
            w = [pexname(x) for x in ln.split()]
            for p_ in POWER:
                if w[0] == f"x_PM_{a.top}_{p_}":
                    supply.update({n: p_ for n in w[1:-1]})
        if not supply:
            die("--ideal-supply: no power-net parasitic instances found")
    skip = {f"PM_{a.top}_{p_}" for p_ in POWER} if a.ideal_supply else set()

    out, flat, nr, nc, ncc, pm_ports = [], {}, 0, 0, 0, {}
    cur, dropping = None, False
    for ln in pex:
        w = [pexname(x) for x in ln.split()]
        k = w[0].lower()
        if k == ".subckt" and w[1] in skip:
            dropping = True
            continue
        if dropping:
            dropping = k != ".ends"
            continue
        if supply and cur == a.top:
            if k[0] == "x" and w[-1] in skip:
                continue
            w = [w[0]] + [supply.get(x, x) for x in w[1:]]
            if k[0] == "c" and w[1] == w[2]:
                continue
        if k == ".subckt":
            cur = w[1]
            out.append(" ".join(w))
            continue
        if k == ".ends":
            cur = None
            out.append(".ends")
            continue
        if cur is None:
            die(f"{a.pex}: statement outside a subckt: {ln[:80]}")
        c = k[0]
        if c == "m":
            # m<name> D G S B <model> w= l= as= ad= ps= pd= m= ng=
            d, g, s, b, model = w[1:6]
            if model not in ("sg13_lv_nmos", "sg13_lv_pmos"):
                die(f"unexpected MOS model {model}")
            p = params(w[6:])
            ps = " ".join(f"{q}={p[q]:.6g}" for q in ("w", "l", "as", "ad", "ps", "pd") if q in p)
            out.append(f"XM{w[0][1:].replace('.', '_')} {d} {g} {s} {b} {model} {ps} "
                       f"ng={p.get('ng', 1):g} m={p.get('m', 1):g}")
            flat[model] = flat.get(model, 0) + 1
        elif c == "d":
            an, ca, model = w[1:4]
            if model not in ("dantenna", "dpantenna"):
                die(f"unexpected diode model {model}")
            p = params(w[4:])
            hp = p["pj"] / 2
            disc = max(hp * hp - 4 * p["area"], 0.0) ** 0.5
            l_, w_ = (hp + disc) / 2, (hp - disc) / 2
            inst = f"XD{w[0][1:].replace('.', '_')} {an} {ca} {model} l={l_:.6g} w={w_:.6g}"
            if a.keep_antenna:
                out.append(inst)
                flat[model] = flat.get(model, 0) + 1
            else:
                out.append("* antenna diode left out (see --keep-antenna): " + inst)
        elif c == "r":
            nr += 1
            out.append(" ".join(w))
        elif c == "c":
            if cur == a.top:
                ncc += 1
            else:
                nc += 1
            out.append(" ".join(w))
        elif c == "x":
            if cur != a.top or not w[-1].startswith(f"PM_{a.top}_"):
                die(f"unexpected instance: {ln[:80]}")
            pm_ports[w[-1][len(f"PM_{a.top}_"):]] = w[1:-1]
            out.append(" ".join(w))
        else:
            die(f"unexpected element: {ln[:80]}")

    # Probes. The testbench saves x1.<net>; in the RC netlist a net is many
    # nodes. Each saved net gets a 0 V source from a node named after it to
    # the first gate (receiver) node of its network -- a logic node behind
    # the wire, as the gates that read it see it.
    probes = []
    for i, net in enumerate(dict.fromkeys(saved_nets(tb))):
        nodes = pm_ports.get(net)
        if nodes is None:
            die(f"save list names x1.{net}: no such net in {a.pex}")
        gates = [n for n in nodes if n.endswith("_g")]
        node = (gates or nodes)[0]
        probes.append(f"Vprobe{i} {net} {node} 0")
    start = next(i for i, x in enumerate(out) if x.startswith(f".subckt {a.top} "))
    ends = out.index(".ends", start)
    out[ends:ends] = ["* probes for the testbench's save list"] + probes
    check_saves(tb, sig, set(sig) | set(saved_nets(tb)), a.top)

    with open(a.cir, "w") as f:
        f.write(f"* {a.top} with parasitics, from Calibre xRC ({os.path.abspath(a.pex)}),\n"
                f"* converted for ngspice by simulations/gen_layout_tb.py pex: includes\n"
                f"* inlined, MOS as X instances of the PDK subckts, '\\' and '@' left out of\n"
                f"* names, a 0 V probe per saved net.{' Ideal supply: VPWR/VGND RC left out.' if supply else ''}\n"
                f"* Flat devices: {dict(sorted(flat.items()))};\n"
                f"* {nr} R, {nc} C to ground, {ncc} coupling C.\n\n" + "\n".join(out) + "\n")
    write_deck(a, tb, lines, cut, [
        f"* RC closed loop: {os.path.relpath(a.deck, ROOT)} with the schematic mdll",
        f"* replaced by the Calibre xRC netlist ({os.path.basename(a.cir)}).",
        "* Generated by simulations/gen_layout_tb.py pex -- do not edit.",
        f"* x1's ports by name: {' '.join(ports)}; VPWR = VDD, VGND = VSS."], a.cir)
    print(f"{a.out}: x1 = Calibre RC {a.top}, {sum(flat.values())} devices "
          f"{dict(sorted(flat.items()))}, {nr} R, {nc} C, {ncc} CC; {len(probes)} probes")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    c = sp.add_parser("cdl")
    c.add_argument("--top", required=True, help="top-level CDL (LibreLane final/cdl)")
    c.add_argument("--macros", default=os.path.join(ROOT, "build", "macros"))
    c.add_argument("--custom", default=os.path.join(os.path.dirname(ROOT), "custom_stdcell", "custom_stdcell.cdl"))
    c.add_argument("--stdcell", default=os.path.join(
        os.environ.get("PDK_ROOT", "/opt/IHP-Open-PDK"),
        "ihp-sg13g2/libs.ref/sg13g2_stdcell/cdl/sg13g2_stdcell.cdl"))
    c.add_argument("--out", required=True)
    c.add_argument("--no-fill", action="store_true",
                   help="leave out the instances of device-less cells (fill_*), for Calibre LVS")
    t = sp.add_parser("tb", help="testbench on KLayout's extracted netlist (no parasitics)")
    t.add_argument("--extracted", required=True, help="KLayout *_extracted.cir")
    t.add_argument("--lvsdb", required=True, help="the LVS run's .lvsdb, for internal net names")
    x_ = sp.add_parser("pex", help="testbench on a Calibre xRC (R+C+CC) netlist")
    x_.add_argument("--pex", required=True, help="Calibre xRC netlist (<top>.pex.spice, "
                    "SOURCENAMES, with its .pex/.pxi includes next to it)")
    for q in (t, x_):
        q.add_argument("--deck", default=os.path.join(ROOT, "build", "test_mdll.spice"))
        q.add_argument("--top", default="mdll")
        q.add_argument("--cir", required=True, help="converted netlist to write")
        q.add_argument("--out", required=True, help="testbench to write")
        q.add_argument("--raw", required=True)
        q.add_argument("--tstop", help="override the tran stop time (smoke runs)")
        q.add_argument("--tref", help="override the reference period .PARAM T_REF (frequency sweeps; "
                       "check_mdll.py counts in reference cycles, so scale --tstop with it)")
        q.add_argument("--threads", type=int, default=4, help="ngspice num_threads")
        q.add_argument("--corner", choices=list(CORNERS), default="typ",
                       help="SPICE corner: MOS models, VDD and .TEMP (gen_mixed.py's table)")
        q.add_argument("--keep-antenna", action="store_true",
                       help="keep the sg13g2_antennanp cells' diodes. Off by default: with "
                            "the PDK's dantenna model (diodes.lib, ngspice-45) the transient "
                            "stalls at the first edge that undershoots VSS by ~0.1 V (a "
                            "buf_1 driving one antennanp alone: timestep -> 1e-23 s). "
                            "Each is a ~1 fF reverse-biased junction on a tool-inserted "
                            "antenna cell; the schematic decks have none either.")
        q.add_argument("--rshunt", action="store_true", help="add .OPTIONS RSHUNT=1e12")
    x_.add_argument("--ideal-supply", action="store_true",
                    help="leave out the RC networks of VPWR/VGND (~70%% of the resistors) "
                         "and tie their nodes to the ideal supply ports")
    a = ap.parse_args()
    {"cdl": cmd_cdl, "tb": cmd_tb, "pex": cmd_pex}[a.cmd](a)


if __name__ == "__main__":
    main()
