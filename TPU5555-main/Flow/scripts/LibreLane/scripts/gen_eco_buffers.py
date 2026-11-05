#!/usr/bin/env python3
"""Generates the INSERT_ECO_BUFFERS section of config.yaml.

Usage: gen_eco_buffers.py <synthesized netlist .nl.v> [--update config.yaml | --check config.yaml]

The hold fix for the SPI front end (see INSERT_ECO_BUFFERS in config.yaml):
one sg13cmos5l_dlygate4sd3_1 on the D pin of each register bit below. The
bits are named by the net their flop drives, which comes from the VHDL
signal names; the flop's instance name (_23641_ ...) is Yosys's numbering
and changes with any change to the synthesized design (adding the MDLL's
divider renumbered all 2744 flops). So the list is generated from the
netlist of the run's own synthesis: every bit must be found, driven by
exactly one flop, or the script fails.

The set is every bit of the SPI front end's shift/receive registers
(REGISTERS; 32 bits, all that Yosys keeps of them). Until full-test-v7 it was
the 31 D pins that violated hold on full-test-v5; with the MDLL the placement
changed and preload_cont_byte1[5], the one left out, violated (mdll-v1,
-0.05 ns fast). A delay cell on a 100 ns sclk path costs no setup.

--update rewrites the section in config.yaml in place; --check exits 1 if
the section in config.yaml differs from what the netlist gives.
"""
import re
import sys

BUFFER = 'sg13cmos5l_dlygate4sd3_1'
REGISTERS = ['i_core.u_spi.u_spi.in_shift', 'i_core.u_spi.rx_byte0', 'i_core.u_spi.rx_byte1',
             'i_core.u_spi.u_spi.preload_cont_byte0', 'i_core.u_spi.u_spi.preload_cont_byte1']
KEY = 'INSERT_ECO_BUFFERS'


def flops_by_q(path):
    """Q net (without the Verilog escape) -> list of flop instance names."""
    text = open(path).read()
    drivers = {}
    for master, inst, body in re.findall(r'^\s*(sg13cmos5l_\w*df\w*)\s+(\S+)\s*\((.*?)\);',
                                         text, re.S | re.M):
        m = re.search(r'\.Q\(\s*(\S+?)\s*\)', body)
        if m:
            drivers.setdefault(m.group(1).lstrip('\\'), []).append(inst.lstrip('\\'))
    return drivers


def section(netlist):
    drivers = flops_by_q(netlist)
    out = [f'{KEY}:']
    for reg in REGISTERS:
        bits = sorted((int(m.group(1)), q) for q in drivers
                      if (m := re.fullmatch(re.escape(reg) + r'\[(\d+)\]', q)))
        if not bits:
            sys.exit(f'{reg}: no flops in {netlist}')
        for _, q in bits:
            if len(drivers[q]) != 1:
                sys.exit(f'{q}: driven by {drivers[q]} in {netlist}')
            out.append(f'  - target: "{drivers[q][0]}/D"')
            out.append(f'    buffer: {BUFFER}')
    return out


def replace_section(text, key, lines):
    """Replace the top-level block `key:`: its line and every following line
    that is indented or blank, up to the next unindented line (or the end);
    blank lines at its end stay."""
    src = text.split('\n')
    try:
        start = next(i for i, ln in enumerate(src) if ln.startswith(f'{key}:'))
    except StopIteration:
        sys.exit(f'no top-level {key}: in config')
    end = start + 1
    while end < len(src) and (src[end][:1] in (' ', '\t') or src[end] == ''):
        end += 1
    while end > start + 1 and src[end - 1] == '':
        end -= 1
    return '\n'.join(src[:start] + lines + src[end:])


def main():
    args = sys.argv[1:]
    if len(args) not in (1, 3) or (len(args) == 3 and args[1] not in ('--update', '--check')):
        sys.exit(__doc__)
    lines = section(args[0])
    if len(args) == 1:
        print('\n'.join(lines))
        return
    cfg = args[2]
    old = open(cfg).read()
    new = replace_section(old, KEY, lines)
    if args[1] == '--check':
        if new != old:
            sys.exit(f'{cfg}: {KEY} is not what {args[0]} gives; run with --update')
        print(f'{cfg}: {KEY} up to date ({(len(lines) - 1) // 2} buffers)')
    elif new != old:
        open(cfg, 'w').write(new)
        print(f'{cfg}: {KEY} updated ({(len(lines) - 1) // 2} buffers)')
    else:
        print(f'{cfg}: {KEY} unchanged')


if __name__ == '__main__':
    main()
