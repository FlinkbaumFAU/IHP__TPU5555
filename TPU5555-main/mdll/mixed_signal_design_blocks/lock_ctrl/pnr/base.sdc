# Timing constraints for lock_ctrl.
#
# An ordinary synchronous block on clk_ref (period 10 ns). What makes the I/O
# unusual is the protocol around it, stated here port by port so that nothing
# is waved through with a blanket false path:
#
#   inj    clk_gen's sel, sampled asynchronously ON PURPOSE: it is only
#          ambiguous when div lands at the clk_ref edge (e ~ 0), and the RTL
#          tolerates either outcome (see rtl/lock_ctrl.v). No timing relation.
#   busy   the TDC's run flag, asynchronous; two-flop synchroniser in the RTL.
#   hit, tdc_s, tdc_f
#          the TDC's capture register; only read after busy has fallen, so
#          they are stable for many reference periods when sampled.
#   code   bbpd's dlf output. Launched by clk_ref_g, the replica-gated clk_ref
#          (mdll.sch x5, one sg13g2_lgcp_1: 62..149 ps later than clk_ref),
#          so it is a same-edge path with that much extra latency.
#
#   seed, load -> dlf, CAPTURED on clk_ref_g, i.e. up to ~0.15 ns after the
#          edge that launched them here. That is a hold requirement at the
#          port: -min output delay of -0.2 ns (replica delay + margin).
#   start, sel -> the TDC's reset generator (async reset and clock of x8).
#   locked     status only.

create_clock -name clk_ref -period 10.0 [get_ports clk]
set_clock_uncertainty 0.05 [all_clocks]
set_clock_transition  0.15 [all_clocks]

set_false_path -from [get_ports {inj busy hit tdc_s* tdc_f*}]
set_false_path -from [get_ports resetb]

# dlf's clock-to-output out of bbpd plus the replica latency, generously.
set_input_delay -max 1.5 -clock clk_ref [get_ports code*]
set_input_delay -min 0.1 -clock clk_ref [get_ports code*]

set_output_delay -max 2.0  -clock clk_ref [get_ports {seed* load start sel locked}]
set_output_delay -min -0.2 -clock clk_ref [get_ports {seed* load}]
set_output_delay -min 0.0  -clock clk_ref [get_ports {start sel locked}]
