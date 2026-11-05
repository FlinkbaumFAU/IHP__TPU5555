# clk_gen -- DCO ring, injection selector and /4 divider for the MDLL.
#
# Flow (all outputs under build/, gitignored):
#
#   clk_gen.sch + src/*.sch --xschem-->  build/01-synth/clk_gen.nl.v    hierarchy
#   rtl/dco_decode.v        --yosys-->   build/01-synth/dco_decode.v    mapped gates
#   both                    --python-->  build/01-synth/clk_gen.pnr.v   stripped
#   that                    --yosys-->   build/01-synth/clk_gen.flat.v  flat
#   that                    --librelane->pnr/runs/<tag>/final/          GDS
#
# The split exists so LibreLane can run with SYNTH_ELABORATE_ONLY and never
# re-optimise the ring (a deliberate combinational loop) or delay_cell's
# cross-coupled latch -- see common/pnr/mk_netlist.py and pnr/config.yaml.

PDK_ROOT ?= /opt/IHP-Open-PDK/
PDK      := ihp-sg13g2
# The flow tools (librelane, sta, openroad, klayout, magic) come from PATH --
# the nix profile. To run them from a librelane checkout's dev shell instead:
#   make harden NIX_SHELL="nix develop ~/Documents/Passionate/librelane -c"
NIX_SHELL ?=

# Netlist through the repo-root wrapper so that root-relative symbol
# references (clk_gen/src/dco.sym, ...) resolve from any working directory.
ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
XSCHEM := $(ROOT)/tools/xschem

IVERILOG ?= iverilog
VVP      ?= vvp

export PDK_ROOT
export PDK

SYNTH := build/01-synth

# Every schematic and symbol clk_gen is drawn from.
SCH := clk_gen.sch clk_gen.sym $(wildcard src/*.sch src/*.sym)

.PHONY: all harden netlist synth lec sim_decode char test_clk_gen sim clean

all: netlist

# --- synthesis of the cap-bank decoder --------------------------------------

# check_dither_cone.py: the ring-clocked g[1:0] may reach a cap enable only
# through single gates (rtl/dco_decode.v). A netlist that breaks it is deleted.
$(SYNTH)/dco_decode.v: rtl/dco_decode.v rtl/bin2therm.v synth/synth_decode.tcl synth/check_dither_cone.py
	@mkdir -p $(SYNTH)
	yosys -q -c synth/synth_decode.tcl -l build/synth_decode.log
	synth/check_dither_cone.py $@ || { rm -f $@; exit 1; }

synth: $(SYNTH)/dco_decode.v

# SAT equivalence of the mapped decoder against its RTL, over all 256 codes.
lec: $(SYNTH)/dco_decode.v
	yosys -q -c synth/lec_decode.tcl -l build/lec_decode.log
	@grep -q "SUCCESS" build/lec_decode.log && echo "LEC: PASS"

# Exhaustive behavioural check of the RTL decoder.
sim_decode: rtl/dco_decode.v rtl/bin2therm.v simulations/tb_dco_decode.v
	@mkdir -p build
	$(IVERILOG) -o build/tb_dco_decode.vvp $^
	$(VVP) build/tb_dco_decode.vvp

# --- netlist assembly for P&R ----------------------------------------------

$(SYNTH)/clk_gen.nl.v: $(SCH)
	@mkdir -p $(SYNTH)
	$(XSCHEM) -q -n -w -o $(SYNTH) -N clk_gen.nl.v clk_gen.sch

$(SYNTH)/clk_gen.pnr.v: $(ROOT)/common/pnr/mk_netlist.py $(SYNTH)/clk_gen.nl.v $(SYNTH)/dco_decode.v
	$(ROOT)/common/pnr/mk_netlist.py --top clk_gen \
	  --keep clk_gen dco delay_cell divider selector \
	  --nl $(SYNTH)/clk_gen.nl.v --append $(SYNTH)/dco_decode.v --out $@

$(SYNTH)/clk_gen.flat.v: pnr/prep_netlist.tcl $(SYNTH)/clk_gen.pnr.v
	yosys -q -c pnr/prep_netlist.tcl

netlist: $(SYNTH)/clk_gen.flat.v

# --- simulation --------------------------------------------------------------

# Behavioural subckt of the decoder for decks that instantiate dco.sch; see the
# script for why it is not a structural translation.
simulations/dco_decode.spice: simulations/gen_decode_spice.py simulations/gen_char_dco.py
	./simulations/gen_decode_spice.py

# DCO period vs. code over all 64 codes, sharded across cores, then the
# monotonicity check -- the acceptance gate for the cap bank.
char:
	./simulations/run_char.sh

# The xschem testbench, netlisted and run exactly as the Simulate button would.
# xschem exits 0 both when it cannot resolve a symbol ("IS MISSING") and when a
# tcleval() block fails (the block becomes "?"), so both are grepped for; its
# exit status is 10 whenever a lab_pin net touches only one pin, which a
# testbench always has, so a written, non-empty deck is the success criterion.
build/test_clk_gen.spice: test_clk_gen.sch $(SCH)
	@mkdir -p build
	@rm -f $@
	-$(XSCHEM) -q -n -o build -N test_clk_gen.spice $<
	@test -s $@ || { echo "ERROR: xschem wrote no $@"; exit 1; }
	@! grep -q "IS MISSING" $@ || \
	  { echo "ERROR: unresolved symbols in $@"; exit 1; }
	@! grep -qxF "?" $@ || \
	  { echo "ERROR: a tcleval() block in test_clk_gen.sch failed -- xschem replaces"; \
	    echo "       the whole block with '?' and still exits 0. Is MSDB_ROOT set?"; \
	    exit 1; }
	@grep -q "mk dco_decode.spice rc=0" $@ || \
	  { echo "ERROR: regenerating simulations/dco_decode.spice failed --"; \
	    echo "       see build/mk_dco_decode.log"; exit 1; }

test_clk_gen: build/test_clk_gen.spice simulations/dco_decode.spice
	ngspice -b build/test_clk_gen.spice > build/test_clk_gen.log 2>&1

sim: char

# --- hardening -------------------------------------------------------------

harden: $(SYNTH)/clk_gen.flat.v
	$(NIX_SHELL) librelane pnr/config.yaml

# The same block on SG13CMOS5L: netlist_cmos5l, harden_cmos5l.
TOP := clk_gen
include $(ROOT)/common/pnr/cmos5l.mk

clean:
	@rm -rf build
