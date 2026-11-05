# Synthesise the DCO cap-bank decoder to sg13g2 gates.
#
# Purely combinational (no flops, so no dfflibmap), and small enough that area
# is irrelevant -- the point is to get a structural netlist that dco.sch can
# instantiate via dco_decode.sym and that the hardening flow can consume.

yosys -import

set design_name dco_decode
set current_corner "typ_1p20V_25C"

set pdk_root $::env(PDK_ROOT)
set pdk $::env(PDK)
set pdk_path "${pdk_root}/${pdk}"

set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_${current_corner}.lib"

read_verilog ./rtl/bin2therm.v
read_verilog ./rtl/dco_decode.v

hierarchy -top ${design_name}
# The dither gates (dco_andn/or/ao/mux4, rtl/dco_decode.v) are mapped on their
# own, so abc cannot give the ring-clocked g[1:0] a path to a cap enable through
# more than one gate (a glitch on a running node). Flattened after mapping:
# everything downstream expects one module.
setattr -mod -set keep_hierarchy 1 dco_andn dco_or dco_ao dco_mux4
synth -top ${design_name}
techmap
abc -liberty ${liberty}
opt_clean
setattr -mod -unset keep_hierarchy dco_andn dco_or dco_ao dco_mux4
flatten
opt_clean

# Constant-driven outputs (cob3[7] is tied low by construction) need a real
# tie cell, otherwise the netlist carries a bare 1'b0 that P&R cannot route.
hilomap -hicell sg13g2_tiehi L_HI -locell sg13g2_tielo L_LO
opt_clean -purge

stat -liberty ${liberty}
write_verilog -noattr "build/01-synth/${design_name}.v"

# NOTE: no write_spice here. Yosys' SPICE backend emits a flat netlist with no
# .subckt wrapper, dotted net names, and cell instances missing VDD/VSS -- the
# PDK's sg13g2_inv_1 is "Y A VDD VSS", so that output will not simulate.
# simulations/gen_decode_spice.py emits a behavioural subckt instead, which is
# the right fidelity for a PLL lock sim: the decoder is combinational and
# already SAT-proven, so 105 gates of it in a transient buys nothing.
