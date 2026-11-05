# Synthesise lock_ctrl to sg13g2 gates.
#
# Same arrangement as bbpd/synth/synth_dlf.tcl: the RTL is mapped here, outside
# LibreLane, so that the top-level hardening can run with SYNTH_ELABORATE_ONLY
# and never re-optimise the hand-drawn parts of the MDLL.
#
# `load` resets HIGH (the controller owns dlf from the first edge), and
# sg13g2's only non-scan async flop resets LOW. yosys stores that bit inverted
# and inverts around the flop; synth/lec_lock_ctrl.tcl checks the result in the
# time domain.

yosys -import

set design_name lock_ctrl
set current_corner "typ_1p20V_25C"

set pdk_root $::env(PDK_ROOT)
set pdk $::env(PDK)
set pdk_path "${pdk_root}/${pdk}"

set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_${current_corner}.lib"

read_verilog ./rtl/lock_ctrl.v

hierarchy -top ${design_name}
flatten
synth -top ${design_name}

dfflibmap -liberty ${liberty}
techmap
abc -liberty ${liberty}
opt_clean

# Any constant-driven bit needs a real tie cell, not a bare 1'b0/1'b1 that P&R
# cannot route.
hilomap -hicell sg13g2_tiehi L_HI -locell sg13g2_tielo L_LO
opt_clean -purge

stat -liberty ${liberty}
write_verilog -noattr "build/01-synth/${design_name}.v"

# No write_spice: common/sim/gen_rtl_spice.py emits the structural subckt
# (Makefile, simulations/lock_ctrl.spice).
