# Flatten and clean the P&R netlist.
#
# LibreLane runs with SYNTH_ELABORATE_ONLY (the netlist is already mapped and
# the two Vernier rings are deliberate combinational loops), but elaborate-only
# also skips the cleanup passes, so yosys' own flatten leaves hierarchy-port
# alias `assign` statements that P&R cannot place.
#
# Doing the flatten here instead lets us clean up while explicitly protecting
# every cell: `keep` on all instances means opt_clean may only drop dangling
# alias wires, never a cell. That matters twice over here: custom_cap_16 has no
# output pin, so an unguarded opt_clean would delete every trim cap; and the
# phase detector's flop samples a clock-derived enable, which a logic optimiser
# has no reason to keep.

set pdk "$::env(PDK_ROOT)/$::env(PDK)"

yosys -import
read_liberty -lib ${pdk}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
# custom_stdcell is a separate repo next to this one; yosys runs in the block dir.
read_liberty -lib ../../custom_stdcell/custom_stdcell.lib
read_verilog build/01-synth/tdc.pnr.v

hierarchy -check -top tdc

# Protect every instance before any optimisation runs.
setattr -set keep 1 t:*

flatten
# The synthesised counter declares multi-bit internal wires (_06_[7:0]) of
# which only bit 0 is really driven; the other bits are aliases of the count
# outputs. Kept whole, the vector survives opt_clean and the aliases come out
# as `assign` statements, which LibreLane's netlist checker rejects. Splitting
# to single bits (ports excluded, so the bus pins keep their names) lets
# opt_clean drop the dead alias bits.
splitnets
opt_clean -purge

write_verilog -noattr build/01-synth/tdc.flat.v
stat
