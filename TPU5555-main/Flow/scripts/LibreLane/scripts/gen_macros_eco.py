#!/usr/bin/env python3
"""Generates the MACROS and INSERT_ECO_DIODES sections of config.yaml.

Usage: gen_macros_eco.py <synthesized netlist .nl.v> [--update config.yaml | --check config.yaml]
(e.g. runs/<tag>/01-yosys-vhdlsynthesis/hdc_chip_top.nl.v; a run with
--to Yosys.VHDLSynthesis is enough). Without an option it prints both
sections; --update rewrites them in config.yaml, --check exits 1 if they
differ (as gen_eco_buffers.py).

Placement is defined in PLACEMENT below: two rows with their pins facing the
logic channel between them (bottom row S, top row N; all pin shapes of these
macros sit on the macro's bottom edge).

ECO diodes: one sg13cmos5l_antennanp per functional SRAM input, i.e. every
A_CLK/A_MEN/A_WEN/A_REN/A_ADDR/A_DIN bit that the netlist drives from logic
(bits tied to tie cells are skipped). Each sits at the pin's x, 12 um outside
the pin edge: pin top + 12 for S, pin bottom - 12 for N.

The MDLL (MDLL below) is a fixed extra MACROS entry; it has no functional
inputs that need diodes here (its own LEF carries its antenna data).
"""
import os
import re
import sys

from gen_eco_buffers import replace_section

PDK = os.environ.get('PDK_ROOT', '/opt/IHP-Open-PDK').rstrip('/') + '/ihp-sg13cmos5l/libs.ref/sg13cmos5l_sram'
CORNERS = {  # LibreLane corner -> SRAM lib corner
    '*_typ_1p20V_25C': 'typ_1p20V_25C',
    '*_fast_1p32V_m40C': 'fast_1p32V_m55C',
    '*_slow_1p08V_125C': 'slow_1p08V_125C',
}
DIODE_OFFSET = 12.0

# instance (without "i_core.accel_unit." prefix) -> (x, y, orientation)
# Bottom row (S): IM and CM, 20 um gaps, pins up at y = 405 + 336.46.
# Top row (N): class counters and AM, pins down at y = 1021.5 (~280 um channel).
# AM sits 10 um higher: at 1021.5 its top edge (1140.28) straddled a
# horizontal TopMetal1 stripe and pdngen dropped 12 VSS vias (PDN-0110).
# The MDLL hard macro, ip/mdll/ (mixed_signal_design_blocks `make ip_cmos5l`,
# see ip/mdll/SOURCE.txt), 257.76 x 294.84 um, in the core's top-right
# corner, clear of both SRAM rows: (instance, x, y, orientation). Its pins:
# clk_ref/resetb/clk_out on the west edge (to the MDLL pads at the right end
# of PAD_NORTH, around its top-left corner), code[7:0]/locked on the east
# edge (to the pads at the top of PAD_EAST, 42 um of core to the east).
# Both horizontal edges sit between TopMetal1 stripes (VDD at 27.66 + 50k,
# VSS at 35.66 + 50k, 6 um wide): bottom 1260 (= 10 mod 50), top 1554.84
# (= 4.84), so none straddles one (see AM above).
MDLL = ('i_mdll', 1735.0, 1260.0, 'N')
MDLL_LIBS = {c: f'nom_{c[2:]}' for c in ('*_typ_1p20V_25C', '*_fast_1p32V_m40C', '*_slow_1p08V_125C')}

PLACEMENT = {
    'im.u_mem.g_1024.u_lo.g_banks:1.g_cols:1.u_macro.g_1024x32.u_mem': (405.0, 405.0, 'S'),
    'im.u_mem.g_1024.u_hi.g_banks:1.g_cols:1.u_macro.g_1024x8.u_mem': (841.64, 405.0, 'S'),
    'cim.u_mem.g_1024.u_lo.g_banks:1.g_cols:1.u_macro.g_1024x32.u_mem': (1008.52, 405.0, 'S'),
    'cim.u_mem.g_1024.u_hi.g_banks:1.g_cols:1.u_macro.g_1024x8.u_mem': (1445.16, 405.0, 'S'),
    'gen_training_ram.cc.g_1024.u_mem.g_banks:1.g_cols:1.u_macro.g_1024x16.u_mem': (405.0, 1021.5, 'N'),
    'am.u_mem.g_256.u_mem.g_banks:1.g_cols:1.u_macro.g_256x48.u_mem': (661.8, 1031.5, 'N'),
}
PREFIX = 'i_core.accel_unit.'
FUNC_PINS = ('A_CLK', 'A_MEN', 'A_WEN', 'A_REN', 'A_ADDR', 'A_DIN')


def read_lef(master):
    text = open(f'{PDK}/lef/{master}.lef').read()
    w, h = map(float, re.search(r'SIZE ([\d.]+) BY ([\d.]+)', text).groups())
    pins = {}
    for name, body in re.findall(r'^  PIN (\S+)\n(.*?)^  END \1', text, re.S | re.M):
        rects = [tuple(map(float, r)) for r in
                 re.findall(r'RECT ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)', body)]
        pins[name] = (min(r[0] for r in rects), min(r[1] for r in rects),
                      max(r[2] for r in rects), max(r[3] for r in rects))
    return w, h, pins


