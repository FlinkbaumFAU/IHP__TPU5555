# Timing constraints for the Vernier TDC.
#
# Like clk_gen, this is not a synchronous design with one clock. There are
# seven clock sources, most of them internal, and the interesting timing -- the
# Vernier resolution itself -- is set by the rings and characterised in SPICE
# (make tdc_sim), not by STA. What STA CAN check, and what these constraints
# are arranged to leave checked:
#
#   * each 8-bit counter against the period of the ring that clocks it -- the
#     one place the TDC has to close ordinary setup/hold at ~1 GHz
#   * the edge-lock detector's second stage (x3.x4 samples x3.x3, both on the
#     fast ring)
#   * the reset generator's toggle flop against Sel
#
# Paths BETWEEN these sources are asynchronous by construction (two
# free-running rings, the DCO output, the reference, and event clocks derived
# from them), so the groups below are declared asynchronous. Two crossings in
# that set are deliberate samplers and are named for the record:
#   x14.x1  (phase detector) samples fast_enable on delayed slow_enable
#   x3.x3   (edge lock)      samples the slow ring on the fast ring
# Both are operated metastable at their decision point, exactly like bbpd's
# comparator. The capture-register race (counts vs. the self-clear) is also a
# crossing STA cannot see; tdc_sim measures its margin in SPICE.

# --- external clocks -------------------------------------------------------
create_clock -name clk_ref -period 10.0 [get_ports Clk_ref]
# clk_gen's output; 400 MHz at lock. Only clocks the slow-ring start flop x6,
# whose D is a tie cell, so the period only matters for reporting.
create_clock -name clk_out -period 2.5  [get_ports Clk_out]
create_clock -name sel     -period 10.0 [get_ports Sel]

# --- internal clocks ---------------------------------------------------------
# x8 toggles on Sel; its Q clocks x9, arming the TDC every second Sel.
create_generated_clock -name arm -source [get_ports Sel] -divide_by 2 \
    [get_pins x8/Q]

# The two rings' output buffers, each clocking its own counter.
#
# The ring period is NOT a fixed number: it moves with PVT exactly as
# the counter's own gates do, and a single period would fail the slow corner
# and flatter the fast one. LibreLane names the corner it is timing in
# _CURRENT_CORNER_NAME, so each corner is checked against the ring period
# SPICE measures at the same PVT (make osci_sim; pre-layout values, which are
# slightly FASTER than the routed rings, so this errs tight). Steps that time
# all corners in one session (the resizer) see the typical values.
#
#   corner  PVT              T_slow  T_fast  (ns)
#   typ     1.20 V   25 C    1.064   1.047   (also the fallback)
#   slow    1.08 V  125 C    1.686   1.664
#   fast    1.32 V  -40 C    0.701   0.688
#
# No comments inside the switch body: there a `;#` is not a comment but more
# pattern/body words, which silently shifts the pairing so later cases never
# match (the first version of this block timed the fast corner at typ).
set ring_period_s 1.064
set ring_period_f 1.047
if { [info exists ::env(_CURRENT_CORNER_NAME)] } {
    switch -glob -- $::env(_CURRENT_CORNER_NAME) {
        *slow* { set ring_period_s 1.686; set ring_period_f 1.664 }
        *fast* { set ring_period_s 0.701; set ring_period_f 0.688 }
    }
}
puts "tdc base.sdc: ring_s $ring_period_s ns, ring_f $ring_period_f ns"
create_clock -name ring_s -period $ring_period_s [get_pins x5.xo/X]
create_clock -name ring_f -period $ring_period_f [get_pins x4.xo/X]

# Slow-ring start (x6/Q) -> x14.x2 -> the phase detector's clock pin.
create_clock -name slow_start -period 20.0 [get_pins x6/Q]

# Detect OR hit_raw: the capture register's clock.
create_clock -name cap -period 20.0 [get_pins x15/X]

set_clock_uncertainty 0.05 [all_clocks]
set_clock_transition  0.15 [all_clocks]

set_clock_groups -asynchronous \
    -group {clk_ref} -group {clk_out} -group {sel arm} \
    -group {ring_s} -group {ring_f} -group {slow_start} -group {cap}

# --- I/O ----------------------------------------------------------------------
# Start is the global active-low reset: quasi-static, applied for many
# reference periods.
set_false_path -from [get_ports Start]
# The results are held in the capture register until the next run ends --
# tens of ns at minimum -- and busy/valid tell the consumer when to sample.
# Timing into the consumer is the consumer's constraint, not this block's.
set_false_path -to [all_outputs]
