# bbpd -- binary phase comparator + loop-filter accumulator for the MDLL.
#
# Flow (all outputs under build/, gitignored):
#
#   src/*.sch            --xschem-->  build/01-synth/bbpd.nl.v     hierarchy
#   rtl/dlf.v            --yosys-->   build/01-synth/dlf.v         mapped gates
#   both                 --python-->  build/01-synth/bbpd.pnr.v    stripped
#   that                 --yosys-->   build/01-synth/bbpd.flat.v   flat
#   that                 --librelane->pnr/runs/<tag>/final/        GDS
#
# The split exists so LibreLane can run with SYNTH_ELABORATE_ONLY and never
# re-optimise the hand-drawn comparator -- see common/pnr/mk_netlist.py.

PDK_ROOT ?= /opt/IHP-Open-PDK/
PDK      := ihp-sg13g2
# The flow tools (librelane, sta, openroad, klayout, magic) come from PATH --
# the nix profile. To run them from a librelane checkout's dev shell instead:
#   make harden NIX_SHELL="nix develop ~/Documents/Passionate/librelane -c"
NIX_SHELL ?=

# Repo root, discovered from this Makefile's own location -- no absolute paths
# are baked in anywhere, so the checkout stays portable.
ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
# Always netlist through the wrapper. It puts the repo root on
# XSCHEM_LIBRARY_PATH and runs from there, which is what makes root-relative
# symbol references such as clk_gen/src/dco.sym resolve no matter which
# directory you started in. See tools/xschem.
XSCHEM := $(ROOT)/tools/xschem

export PDK_ROOT
export PDK

SYNTH := build/01-synth

.PHONY: meta_char all harden delays netlist synth lec formal pd_sim fine_loop_sim sim clean

all: netlist

# --- netlist assembly ------------------------------------------------------

$(SYNTH)/bbpd.nl.v: src/bbpd.sch src/pd.sch src/pd.sym src/dlf.sym
	@mkdir -p $(SYNTH)
	$(XSCHEM) -q -n -w -o $(SYNTH) -N bbpd.nl.v $<

# check_comp_cone.py: comp may reach the state only through and2 -> xor2,
# which is what makes an unresolved comp harmless (rtl/dlf.v). A netlist that
# breaks it is deleted, so nothing downstream can use it.
$(SYNTH)/dlf.v: rtl/dlf.v synth/synth_dlf.tcl synth/check_comp_cone.py
	@mkdir -p $(SYNTH)
	yosys -c synth/synth_dlf.tcl
	synth/check_comp_cone.py $@ || { rm -f $@; exit 1; }

$(SYNTH)/bbpd.pnr.v: $(ROOT)/common/pnr/mk_netlist.py $(SYNTH)/bbpd.nl.v $(SYNTH)/dlf.v
	$(ROOT)/common/pnr/mk_netlist.py --top bbpd --keep bbpd pd \
	  --nl $(SYNTH)/bbpd.nl.v --append $(SYNTH)/dlf.v --out $@

$(SYNTH)/bbpd.flat.v: pnr/prep_netlist.tcl $(SYNTH)/bbpd.pnr.v
	yosys -c pnr/prep_netlist.tcl

netlist: $(SYNTH)/bbpd.flat.v
synth:   $(SYNTH)/dlf.v

# --- verification ----------------------------------------------------------

# SAT equivalence of the mapped dlf netlist against its RTL.
lec: $(SYNTH)/dlf.v
	yosys -c synth/lec_dlf.tcl

# Bounded model check of the accumulator's properties: saturation, one-LSB
# steps, load priority, direction, reset code.
formal:
	yosys -c synth/props_dlf.tcl

# --- simulation ------------------------------------------------------------

$(SYNTH)/pd.spice: src/pd.sch
	@mkdir -p $(SYNTH)
	$(XSCHEM) -q -n -o $(SYNTH) -N pd.spice $<

# Structural translation of the synthesised accumulator, so the closed-loop
# run exercises the real cells rather than a behavioural stand-in.
simulations/dlf.spice: $(ROOT)/common/sim/gen_rtl_spice.py $(SYNTH)/dlf.v
	$(ROOT)/common/sim/gen_rtl_spice.py --module dlf --nl $(SYNTH)/dlf.v \
	  --ports clk_ref clk resetb comp load 'seed[7:0]' 'code[7:0]' \
	  --title "8-bit saturating bang-bang accumulator (the MDLL loop filter)" -o $@

