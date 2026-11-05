# Formal equivalence: RTL counter vs. the synthesised sg13g2 netlist.
#
# Bounded sequential miter, as bbpd/synth/lec_dlf.tcl. rst_n is forced low at
# t=1 so both sides start from the same known state; after that every input is
# free. SEQ_DEPTH exceeds 2^WIDTH so the proof covers a full wrap of the
# 8-bit count, not just the first few increments.
#
# async2sync on both sides: yosys' SAT engine cannot import async-reset flops.
# What is proved is the CLOCKED behaviour; the reset response itself goes
# through the same sg13g2_dfrbp RESET_B pin on both sides.

set pdk_path "$::env(PDK_ROOT)/$::env(PDK)"
set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"
set width 8
set seq_depth 260

yosys -import

# --- golden: RTL ---
read_verilog ./counter/src/counter.v
hierarchy -top counter -chparam COUNTER_WIDTH ${width}
prep -top counter -flatten
async2sync
design -stash gold

# --- revised: synthesised gates ---
read_liberty -ignore_miss_func ${liberty}
read_verilog ./build/01-synth/counter.v
prep -top counter -flatten
async2sync
design -stash gate

design -copy-from gold -as gold counter
design -copy-from gate -as gate counter

miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter

sat -seq ${seq_depth} -prove-asserts -verify -set-at 1 in_rst_n 0 miter
