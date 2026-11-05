# tdc -- Vernier time-to-digital converter for the MDLL's fast-lock path.
#
# Flow (all outputs under build/, gitignored):
#
#   src/*.sch + sub-blocks --xschem-->  build/01-synth/tdc.nl.v     hierarchy
#   counter/src/counter.v   --yosys-->  build/01-synth/counter.v    mapped gates
#   both                    --python->  build/01-synth/tdc.pnr.v    stripped
#   that                    --yosys-->  build/01-synth/tdc.flat.v   flat
#   that                    --librelane-> pnr/runs/<tag>/final/     GDS
#
# The split exists so LibreLane can run with SYNTH_ELABORATE_ONLY and never
# re-optimise the hand-drawn rings, edge-lock detector and phase detector --
# see common/pnr/mk_netlist.py.

PDK_ROOT ?= /opt/IHP-Open-PDK/
PDK      := ihp-sg13g2
# The flow tools (librelane, sta, openroad, klayout, magic) come from PATH --
# the nix profile. To run them from a librelane checkout's dev shell instead:
#   make harden NIX_SHELL="nix develop ~/Documents/Passionate/librelane -c"
NIX_SHELL ?=

ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
XSCHEM := $(ROOT)/tools/xschem

export PDK_ROOT
export PDK

SYNTH := build/01-synth

# Every schematic and symbol the TDC is drawn from.
SCH := src/tdc.sch src/tdc.sym src/tdc_pd.sch src/tdc_pd.sym \
       osci/src/slow_osci.sch osci/src/fast_osci.sch \
       osci/src/slow_osci.sym osci/src/fast_osci.sym \
       edge_lock/edge_lock_dector.sch edge_lock/edge_lock_dector.sym \
       counter/src/counter.sym

.PHONY: all harden netlist synth lec sim_rtl osci_sim tdc_sim sim clean

all: netlist

# --- synthesis of the counter ----------------------------------------------

$(SYNTH)/counter.v: counter/src/counter.v synth/synth_counter.tcl
	@mkdir -p $(SYNTH)
	yosys -q -c synth/synth_counter.tcl -l build/synth_counter.log

synth: $(SYNTH)/counter.v

# SAT equivalence of the mapped counter against its RTL, over a full wrap.
lec: $(SYNTH)/counter.v
	yosys -q -c synth/lec_counter.tcl -l build/lec_counter.log
	@grep -q "SUCCESS" build/lec_counter.log && echo "LEC: PASS"

# Self-checking RTL testbench: reset, increment over a full wrap, async clear.
sim_rtl: counter/src/counter.v counter/simul/tb_counter.v
	@mkdir -p build
	verilator --binary --timing -Wno-fatal --top-module tb_counter \
	  -Mdir build/obj_tb_counter -o tb_counter $^ > build/verilate_counter.log
	build/obj_tb_counter/tb_counter | tee build/sim_rtl.log
	@grep -q "^PASS: counter" build/sim_rtl.log

# --- netlist assembly for P&R ----------------------------------------------

$(SYNTH)/tdc.nl.v: $(SCH)
	@mkdir -p $(SYNTH)
	$(XSCHEM) -q -n -w -o $(SYNTH) -N tdc.nl.v src/tdc.sch

$(SYNTH)/tdc.pnr.v: $(ROOT)/common/pnr/mk_netlist.py $(SYNTH)/tdc.nl.v $(SYNTH)/counter.v
	$(ROOT)/common/pnr/mk_netlist.py --top tdc \
	  --keep tdc tdc_pd edge_lock_dector slow_osci fast_osci \
	  --nl $(SYNTH)/tdc.nl.v --append $(SYNTH)/counter.v --out $@

$(SYNTH)/tdc.flat.v: pnr/prep_netlist.tcl $(SYNTH)/tdc.pnr.v
	yosys -q -c pnr/prep_netlist.tcl

netlist: $(SYNTH)/tdc.flat.v

# --- simulation --------------------------------------------------------------

# Structural translation of the synthesised counter. counter.sym passes the
# supplies explicitly, hence --supply-ports.
simulations/counter.spice: $(ROOT)/common/sim/gen_rtl_spice.py $(SYNTH)/counter.v
	$(ROOT)/common/sim/gen_rtl_spice.py --module counter --nl $(SYNTH)/counter.v \
	  --ports 'count[7:0]' clk rst_n --supply-ports \
	  --title "8-bit synchronous binary counter (Vernier TDC)" -o $@

# The whole TDC as one subckt hierarchy, for the characterisation decks.
$(SYNTH)/tdc.spice: $(SCH)
	@mkdir -p $(SYNTH)
	$(XSCHEM) -q -n -o $(SYNTH) -N tdc.spice src/tdc.sch
	@! grep -q "IS MISSING" $@ || { echo "ERROR: unresolved symbols in $@"; exit 1; }

# Ring period and Vernier resolution at ss/tt/ff.
osci_sim: $(SYNTH)/tdc.spice
	./simulations/char_osci.py

# Transfer curve: captured counts vs. the clk_out-to-clk_ref interval.
tdc_sim: build/test_tdc.spice simulations/counter.spice
	./simulations/char_tdc.py

# The xschem testbench, netlisted and run exactly as the Simulate button would.
# xschem exits 0 both when it cannot resolve a symbol ("IS MISSING") and when a
# tcleval() block fails (the block becomes "?"), so both are grepped for.
#
# The exit status is not usable for this sheet either: xschem 3.4.7 exits 10
# whenever a lab_pin net touches only one pin, and in a testbench that is every
# net driven from the SPICE code block (Clk_out, Sel, ...) and every observed
# output. The netlist it writes is complete regardless. So a written, non-empty
# deck is the success criterion, and the greps decide. (For the design
# schematics a nonzero exit is still meaningful -- it caught a ring whose
# feedback label pointed at a net nothing drove -- so those rules keep it.)
build/test_tdc.spice: test_tdc.sch $(SCH)
	@mkdir -p build
	@rm -f $@
	-$(XSCHEM) -q -n -o build -N test_tdc.spice $<
	@test -s $@ || { echo "ERROR: xschem wrote no $@"; exit 1; }
	@! grep -q "IS MISSING" $@ || \
	  { echo "ERROR: unresolved symbols in $@"; exit 1; }
	@! grep -qxF "?" $@ || \
	  { echo "ERROR: a tcleval() block in test_tdc.sch failed -- xschem replaces"; \
	    echo "       the whole block with '?' and still exits 0. Is MSDB_ROOT set?"; \
	    exit 1; }
	@grep -q "mk counter.spice rc=0" $@ || \
	  { echo "ERROR: regenerating simulations/counter.spice failed --"; \
	    echo "       see build/mk_counter.log"; exit 1; }

test_tdc: build/test_tdc.spice simulations/counter.spice
	ngspice -b build/test_tdc.spice > build/test_tdc.log 2>&1

sim: osci_sim tdc_sim

# --- hardening -------------------------------------------------------------

harden: $(SYNTH)/tdc.flat.v
	$(NIX_SHELL) librelane pnr/config.yaml

# The same block on SG13CMOS5L: netlist_cmos5l, harden_cmos5l.
TOP := tdc
include $(ROOT)/common/pnr/cmos5l.mk

clean:
	@rm -rf build
