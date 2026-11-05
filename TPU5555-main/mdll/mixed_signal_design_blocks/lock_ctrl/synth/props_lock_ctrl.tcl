# Bounded model check of lock_ctrl's properties (synth/props_lock_ctrl.v).
#
# Depth covers the reset force, several complete measure/jump iterations
# (>= 2 ARM, >= 2 WAIT per iteration) and the handover.

set depth 48

yosys -import

read_verilog -formal ./rtl/lock_ctrl.v
read_verilog -formal ../bbpd/rtl/dlf.v
read_verilog -formal ./synth/props_lock_ctrl.v

prep -top lock_ctrl_props -flatten
async2sync

sat -seq ${depth} -prove-asserts -verify -set-at 1 resetb 0 lock_ctrl_props
