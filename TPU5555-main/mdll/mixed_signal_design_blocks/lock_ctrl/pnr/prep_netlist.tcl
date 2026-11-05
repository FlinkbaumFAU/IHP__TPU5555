# Flatten and clean the P&R netlist.
#
# LibreLane runs with SYNTH_ELABORATE_ONLY on the netlist synth_lock_ctrl.tcl
# mapped and lec_lock_ctrl.tcl proved equivalent to the RTL, so the hardened
# cells are the ones the SPICE model (simulations/lock_ctrl.spice) and the LEC
# describe. Elaborate-only skips yosys' cleanup, and the mapped netlist carries
# a bit-level alias (`assign _318_[9] = _318_[11]`) that LibreLane's netlist
# checker rejects; splitnets + opt_clean resolves it without touching a cell
# (every instance is `keep`, as in the other blocks).

set pdk "$::env(PDK_ROOT)/$::env(PDK)"

yosys -import
read_liberty -lib ${pdk}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
read_verilog build/01-synth/lock_ctrl.v

hierarchy -check -top lock_ctrl
setattr -set keep 1 t:*
splitnets
opt_clean -purge

write_verilog -noattr build/01-synth/lock_ctrl.flat.v
stat
