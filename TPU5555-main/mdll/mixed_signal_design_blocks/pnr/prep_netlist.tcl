# Clean the top-level P&R netlist: mdll = four macros + x5 (lgcp_1) + x6
# (tiehi), from common/pnr/mk_netlist.py. The macros are read as blackboxes
# from their hardened Verilog headers (build/macros/<block>/vh, no power pins
# without USE_POWER_PINS -- PDN_MACRO_CONNECTIONS wires those). Same shape as
# the blocks' prep_netlist.tcl: keep every instance, then let opt_clean drop
# only dangling alias wires.
#
# MACRO_DIR is build/macros or build/sg13cmos5l/macros (the Verilog headers
# are the same), FLAT the output. The cells are sg13g2 here either way; the
# CMOS5L netlist is renamed afterwards (common/pnr/retarget.py).

set pdk "$::env(PDK_ROOT)/$::env(PDK)"

yosys -import
read_liberty -lib ${pdk}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib
foreach blk {clk_gen tdc bbpd lock_ctrl} {
    read_verilog -lib $::env(MACRO_DIR)/${blk}/vh/${blk}.vh
}
read_verilog build/01-synth/mdll.pnr.v

hierarchy -check -top mdll
setattr -set keep 1 t:*
splitnets
opt_clean -purge

write_verilog -noattr $::env(FLAT)
stat
