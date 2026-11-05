# MDLL top level -- timing constraints.
#
# The blocks are macros timed by their abstract .lib models (STA_MACRO_
# PRIORITIZE_NL: false), which hold only the arcs each block's own STA could
# derive. What remains to time at this level is the clk_ref domain between the
# macros (lock_ctrl <-> bbpd, lock_ctrl <-> tdc captures) and the glue.
#
# Clocks:
#   clk_ref  the reference input. x5 (always-on sg13g2_lgcp_1) passes it on as
#            clk_ref_g to the tdc and the bbpd; STA propagates it through x5.
#   div      clk_gen's divider pulse (x1/div), from the ring. Same frequency as
#            clk_ref but not phase-related by anything STA can trace -- comparing
#            the two IS what the tdc and the bbpd do.
#   sel      clk_gen's injection window (x1/sel): sampled asynchronously by
#            lock_ctrl (inj). It clocks nothing (bbpd's late flag is gone,
#            2026-10-29); defined so the inj path is treated as asynchronous.
#
# NOT covered by STA, and by design: div and clk_ref_g are compared against
# each other, so what matters is that their routes from clk_gen / x5 to the
# tdc and bbpd pins MATCH, not that they meet a check. pnr/match_report.tcl
# reports the post-route arrival difference (gate: |delta| <~ 20 ps, one TDC
# LSB is ~16 ps).

create_clock -name clk_ref -period 10.0 [get_ports clk_ref]
create_clock -name div     -period 10.0 [get_pins x1/div]
create_clock -name sel     -period 10.0 [get_pins x1/sel]
set_clock_groups -asynchronous -group {clk_ref} -group {div} -group {sel}

set_clock_uncertainty 0.05 [all_clocks]
set_clock_transition  0.15 [all_clocks]

# resetb is asynchronous everywhere it lands (every block's flops reset on it).
set_false_path -from [get_ports resetb]

# clk_out is the ring itself; it has no clocked path.
set_false_path -to [get_ports clk_out]

# code and locked are status outputs, quasi-static once locked. Same I/O
# budget as the blocks.
set_output_delay 2.0 -clock clk_ref [get_ports {code[*] locked}]
