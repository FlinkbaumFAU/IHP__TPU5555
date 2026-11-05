# Synthesise the Vernier ring counter to sg13g2 gates.
#
# Same arrangement as bbpd/synth/synth_dlf.tcl: the RTL is mapped here, outside
# LibreLane, so the hardening flow runs with SYNTH_ELABORATE_ONLY and never
# re-optimises the hand-drawn parts of the TDC (the rings, the edge-lock
# detector and the phase detector are all timing-critical structures that a
# resizer would happily "fix").
#
# One module serves both rings (src/tdc.sch instantiates it twice).
#
# Clocked straight off a ring output at ~1 GHz, so the incrementer is mapped
# for speed; post-PnR STA with a clock on each ring output is the check.

yosys -import

set design_name counter
set width 8
set current_corner "typ_1p20V_25C"

set pdk_root $::env(PDK_ROOT)
set pdk $::env(PDK)
set pdk_path "${pdk_root}/${pdk}"

set liberty "${pdk_path}/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_${current_corner}.lib"

read_verilog ./counter/src/counter.v

hierarchy -top ${design_name} -chparam COUNTER_WIDTH ${width}
flatten
synth -top ${design_name}

dfflibmap -liberty ${liberty}
techmap
abc -D 900 -liberty ${liberty}
opt_clean

hilomap -hicell sg13g2_tiehi L_HI -locell sg13g2_tielo L_LO
opt_clean -purge

stat -liberty ${liberty}
write_verilog -noattr "build/01-synth/${design_name}.v"