def read_netlist(path):
    """instance -> (master, set of functional pin bits like 'A_DIN[3]')"""
    text = open(path).read()
    ties = {n.strip() for n in
            re.findall(r'sg13cmos5l_tie\w+ \S+ \(\s*\.\w+\(([^)]+)\)', text)}
    result = {}
    for master, inst, body in re.findall(r'(RM_IHPSG13_\S+) \\(\S+)\s+\((.*?)\);', text, re.S):
        used = set()
        for port, expr in re.findall(r'\.(\w+)\((\{.*?\}|[^()]*?)\)', body, re.S):
            if port not in FUNC_PINS:
                continue
            bits = [b.strip() for b in expr.strip().strip('{}').split(',')]
            for i, b in enumerate(reversed(bits)):  # Verilog concat is MSB first
                if b in ties or re.match(r"\d+'", b):
                    continue
                used.add(port if len(bits) == 1 else f'{port}[{i}]')
        result[inst] = (master, used)
    return result


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    netlist = read_netlist(sys.argv[1])
    expected = {PREFIX + k for k in PLACEMENT}
    if set(netlist) != expected:
        sys.exit(f'netlist macros differ from PLACEMENT:\n  netlist only: '
                 f'{sorted(set(netlist) - expected)}\n  PLACEMENT only: {sorted(expected - set(netlist))}')

    by_master = {}
    for inst, (master, _) in sorted(netlist.items()):
        by_master.setdefault(master, []).append(inst)

    out = ['MACROS:']
    for master, insts in by_master.items():
        out.append(f'  {master}:')
        out.append(f'    gds: [pdk_dir::libs.ref/sg13cmos5l_sram/gds/{master}.gds]')
        out.append(f'    lef: [pdk_dir::libs.ref/sg13cmos5l_sram/lef/{master}.lef]')
        out.append('    lib:')
        for corner, lib in CORNERS.items():
            out.append(f'      "{corner}": [pdk_dir::libs.ref/sg13cmos5l_sram/lib/{master}_{lib}.lib]')
        out.append('    instances:')
        for inst in insts:
            x, y, orient = PLACEMENT[inst[len(PREFIX):]]
            out.append(f'      {inst}:')
            out.append(f'        location: [{x}, {y}]')
            out.append(f'        orientation: {orient}')

    if not re.search(rf'^\s*mdll\s+\\?{MDLL[0]}\s*\(', open(sys.argv[1]).read(), re.M):
        sys.exit(f'no mdll instance {MDLL[0]} in {sys.argv[1]}')
    out.append('  mdll:')
    out.append('    gds: [dir::ip/mdll/gds/mdll.gds]')
    out.append('    lef: [dir::ip/mdll/lef/mdll.lef]')
    out.append('    lib:')
    for corner, d in MDLL_LIBS.items():
        out.append(f'      "{corner}": [dir::ip/mdll/lib/{d}/mdll__{d}.lib]')
    out.append('    instances:')
    out.append(f'      {MDLL[0]}:')
    out.append(f'        location: [{MDLL[1]}, {MDLL[2]}]')
    out.append(f'        orientation: {MDLL[3]}')

    eco = []
    for inst, (master, used) in sorted(netlist.items()):
        w, h, pins = read_lef(master)
        x0, y0, orient = PLACEMENT[inst[len(PREFIX):]]

        def key(p):
            m = re.match(r'(\w+?)(?:\[(\d+)\])?$', p)
            return FUNC_PINS.index(m.group(1)), int(m.group(2) or 0)

        for pin in sorted(used, key=key):
            px0, py0, px1, py1 = pins[pin]
            xc = (px0 + px1) / 2
            if orient == 'S':  # R180: (x, y) -> (x0 + w - x, y0 + h - y)
                x, y = x0 + w - xc, y0 + h - py0 + DIODE_OFFSET
            elif orient == 'N':
                x, y = x0 + xc, y0 + py0 - DIODE_OFFSET
            else:
                sys.exit(f'unsupported orientation {orient}')
            eco.append(f'  - target: "{inst}/{pin}"\n    placement: [{round(x, 3)}, {round(y, 3)}]')

    diodes = ['INSERT_ECO_DIODES:'] + eco
    if len(sys.argv) == 2:
        print('\n'.join(out))
        print()
        print('\n'.join(diodes))
        print(f'# {len(eco)} ECO diodes', file=sys.stderr)
        return
    if len(sys.argv) != 4 or sys.argv[2] not in ('--update', '--check'):
        sys.exit(__doc__)
    cfg = sys.argv[3]
    old = open(cfg).read()
    new = replace_section(replace_section(old, 'MACROS', out), 'INSERT_ECO_DIODES', diodes)
    if sys.argv[2] == '--check':
        if new != old:
            sys.exit(f'{cfg}: MACROS/INSERT_ECO_DIODES are not what {sys.argv[1]} gives; run with --update')
        print(f'{cfg}: MACROS/INSERT_ECO_DIODES up to date ({len(eco)} diodes)')
    else:
        open(cfg, 'w').write(new)
        print(f'{cfg}: MACROS/INSERT_ECO_DIODES {"updated" if new != old else "unchanged"} ({len(eco)} diodes)')


if __name__ == '__main__':
    main()
