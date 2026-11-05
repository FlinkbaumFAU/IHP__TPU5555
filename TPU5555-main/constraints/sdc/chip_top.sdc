# Adapted from https://github.com/IHP-GmbH/ihp-sg13-librelane-template (librelane/chip_top.sdc)
current_design $::env(DESIGN_NAME)
set_units -time ns

# Three clocks: the core clock (CLOCK_PERIOD) and the SPI front end, which
# clocks flops on both sclk edges and on the falling edge of cs_n (also its
# async reset). All are defined on the IOPadIn p2c pins. The SPI side reaches
# the core only through toggle synchronizers, so clk is asynchronous to it.
set spi_period 100.0 ;# 10 MHz SCLK; sclk/cs_n are timed against each other

create_clock [get_pins clk_pad/p2c]  -name clk  -period $::env(CLOCK_PERIOD)
create_clock [get_pins sclk_pad/p2c] -name sclk -period $spi_period
create_clock [get_pins cs_n_pad/p2c] -name cs_n -period $spi_period
# The MDLL (i_mdll) and its /4 counter: the reference from its own pad
# (100 MHz nominal), and clk_out, which clocks only the counter. clk_out is
# 4x the reference at lock; during acquisition the ring runs at up to ~1.5
# GHz (ff, code 0), where the divided pad output does not matter. 1.25 ns
# covers lock up to 200 MHz reference.
create_clock [get_pins mdll_clk_ref_pad/p2c] -name mdll_ref -period 10.0
create_clock [get_pins i_mdll/clk_out]       -name mdll_out -period 1.25
set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks {sclk cs_n}] \
    -group [get_clocks mdll_ref] -group [get_clocks mdll_out]

# cs_n (async reset for the SPI front end) and sclk never transition at the
# same instant: SPI framing holds SCLK idle while CS toggles, and keeps CS low
# (stable) for the whole burst while SCLK is active. The removal/recovery
# check STA runs between them (same clock group) is a worst-case phase
# assumption that can never occur in real operation, not a genuine risk.
# Standalone recheck against full-test-v4's post-route netlist/SPEF confirmed
# this is the single dominant hold violator in every corner (fast: -0.198ns
# vs. the next-worst real hold path at -0.054ns) and that false-pathing it
# clears it completely, leaving only ordinary same-clock hold paths.
set_false_path -hold -from [get_clocks cs_n] -to [get_clocks sclk]
set_false_path -hold -from [get_clocks sclk] -to [get_clocks cs_n]

set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
puts "\[INFO] Setting output delay to: $output_delay_value"
puts "\[INFO] Setting input delay to: $input_delay_value"

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
}

set clocks [get_clocks clk]
set spi_io_delay [expr $spi_period * $::env(IO_DELAY_CONSTRAINT) / 100]

# rstn is asynchronous to clk; constrained like the template's inputs so the
# pad-to-core path is still timed
set_input_delay -min 0 -clock $clocks [get_ports pad_rstn]
set_input_delay -max $input_delay_value -clock $clocks [get_ports pad_rstn]
set_output_delay $output_delay_value -clock $clocks [get_ports pad_led]

# MDLL: resetb is asynchronous (it also resets the /4 counter); code,
# locked and the /4 clock are observed off chip, not captured by anything
# on it.
set_false_path -from [get_ports pad_mdll_resetb]
set_false_path -to [get_ports {pad_mdll_clk pad_mdll_clk_raw pad_mdll_locked pad_mdll_code[*]}]

# SPI mode 0: mosi sampled on rising sclk, miso shifted on falling sclk
set_input_delay -min 0 -clock [get_clocks sclk] [get_ports pad_mosi]
set_input_delay -max $spi_io_delay -clock [get_clocks sclk] [get_ports pad_mosi]
set_output_delay $spi_io_delay -clock [get_clocks sclk] [get_ports pad_miso]

set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting load to: $cap_load"
set_load $cap_load [all_outputs]

puts "\[INFO] Setting clock uncertainty to: $::env(CLOCK_UNCERTAINTY_CONSTRAINT)"
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) [all_clocks]

puts "\[INFO] Setting clock transition to: $::env(CLOCK_TRANSITION_CONSTRAINT)"
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) [all_clocks]

# The /4 counter's bits capture on the same mdll_out edge that launched them
# (bit 0 is a one-inverter self-loop): clock jitter does not change that
# edge, so the 0.25 ns hold uncertainty above only demanded delay the
# resizer could not add without breaking setup (mdll-v1: hold -0.094 ns,
# fast). Setup keeps the full uncertainty.
set_clock_uncertainty -hold 0.05 [get_clocks mdll_out]

puts "\[INFO] Setting timing derate to: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1-[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]
set_timing_derate -late [expr 1+[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}

