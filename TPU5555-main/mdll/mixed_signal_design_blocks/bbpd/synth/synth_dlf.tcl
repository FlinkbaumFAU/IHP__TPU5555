# Synthesise the loop-filter accumulator to sg13g2 gates.
#
# Same arrangement as clk_gen/synth/synth_decode.tcl: the RTL is mapped here,
# outside LibreLane, so that the hardening flow can run with
# SYNTH_ELABORATE_ONLY and never re-optimise the hand-drawn structural parts of
# the design (src/pd.sch's comparator flop is deliberately operated metastable
# and must not be resized or rebuffered).
#
# Unlike dco_decode this design has state, so dfflibmap runs before abc.
#
# RESET_CODE (0x18, Gray 0x14) and load_r reset some bits HIGH. sg13g2's only non-scan
# asynchronous flop is sg13g2_dfrbp_* (reset to 0), so there is no async-set
# cell to map those bits onto. yosys handles it by storing the complement in
# those bits and inverting around the flop -- check the dfflibmap output and
# the final stat for that, since it is the one thing in this mapping that is
# not a literal transcription of the RTL.

yosys -import

set design_name dlf
set current_corner "typ_1p20V_25C"

set pdk_root $::env(PDK_ROOT)
set pdk $::env(PDK)
set pdk_path "${pdk_root}/${pdk}"

set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_${current_corner}.lib"

read_verilog ./rtl/dlf.v

hierarchy -top ${design_name}
# dlf_and/dlf_xor (keep_hierarchy) are the only gates comp passes: one AND
# with a static input ("this Gray bit differs"), one XOR. Mapped on their own,
# so abc can neither fold comp into the +-1 logic nor give it a gate in which
# a mid-level comp could reach a bit that does not depend on it (rtl/dlf.v).
# The netlist is flattened after mapping: everything downstream expects one
# module.
setattr -mod -set keep_hierarchy 1 dlf_and dlf_xor
synth -top ${design_name}

dfflibmap -liberty ${liberty}
techmap
abc -liberty ${liberty}
opt_clean
setattr -mod -unset keep_hierarchy dlf_and dlf_xor
flatten
opt_clean

# Any constant-driven bit needs a real tie cell, not a bare 1'b0/1'b1 that P&R
# cannot route.
hilomap -hicell sg13g2_tiehi L_HI -locell sg13g2_tielo L_LO
opt_clean -purge
# The Gray tree passes some bits straight through (code[7] is g[7]), and yosys
# writes such aliases of named wires as `assign`, which LibreLane rejects
# ("One or more assign statements found in the netlist"). Make them buffers.
insbuf -buf sg13g2_buf_1 A X
opt_clean -purge

stat -liberty ${liberty}
write_verilog -noattr "build/01-synth/${design_name}.v"

# No write_spice: yosys' SPICE backend emits a flat netlist with no .subckt
# wrapper, dotted net names and cells missing VDD/VSS.
# common/sim/gen_rtl_spice.py emits a structural subckt from this netlist
# instead (bbpd/Makefile, simulations/dlf.spice).
