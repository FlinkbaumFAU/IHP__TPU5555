# Flatten and clean the P&R netlist.
#
# LibreLane runs with SYNTH_ELABORATE_ONLY (the netlist is already mapped and
# the ring is a deliberate combinational loop we do not want re-optimised), but
# elaborate-only also skips the cleanup passes, so yosys' own flatten leaves
# ~178 hierarchy-port alias `assign` statements that P&R cannot place.
#
# Doing the flatten here instead lets us clean up while explicitly protecting
# every cell: `keep` on all instances means opt_clean may only drop dangling
# alias wires, never a cell. That matters -- custom_cap_4 has no output pin at
# all, so an unguarded opt_clean would happily delete all 64 of them.

set pdk "$::env(PDK_ROOT)/$::env(PDK)"

yosys -import
read_liberty -lib ${pdk}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
# custom_stdcell is a separate repo next to this one; yosys runs in the block dir.
read_liberty -lib ../../custom_stdcell/custom_stdcell.lib
read_verilog build/01-synth/clk_gen.pnr.v

hierarchy -check -top clk_gen

# Protect every instance before any optimisation runs.
setattr -set keep 1 t:*

flatten
opt_clean -purge

write_verilog -noattr build/01-synth/clk_gen.flat.v
stat
