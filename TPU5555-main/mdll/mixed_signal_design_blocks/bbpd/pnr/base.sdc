# Timing constraints for bbpd.
#
# Two clocks arrive at this block and only one of them is a clock in the
# ordinary sense:
#
#   clk_ref  the system reference. Everything stateful except the comparator's
#            first flop runs on it, through x1.x6 (buf_2) and two delay chains:
#              x1.x7               -> x1.clk_x2  x1.x2, the retiming flop (~0.42 ns tt)
#              x1.x7..x1.x10       -> clk_dlf    dlf's state, the code (~1.2 ns tt)
#              x1.x6               -> clk_ref_d  dlf's re-register of load/seed
#            The chains are delay cells, so STA propagates them as clk_ref with
#            insertion delay -- that is what makes the paths below checkable.
#            (No CTS on this block, pnr/config.yaml: a tree builder would try
#            to balance the latencies away.)
#   div      the divider's 1-in-4 pulse from clk_gen. Nominally the same
#            frequency as clk_ref -- comparing the two IS the function of this
#            block -- but it originates in a free-running ring oscillator, so
#            the two are not phase related by anything STA can trace.
#
# Why the delays: the decision on run k exists only at the clk_ref edge that
# starts run k+1, and acting on it within run k+1 rather than k+2 cuts the
# bang-bang limit cycle from three code LSBs to one
# (lock_ctrl/simul/sweep_variants.py). So x2 and dlf capture in the SAME
# reference cycle, a fraction of a nanosecond apart. See rtl/dlf.v for why an
# unresolved comp is harmless there.

create_clock -name clk_ref -period 10.0 [get_ports clk_ref]
create_clock -name div     -period 10.0 [get_ports div]

set_clock_uncertainty 0.05 [all_clocks]
set_clock_transition  0.15 [all_clocks]

# dlf's state flops: everything clocked by clk_dlf (the code register). The
# load/seed re-register is on clk_ref_d and is NOT in this set.
set dlf_state_d {}
foreach pin [get_pins -of_objects [get_nets clk_dlf] -filter "direction == input"] {
    lappend dlf_state_d [get_pins "[get_full_name [get_cells -of_objects $pin]]/D"]
}

# --- the exceptions this block needs ----------------------------------------
#
# 1. The comparison itself: clk_ref -> x1.x1/D, captured on div.
#
# x1.x1 samples clk_ref on the div edge, and at lock those edges coincide by
# construction. STA sees an input-to-register path with a hold requirement and
# reports it violated in the fast corner -- which is not a defect, it is the
# tool asking the circuit not to do its job. A bang-bang phase detector HAS no
# hold margin at its decision point; that is what makes its gain infinite.
#
# Falsed narrowly, on that one path. (`set_clock_groups -asynchronous` would
# also work but is a much broader claim, and as a false path it would outrank
# the max-delay below.)
set_false_path -from [get_ports clk_ref] -to [get_pins x1.x1/D]

# 2. x1.x1 -> x1.x2, the div -> clk_ref crossing.
#
# div lands ~0.1 ns after clk_ref at lock (0.15 ns ss) and x2 samples 0.42 ns
# after it (0.65 ns ss), so comp_raw has to get there fast: x1's clock-to-Q
# (0.15 / 0.23 ns) plus one short net, and x2's setup. The max-delay keeps that
# net short; -ignore_clock_latency makes it the data path alone (div's and
# clk_x2's insertion delays are what the margin is made of). The start point is
# the flop's CLOCK pin: OpenSTA drops `-from x1.x1/Q` ("STA-1554 not a valid
# start point") and the constraint would quietly do nothing.
#
# No hold check: STA sees div and clk_ref as aligned clocks, so x2 capturing
# x1's decision in the same cycle -- the point -- looks like a hold violation
# (-0.35 ns at tt). For this asynchronous crossing it means nothing.
set_max_delay 0.50 -ignore_clock_latency -from [get_pins x1.x1/CLK] -to [get_pins x1.x2/D]
set_false_path -hold -from [get_pins x1.x1/CLK] -to [get_pins x1.x2/D]

# 3. Same-cycle captures onto clk_dlf: x1.x2 -> dlf state (comp), and the
#    load/seed re-register -> dlf state.
#
# Launched on clk_ref (+0.42 ns or +0.06 ns of insertion delay), captured on
# clk_ref +1.2 ns OF THE SAME EDGE. By default STA checks setup against the
# next edge and hold against this one -- it would report a hold violation and
# the resizer would delay these paths by a whole period, undoing the point.
# Setup multiplier 0 checks setup against the same edge (the real constraint)
# and moves hold to the previous one.
set_multicycle_path 0 -setup -from [get_pins x1.x2/CLK] -to $dlf_state_d
set preg_clk {}
foreach pin [get_pins -of_objects [get_nets clk_ref_d] -filter "direction == input"] {
    if {[string match */CLK [get_full_name $pin]]} { lappend preg_clk $pin }
}
set_multicycle_path 0 -setup -from $preg_clk -to $dlf_state_d

# These cover every path between the domains: div reaches only x1.x1/CLK, and
# x1.x1/Q only x1.x2/D.

# I/O budget. load/seed come from lock_ctrl, ~0.8 ns (tt) / 1.3 ns (ss) after
# clk_ref, and are re-registered on clk_ref_d: a full-period path. C[7:0]
# drives clk_gen's decoder, which is combinational; it changes ~1.9 ns after
# clk_ref (tt) and is used for the rest of the run.
set_input_delay  2.0 -clock clk_ref [all_inputs -no_clocks]
set_output_delay 2.0 -clock clk_ref [all_outputs]
