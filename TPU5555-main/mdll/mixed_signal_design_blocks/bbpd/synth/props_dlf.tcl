# Bounded model check of rtl/dlf.v against synth/props_dlf.v.
#
# Covers: load priority, |delta code| <= 1, no wrap at either rail, direction
# follows comp, and reset forces RESET_CODE. See props_dlf.v for why these are
# the properties that matter.
#
# resetb is forced low at t=1 so both the DUT and the property wrapper's
# history registers start from a known state; every input is free thereafter.
# Depth 24 is far past the design's diameter -- the only state is the 8-bit
# code and every property is a one-cycle relation over it.

set depth 24

yosys -import

read_verilog -formal ./rtl/dlf.v
read_verilog -formal ./synth/props_dlf.v

prep -top dlf_props -flatten
async2sync

sat -seq ${depth} -prove-asserts -verify -set-at 1 resetb 0 dlf_props
