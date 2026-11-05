# Formal equivalence: RTL dlf vs. the synthesised sg13g2 netlist.
#
# Unlike clk_gen/synth/lec_decode.tcl this design has state, so the proof is a
# BOUNDED sequential miter rather than an exhaustive combinational one.
#
# The bound matters here because the mapping is not a literal transcription.
# RESET_CODE = 0x18 (Gray 0x14) and load_r reset some bits HIGH, and sg13g2's only non-scan async flop
# resets LOW, so dfflibmap stores those bits inverted and inverts around the
# flop. The reset state, the saturation logic and the inverted bits therefore
# all have to be checked in the time domain, not just as a cone of logic.
#
# resetb is forced low at t=1 so both sides start from a KNOWN, identical
# state; without that the free initial state alone is a counterexample and the
# proof says nothing. Steps 2..N then run with every input free.
#
# async2sync runs on both sides before the miter: yosys' SAT engine cannot
# import $_DFF_PN0_ (async reset) at all. It rewrites the async reset into a
# mux on the D input, so what is proved is equivalence of the CLOCKED
# behaviour. Reset response between clock edges is out of scope -- acceptable
# because both sides reset through the same sg13g2_dfrbpq_1 RESET_B pin.
#
# SEQ_DEPTH is well past what this design needs: the accumulator's only state
# is the 8-bit code, and every reachable difference (saturation at either rail,
# the inverted bits, load priority) shows up within a couple of cycles.

set pdk_path "$::env(PDK_ROOT)/$::env(PDK)"
set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"
set seq_depth 16

yosys -import

# --- golden: RTL ---
read_verilog ./rtl/dlf.v
prep -top dlf -flatten
async2sync
design -stash gold

# --- revised: synthesised gates ---
read_liberty -ignore_miss_func ${liberty}
read_verilog ./build/01-synth/dlf.v
prep -top dlf -flatten
async2sync
design -stash gate

design -copy-from gold -as gold dlf
design -copy-from gate -as gate dlf

miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter

sat -seq ${seq_depth} -prove-asserts -verify -set-at 1 in_resetb 0 miter