build/char_pd.spice: simulations/gen_char_pd.py $(SYNTH)/pd.spice
	./simulations/gen_char_pd.py

# Comparator polarity and static offset. One deck, 51 copies of pd at
# different div delays -- ~6 min. gen_char_pd.py --ct/--fine-ps re-runs it at a
# different input slew, which is how the flop's setup time is separated from
# the ramp.
# Clock-to-Q vs. data-to-clock offset of the pd's flops at tt and ss: the
# resolution time constant tau that bounds how soon after clk_ref dlf can use
# comp (~20 min, 8 parallel decks). See the script's header.
meta_char:
	@mkdir -p build
	./simulations/char_meta.py -v > build/char_meta.txt
	@grep -v '^    dt' build/char_meta.txt

pd_sim: build/char_pd.spice
	ngspice -b build/char_pd.spice > build/char_pd.out 2>&1
	./simulations/check_pd.py

# test_fine_loop.sch spans two blocks: it instantiates clk_gen/clk_gen.sym, whose
# own sub-symbols are named relative to the library path. The grep is not
# belt-and-braces -- when xschem cannot resolve a symbol it writes "IS MISSING"
# into an otherwise plausible .subckt and still EXITS 0, which once produced a
# deck with no DUT that simulated to a flat 0.665 V and looked like a dead ring.
build/test_fine_loop.spice: test_fine_loop.sch src/bbpd.sch src/bbpd.sym src/pd.sch src/pd.sym src/dlf.sym \
                       ../clk_gen/clk_gen.sch ../clk_gen/clk_gen.sym \
                       $(wildcard ../clk_gen/src/*.sch ../clk_gen/src/*.sym)
	@mkdir -p build
	$(XSCHEM) -q -n -o build -N test_fine_loop.spice $<
	@! grep -q "IS MISSING" build/test_fine_loop.spice || \
	  { echo "ERROR: unresolved symbols in build/test_fine_loop.spice"; exit 1; }
	@! grep -qxF "?" build/test_fine_loop.spice || \
	  { echo "ERROR: a tcleval() block in test_fine_loop.sch failed -- xschem replaces"; \
	    echo "       the whole block with '?' and still exits 0. Is MSDB_ROOT set?"; \
	    exit 1; }
	@grep -q "mk dlf.spice rc=0" build/test_fine_loop.spice || \
	  { echo "ERROR: regenerating simulations/dlf.spice failed --"; \
	    sed -n "s/^\* mk dlf.spice /       /p" build/test_fine_loop.spice; \
	    echo "       see build/mk_dlf.log"; exit 1; }

# The acceptance gate. The deck is position-independent -- every path in it
# (the two generated includes and the raw output) is made absolute from
# MSDB_ROOT by tcleval() at netlist time -- so it runs the same from here as it
# does from xschem's Simulate button, which uses netlist_dir as its cwd.
fine_loop_sim: build/test_fine_loop.spice simulations/dlf.spice
	rm -f simulations/test_fine_loop.raw
	ngspice -b build/test_fine_loop.spice > build/test_fine_loop.log 2>&1
	./simulations/check_lock.py

sim: pd_sim fine_loop_sim

# --- hardening -------------------------------------------------------------

harden: $(SYNTH)/bbpd.flat.v
	$(NIX_SHELL) librelane pnr/config.yaml

# The same block on SG13CMOS5L: netlist_cmos5l, harden_cmos5l.
TOP := bbpd
include $(ROOT)/common/pnr/cmos5l.mk

# Clock-to-output delay of every output port (C[7:0] is dlf's code) at the
# three signoff corners, from the latest run's post-PnR STA. Tracked: the
# root's mixed-signal MDLL run injects these after its Verilator model of dlf.
# From the launching flop's clock pin: that model is clocked by clk_dlf, after
# pd.sch's delay chain, which the mixed deck simulates at transistor level.
delays:
	$(NIX_SHELL) $(ROOT)/common/pnr/output_delays.py --from-launch-clock \
	  $$(ls -d pnr/runs/RUN_* | tail -1) simulations/output_delays.json

clean:
	@rm -rf build
