#!/usr/bin/env python3
"""Make the IHP standard-cell Verilog models usable for zero-delay simulation in Verilator.

1. The sequential cells (flops, latches, scan flops) of sg13cmos5l_stdcell.v feed their
   functional UDPs with `delayed_CLK`, `delayed_D`, `delayed_RESET_B`, ... These wires
   are only driven by the `$setuphold` / `$recrem` checks in the `specify` blocks.
   Simulators that ignore `specify` (Verilator) leave them undriven, so no flop or latch
   ever switches. With the zero-valued limits of the PDK models an event-driven
   simulator drives each `delayed_X` with `X`, so `assign delayed_X = X;` is inserted.

2. The flop UDPs update their output immediately. In a zero-delay simulation a flop can
   then change before another flop clocked by the same edge has sampled it (a race that
   the real clock-to-Q delay prevents on silicon). The flop types used by TPU5555
   (sg13cmos5l_dfrbpq_*: rising edge, active-low asynchronous reset) are therefore
   replaced by an equivalent behavioral model with nonblocking assignments, which is the
   UDP's function: RESET_B = 0 forces Q = 0, a rising CLK edge loads D. A reset level
   that is already active at time 0 (e.g. the SPI front end's cs_n reset while the chip
   is deselected) is applied once at start-up, since it produces no edge.

usage: functional_stdcells.py <sg13cmos5l_stdcell.v> <output.v>
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
tied = replaced = 0

DFRBPQ = """module {name} (Q, CLK, D, RESET_B);
	// functional_stdcells.py: behavioral replacement of the ihp_dff_r UDP (nonblocking)
	output reg Q;
	input CLK, D, RESET_B;
	always @(posedge CLK or negedge RESET_B)
		if (!RESET_B) Q <= 1'b0;
		else          Q <= D;
	// A reset that is already active at time 0 has no negedge in a 2-state simulator;
	// apply it once after start-up (later assertions are real edges).
	initial #0.01 if (!RESET_B) Q <= 1'b0;
endmodule"""


def patch(module):
    global tied, replaced
    name = re.match(r"module\s+(\w+)", module).group(1)
    if re.fullmatch(r"sg13cmos5l_dfrbpq_\d+", name):
        replaced += 1
        return DFRBPQ.format(name=name)
    if "delayed_" not in module:
        return module
    out = []
    for line in module.splitlines(keepends=True):
        out.append(line)
        m = re.match(r"\s*wire\s+(delayed_\w+(?:\s*,\s*delayed_\w+)*)\s*;", line)
        if m:
            for sig in re.split(r"\s*,\s*", m.group(1)):
                out.append(f"\tassign {sig} = {sig[len('delayed_'):]};  // functional_stdcells.py\n")
                tied += 1
    return "".join(out)


body = re.sub(r"^module\s.*?endmodule", lambda m: patch(m.group(0)), text, flags=re.S | re.M)
open(dst, "w").write(body)
print(f"{dst}: {replaced} flop models replaced (nonblocking), {tied} delayed_* wires tied in the others")
