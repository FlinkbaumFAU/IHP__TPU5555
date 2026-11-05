# Formal equivalence: RTL dco_decode vs. the synthesised sg13g2 netlist.
#
# Combinational and small, so the SAT proof is exhaustive over the whole input
# space -- strictly stronger than simulating all 256 codes. Liberty is read
# without -lib so the cells come in as functional models rather than blackboxes.

set pdk_path "$::env(PDK_ROOT)/$::env(PDK)"
set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"

yosys -import

# --- golden: RTL ---
read_verilog ./rtl/bin2therm.v
read_verilog ./rtl/dco_decode.v
prep -top dco_decode -flatten
design -stash gold

# --- revised: synthesised gates ---
read_liberty -ignore_miss_func ${liberty}
read_verilog ./build/01-synth/dco_decode.v
prep -top dco_decode -flatten
design -stash gate

design -copy-from gold -as gold dco_decode
design -copy-from gate -as gate dco_decode

miter -equiv -flatten -make_assert gold gate miter
sat -verify -prove-asserts miter
