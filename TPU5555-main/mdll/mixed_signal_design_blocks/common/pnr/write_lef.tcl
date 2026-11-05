# Abstract LEF of a hardened block, from its final ODB.
#
# The flows run without magic (see the substituting_steps in any
# pnr/config.yaml), and in LibreLane 3.0.16 Magic.WriteLEF is the only step
# that writes the design LEF, so the root Makefile's macros targets call this.
#
# -bloat_factor 2 (um), not -bloat_occupied_layers: magic's `lef write -hide`
# obstructed each block's core on Metal1..Metal3 but left the margin between
# core and die edge open, where the pins are. -bloat_occupied_layers covers the
# whole bbox, the top level's div/clk_ref_g routes detoured, and their loads
# came out 29.9 / 18.2 fF -- clk_ref_g - div -46 ps at slow on sg13cmos5l.
# Growing each shape by 2 um closes the gaps inside the core but keeps the
# ~7 um margins mostly open (21.1 / 25.6 fF, +19.9 ps). The match is that
# sensitive to routing: see TAPEOUT.md.
#
# The OBS it writes holds the wires but not the via enclosures, which reach
# past a wire's end: the Makefile grows every OBS rectangle by 0.1 um
# afterwards (grow_obs.py, which says why).
#
#   ODB=<run>/final/odb/<top>.odb LEF=<out.lef> openroad -exit -no_splash write_lef.tcl
read_db $::env(ODB)
write_abstract_lef -bloat_factor 2 $::env(LEF)
