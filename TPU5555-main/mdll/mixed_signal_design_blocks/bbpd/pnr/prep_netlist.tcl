# Flatten and clean the P&R netlist.
#
# LibreLane runs with SYNTH_ELABORATE_ONLY (the netlist is already mapped and
# the comparator's cell choices are deliberate), but elaborate-only also skips
# the cleanup passes, so yosys' own flatten leaves hierarchy-port alias
# `assign` statements that P&R cannot place. Doing the flatten here lets us
# clean up while explicitly protecting every cell: `keep` on all instances
# means opt_clean may only drop dangling alias wires, never a cell.
#
# That guard is not decorative here. src/pd.sch's x1 looks redundant to a
# logic optimiser -- its D input is a clock -- and letting opt_clean reason
# about it is exactly the wrong outcome.

set pdk "$::env(PDK_ROOT)/$::env(PDK)"

yosys -import
read_liberty -lib ${pdk}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
read_verilog build/01-synth/bbpd.pnr.v

hierarchy -check -top bbpd

# Protect every instance before any optimisation runs.
setattr -set keep 1 t:*

flatten
opt_clean -purge

write_verilog -noattr build/01-synth/bbpd.flat.v
stat
