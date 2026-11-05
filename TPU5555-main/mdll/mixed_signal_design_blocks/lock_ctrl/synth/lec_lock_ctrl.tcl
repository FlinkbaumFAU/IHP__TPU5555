# Formal equivalence: RTL lock_ctrl vs. the synthesised sg13g2 netlist.
#
# Bounded sequential miter, as bbpd/synth/lec_dlf.tcl. resetb is forced low at
# t=1 so both sides start from the same known state; after that every input is
# free. The depth covers several complete measure/jump iterations of the state
# machine, the inverted reset-high `load` flop (see synth_lock_ctrl.tcl), and
# FINE's out-of-lock counters: 16 injecting edges to forget a miss, 8 at a rail
# (32, was 24 before them).
#
# async2sync on both sides: yosys' SAT engine cannot import async-reset flops.

set pdk_path "$::env(PDK_ROOT)/$::env(PDK)"
set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib"
set seq_depth 32

yosys -import

# --- golden: RTL ---
read_verilog ./rtl/lock_ctrl.v
prep -top lock_ctrl -flatten
async2sync
design -stash gold

# --- revised: synthesised gates ---
read_liberty -ignore_miss_func ${liberty}
read_verilog ./build/01-synth/lock_ctrl.v
prep -top lock_ctrl -flatten
async2sync
design -stash gate

design -copy-from gold -as gold lock_ctrl
design -copy-from gate -as gate lock_ctrl

miter -equiv -flatten -make_assert gold gate miter
hierarchy -top miter

sat -seq ${seq_depth} -prove-asserts -verify -set-at 1 in_resetb 0 miter
