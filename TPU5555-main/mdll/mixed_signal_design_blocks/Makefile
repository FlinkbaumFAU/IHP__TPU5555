# MDLL top level. The blocks live in their own directories (clk_gen/, tdc/,
# bbpd/, lock_ctrl/), each with its own Makefile; this one integrates them.
#
#   mdll.sch          clk_gen + tdc + bbpd (pd, dlf) + lock_ctrl
#   test_mdll.sch     closed loop from reset to lock   -> make mdll_sim
#   test_acq.sch      open loop, fixed code, clk_gen -> TDC timing
#                                                      -> make acq_char
#
# The top level hardens as a macro of macros (pnr/config.yaml): `make
# macros harden` after each block's own `make netlist harden`. No pads.

PDK_ROOT ?= /opt/IHP-Open-PDK/
PDK      := ihp-sg13g2

ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
XSCHEM := $(ROOT)/tools/xschem

# The flow tools come from PATH (the nix profile); see the blocks' Makefiles.
NIX_SHELL ?=

export PDK_ROOT
export PDK

# Every schematic and symbol the top level is drawn from.
SCH := mdll.sch mdll.sym \
       clk_gen/clk_gen.sch clk_gen/clk_gen.sym $(wildcard clk_gen/src/*.sch clk_gen/src/*.sym) \
       $(wildcard tdc/src/*.sch tdc/src/*.sym tdc/osci/src/*.sch tdc/osci/src/*.sym) \
       $(wildcard tdc/edge_lock/*.sch tdc/edge_lock/*.sym) tdc/counter/src/counter.sym \
       $(wildcard bbpd/src/*.sch bbpd/src/*.sym) lock_ctrl/src/lock_ctrl.sym

.PHONY: all models mdll_sim mdll_mixed_sim acq_char sim netlist macros harden match_report clean \
        netlist_cmos5l macros_cmos5l harden_cmos5l match_report_cmos5l

all: build/test_mdll.spice

# The generated SPICE models of synthesised RTL. Their rules live in the
# blocks; this only delegates, so there is one place each is built from.
models:
	$(MAKE) -s -C clk_gen   simulations/dco_decode.spice
	$(MAKE) -s -C bbpd      simulations/dlf.spice
	$(MAKE) -s -C tdc       simulations/counter.spice
	$(MAKE) -s -C lock_ctrl simulations/lock_ctrl.spice

# Testbench netlisting, judged by the file and the greps, not xschem's exit
# status (10 whenever a lab_pin net touches only one pin -- see CLAUDE.md).
# The tcleval() header rebuilds the models itself and prints each make's
# return code, so a failed rebuild cannot hide behind a stale model.
define netlist_tb
	@mkdir -p build
	@rm -f $@
	-$(XSCHEM) -q -n -o build -N $(notdir $@) $<
	@test -s $@ || { echo "ERROR: xschem wrote no $@"; exit 1; }
	@! grep -q "IS MISSING" $@ || { echo "ERROR: unresolved symbols in $@"; exit 1; }
	@! grep -qxF "?" $@ || \
	  { echo "ERROR: a tcleval() block in $< failed -- xschem replaces the whole"; \
	    echo "       block with '?' and still exits 0. Is MSDB_ROOT set?"; exit 1; }
	@! grep -E "^\* mk [a-z_]+\.spice rc=" $@ | grep -v "rc=0" || \
	  { echo "ERROR: regenerating a model failed -- see build/mk_*.log"; exit 1; }
endef

build/test_mdll.spice: test_mdll.sch $(SCH)
	$(netlist_tb)

build/test_acq.spice: test_acq.sch $(SCH)
	$(netlist_tb)

# Closed loop, transistor level: reset -> coarse acquisition -> handover ->
# bang-bang. Hours, not minutes; lock_ctrl's `make sim_acq` checks the same
# loop logic behaviourally in milliseconds.
mdll_sim: build/test_mdll.spice models
	rm -f simulations/test_mdll.raw
	ngspice -b build/test_mdll.spice > build/test_mdll.log 2>&1
	./simulations/check_mdll.py

# Same closed loop, same stimulus and acceptance gate, with lock_ctrl and dlf
# running as RTL in Verilator (XSPICE d_cosim) and their outputs delayed by the
# hardened blocks' post-PnR STA clock-to-output times -- see
# simulations/gen_mixed.py for what that does and does not model. Several times
# faster; the transistor-level mdll_sim stays the reference.
# CORNER=slow|fast picks the STA delays and the matching SPICE corner (ss at
# 1.08 V / 125 C, ff at 1.32 V / -40 C); SPICE_CORNER=typ|slow|fast overrides
# the latter, e.g. to see the delays alone.
# ngspice-45 can abort in teardown after unloading a d_cosim library, AFTER the
# raw file is written, so its exit status is ignored and check_mdll.py decides.
# That makes the old raw file dangerous: a run that fails outright (e.g. no
# operating point) writes nothing, and the checker would grade the previous
# run's waveforms. It is deleted first.
CORNER ?= typ
SPICE_CORNER ?= $(CORNER)
mdll_mixed_sim: build/test_mdll.spice models \
                lock_ctrl/simulations/output_delays.json bbpd/simulations/output_delays.json
	./simulations/gen_mixed.py --corner $(CORNER) --spice-corner $(SPICE_CORNER)
	rm -f simulations/test_mdll_mixed.raw
	-ngspice -b build/test_mdll_mixed.spice > build/test_mdll_mixed.log 2>&1
	./simulations/check_mdll.py --raw simulations/test_mdll_mixed.raw

# What the TDC measures when wired to clk_gen, over a set of fixed codes.
acq_char: build/test_acq.spice models
	./simulations/char_acq.py

sim: mdll_sim

# --- top-level macro ---------------------------------------------------------
#
#   mdll.sch  --xschem -w-->       build/01-synth/mdll.nl.v    blocks as instances
#   that      --mk_netlist.py-->   build/01-synth/mdll.pnr.v   block bodies dropped
#   that      --prep_netlist.tcl-> build/01-synth/mdll.flat.v  macros as blackboxes
#   that + build/macros/ --librelane pnr/config.yaml--> pnr/runs/<tag>/final/
#
# mdll.sch is a design schematic: unused outputs end in noconn, so xschem's
# exit status is meaningful here (unlike for the testbenches).
BLOCKS := clk_gen tdc bbpd lock_ctrl

build/01-synth/mdll.nl.v: $(SCH)
	@mkdir -p build/01-synth
	$(XSCHEM) -q -n -w -o build/01-synth -N mdll.nl.v mdll.sch

build/01-synth/mdll.pnr.v: common/pnr/mk_netlist.py build/01-synth/mdll.nl.v
	common/pnr/mk_netlist.py --top mdll --keep mdll \
	  --nl build/01-synth/mdll.nl.v --out $@

build/01-synth/mdll.flat.v: pnr/prep_netlist.tcl build/01-synth/mdll.pnr.v build/macros/RUNS.txt
	MACRO_DIR=build/macros FLAT=$@ yosys -q -c pnr/prep_netlist.tcl -l build/prep_netlist.log

netlist: build/01-synth/mdll.flat.v

# Each block's latest hardened views, copied so pnr/config.yaml has fixed
# paths. RUNS.txt records the run tags; it is rewritten only when one changes.
# $(1): run-tag prefix (RUN for sg13g2, CMOS5L), $(2): destination.
define copy_macros
	@mkdir -p $(2)
	@for b in $(BLOCKS); do echo "$$b $$(ls -d $$b/pnr/runs/$(1)_* | tail -1)"; done \
	  > $(2)/RUNS.new
	@if ! cmp -s $(2)/RUNS.new $(2)/RUNS.txt; then \
	  while read b r; do \
	    test -f $$r/final/gds/$$b.gds || { echo "ERROR: $$b: no $(1)_* run with a final GDS"; exit 1; }; \
	    rm -rf $(2)/$$b; mkdir -p $(2)/$$b; \
	    cp -r $$r/final/gds $$r/final/nl $$r/final/pnl $$r/final/vh \
	          $$r/final/lib $$r/final/spef $$r/final/spice $$r/final/cdl $(2)/$$b/; \
	    mkdir -p $(2)/$$b/lef; \
	    ODB=$$r/final/odb/$$b.odb LEF=$(2)/$$b/lef/$$b.lef \
	      $(NIX_SHELL) openroad -exit -no_splash common/pnr/write_lef.tcl \
	      < /dev/null > $(2)/$$b/lef/write_lef.log 2>&1 \
	      || { echo "ERROR: $$b: write_lef.tcl failed, see $(2)/$$b/lef/write_lef.log"; exit 1; }; \
	    common/pnr/grow_obs.py $(2)/$$b/lef/$$b.lef >> $(2)/$$b/lef/write_lef.log || exit 1; \
	  done < $(2)/RUNS.new; \
	  mv $(2)/RUNS.new $(2)/RUNS.txt; \
	else rm $(2)/RUNS.new; fi
	@cat $(2)/RUNS.txt
endef

macros:
	$(call copy_macros,RUN,build/macros)

build/macros/RUNS.txt: macros

harden: macros build/01-synth/mdll.flat.v
	$(NIX_SHELL) librelane pnr/config.yaml

# --- the same top level on SG13CMOS5L ----------------------------------------
#
# From each block's latest CMOS5L_* run (`make -C <block> harden_cmos5l`, see
# common/pnr/cmos5l.mk) and the same netlist with its cells renamed; what
# differs in P&R is pnr/config.yaml's "pdk::ihp-sg13cmos5l" section.
CMOS5L := build/sg13cmos5l
LIBRELANE_FLAGS ?=

macros_cmos5l:
	$(call copy_macros,CMOS5L,$(CMOS5L)/macros)

$(CMOS5L)/macros/RUNS.txt: macros_cmos5l

$(CMOS5L)/mdll.sg13g2.v: pnr/prep_netlist.tcl build/01-synth/mdll.pnr.v $(CMOS5L)/macros/RUNS.txt
	MACRO_DIR=$(CMOS5L)/macros FLAT=$@ yosys -q -c pnr/prep_netlist.tcl -l $(CMOS5L)/prep_netlist.log

$(CMOS5L)/mdll.flat.v: $(CMOS5L)/mdll.sg13g2.v common/pnr/retarget.py
	common/pnr/retarget.py --check --pdk-root $(PDK_ROOT) --to sg13cmos5l $< $@

netlist_cmos5l: $(CMOS5L)/mdll.flat.v

# The PDK root is build/pdk_cmos5l, as for the blocks (common/pnr/cmos5l.mk,
# common/pnr/cmos5l_pdk.sh): the installed PDK with a LibreLane config that
# LibreLane 3.0.16 can read.
CMOS5L_PDK_ROOT := $(abspath build/pdk_cmos5l)
$(CMOS5L_PDK_ROOT)/.stamp: common/pnr/cmos5l_pdk.sh
	PDK_ROOT=$(PDK_ROOT) $< $(CMOS5L_PDK_ROOT)

harden_cmos5l: macros_cmos5l $(CMOS5L)/mdll.flat.v $(CMOS5L_PDK_ROOT)/.stamp
	$(NIX_SHELL) librelane --manual-pdk --pdk-root $(CMOS5L_PDK_ROOT) --pdk ihp-sg13cmos5l \
	  --run-tag CMOS5L_$$(date +%Y-%m-%d_%H-%M-%S) $(LIBRELANE_FLAGS) pnr/config.yaml

# div vs. clk_ref_g arrival at the tdc and bbpd pins, latest run, all corners.
match_report:
	$(NIX_SHELL) ./pnr/match_report.py

match_report_cmos5l:
	$(NIX_SHELL) ./pnr/match_report.py --cmos5l

# --- the hardened top level, checked and simulated from its layout -----------
#
#   pnr/runs/<latest RUN_*>/final/cdl + build/macros/*/cdl + custom_stdcell.cdl
#       + the PDK's stdcell CDL  --gen_layout_tb.py cdl--> build/layout/mdll_full.cdl
#   final/gds/mdll.gds vs. that  --run_lvs.py-->  build/layout/lvs/
#                                (mdll.lvsdb, mdll_extracted.cir: transistors, no RC)
#   build/test_mdll.spice + those --gen_layout_tb.py tb--> build/layout/test_mdll_layout.spice
#
# lvs_full is independent of LibreLane's KLayout.LVS step: the CDL is our own
# concatenation (LibreLane 3.0.16's lost its tail, see CLAUDE.md) and checked
# complete, and the PDK's run_lvs.py runs on the merged GDS as is. run_lvs.py
# imports the klayout Python package, which the nix profile lacks, and only
# uses it to find the top cell; --topcell plus a stub package does without.
#
# layout_sim is mdll_sim with x1 replaced by the extracted netlist; its
# internal nets carry the schematic's names (from the LVS cross-reference), so
# the save list and check_mdll.py are unchanged. Hours, like mdll_sim.
# TOP_RUN picks another top-level run.
TOP_RUN ?= $(lastword $(sort $(wildcard pnr/runs/RUN_*)))
LAYOUT  := build/layout
RUN_LVS := $(PDK_ROOT)/$(PDK)/libs.tech/klayout/tech/lvs/run_lvs.py
CUSTOM_CDL ?= $(abspath ../custom_stdcell/custom_stdcell.cdl)

.PHONY: lvs_full layout_sim

lvs_full:
	@test -f $(TOP_RUN)/final/gds/mdll.gds || { echo "ERROR: no $(TOP_RUN)/final/gds/mdll.gds"; exit 1; }
	@mkdir -p $(LAYOUT)/pyshim/klayout
	@echo "# stub: run_lvs.py needs klayout.db only without --topcell" \
	  > $(LAYOUT)/pyshim/klayout/__init__.py
	@printf 'class Layout:\n    def __init__(self, *a, **k):\n        raise RuntimeError("stub: pass --topcell")\n' \
	  > $(LAYOUT)/pyshim/klayout/db.py
	./simulations/gen_layout_tb.py cdl --top $(TOP_RUN)/final/cdl/mdll.cdl \
	  --macros build/macros --custom $(CUSTOM_CDL) --out $(LAYOUT)/mdll_full.cdl
	rm -rf $(LAYOUT)/lvs
	PYTHONPATH=$(abspath $(LAYOUT)/pyshim) python3 $(RUN_LVS) \
	  --layout $(TOP_RUN)/final/gds/mdll.gds --netlist $(LAYOUT)/mdll_full.cdl \
	  --topcell mdll --run_dir $(LAYOUT)/lvs --run_mode deep > $(LAYOUT)/lvs.log 2>&1
	@grep -q "Congratulations! Netlists match." $(LAYOUT)/lvs/mdll.log \
	  && echo "lvs_full: $(TOP_RUN): netlists match" \
	  || { echo "ERROR: LVS mismatch, see $(LAYOUT)/lvs/mdll.log"; exit 1; }

# The LVS reference for Calibre: the same CDL without the filler instances
# (Calibre reports each as unmatched; KLayout skips device-less cells).
# calibre_cdl_cmos5l: the CMOS5L layout's, from its own runs and stdcell CDL.
.PHONY: calibre_cdl calibre_cdl_cmos5l
calibre_cdl:
	@mkdir -p $(LAYOUT)
	./simulations/gen_layout_tb.py cdl --no-fill --top $(TOP_RUN)/final/cdl/mdll.cdl \
	  --macros build/macros --custom $(CUSTOM_CDL) --out $(LAYOUT)/mdll_calibre.cdl

TOP_RUN_CMOS5L ?= $(lastword $(sort $(wildcard pnr/runs/CMOS5L_*)))
calibre_cdl_cmos5l:
	@mkdir -p $(CMOS5L)/layout
	./simulations/gen_layout_tb.py cdl --no-fill --top $(TOP_RUN_CMOS5L)/final/cdl/mdll.cdl \
	  --macros $(CMOS5L)/macros --custom $(CUSTOM_CDL) \
	  --stdcell $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell/cdl/sg13cmos5l_stdcell.cdl \
	  --out $(CMOS5L)/layout/mdll_calibre.cdl

# --- the CMOS5L top level as a hard macro for a chip --------------------------
#
# build/sg13cmos5l/ip/mdll/ from TOP_RUN_CMOS5L: GDS, Liberty per corner, CDL
# and netlist as LibreLane wrote them, an abstract LEF (write_lef.tcl +
# grow_obs.py, as for the blocks), cdl/mdll_bb.cdl (the subckt's pins only: a
# chip LVS that compares the MDLL as a black box) and SOURCE.txt (run, commit,
# PDK revision). The hdc chip copies this directory into its asic/ip/mdll/.
IP_CMOS5L := $(CMOS5L)/ip/mdll
.PHONY: ip_cmos5l
ip_cmos5l:
	@test -f $(TOP_RUN_CMOS5L)/final/gds/mdll.gds || { echo "ERROR: no $(TOP_RUN_CMOS5L)/final/gds/mdll.gds"; exit 1; }
	rm -rf $(IP_CMOS5L)
	mkdir -p $(IP_CMOS5L)/lef
	cp -r $(TOP_RUN_CMOS5L)/final/gds $(TOP_RUN_CMOS5L)/final/lib $(TOP_RUN_CMOS5L)/final/cdl \
	  $(TOP_RUN_CMOS5L)/final/nl $(IP_CMOS5L)/
	ODB=$(TOP_RUN_CMOS5L)/final/odb/mdll.odb LEF=$(IP_CMOS5L)/lef/mdll.lef \
	  $(NIX_SHELL) openroad -exit -no_splash common/pnr/write_lef.tcl \
	  < /dev/null > $(IP_CMOS5L)/lef/write_lef.log 2>&1
	common/pnr/grow_obs.py $(IP_CMOS5L)/lef/mdll.lef >> $(IP_CMOS5L)/lef/write_lef.log
	python3 -c 'import re,sys; t=open(sys.argv[1]).read(); \
	  m=re.search(r"^\.SUBCKT mdll\b.*?\n(?!\+)", t, re.M|re.S|re.I); \
	  m or sys.exit("no .SUBCKT mdll"); \
	  print("* mdll pins only (black box), from " + sys.argv[1]); print(m.group(0) + ".ENDS")' \
	  $(IP_CMOS5L)/cdl/mdll.cdl > $(IP_CMOS5L)/cdl/mdll_bb.cdl
	{ echo "run    $(TOP_RUN_CMOS5L)"; \
	  echo "commit $$(git rev-parse --short HEAD)$$(git diff --quiet HEAD || echo ' (dirty)')"; \
	  echo "pdk    $(PDK_ROOT) $$(git -C $(PDK_ROOT) rev-parse --short HEAD 2>/dev/null)"; \
	} > $(IP_CMOS5L)/SOURCE.txt
	@cat $(IP_CMOS5L)/SOURCE.txt

# ngspice's exit status is not trusted (see mdll_mixed_sim); the old raw file
# is deleted first so check_mdll.py cannot grade a previous run.
layout_sim: lvs_full build/test_mdll.spice
	./simulations/gen_layout_tb.py tb --deck build/test_mdll.spice \
	  --extracted $(LAYOUT)/lvs/mdll_extracted.cir --lvsdb $(LAYOUT)/lvs/mdll.lvsdb \
	  --cir $(LAYOUT)/mdll_extracted.spice --out $(LAYOUT)/test_mdll_layout.spice \
	  --raw $(LAYOUT)/test_mdll_layout.raw
	rm -f $(LAYOUT)/test_mdll_layout.raw
	-ngspice -b $(LAYOUT)/test_mdll_layout.spice > $(LAYOUT)/test_mdll_layout.log 2>&1
	./simulations/check_mdll.py --raw $(LAYOUT)/test_mdll_layout.raw

# The closed loop on a Calibre xRC netlist (R+C+CC, SOURCENAMES, ELDO format;
# see TAPEOUT.md for how it was made): make pex_sim PEX=<dir>/mdll.pex.spice.
# PEX_TAG names the run (build/pex/<tag>/), PEX_OPTS passes gen_layout_tb.py
# pex options (--ideal-supply, --tstop), PEX_THREADS ngspice's num_threads,
# PEX_CORNER the SPICE corner (typ|slow|fast, as CORNER for mdll_mixed_sim).
# The deck is used as it is (order-only), so a copied build/test_mdll.spice
# works on a machine without xschem.
PEX_TAG     ?= rc
PEX_OPTS    ?=
PEX_THREADS ?= 8
PEX_CORNER  ?= typ
PEX_RUN     := build/pex/$(PEX_TAG)
.PHONY: pex_sim
pex_sim: | build/test_mdll.spice
	@test -n "$(PEX)" || { echo "ERROR: PEX=<path to mdll.pex.spice>"; exit 1; }
	@mkdir -p $(PEX_RUN)
	./simulations/gen_layout_tb.py pex --deck build/test_mdll.spice --pex $(PEX) \
	  --cir $(PEX_RUN)/mdll_pex.spice --out $(PEX_RUN)/test_mdll_pex.spice \
	  --raw $(PEX_RUN)/test_mdll_pex.raw --threads $(PEX_THREADS) --corner $(PEX_CORNER) $(PEX_OPTS)
	rm -f $(PEX_RUN)/test_mdll_pex.raw
	-ngspice -b $(PEX_RUN)/test_mdll_pex.spice > $(PEX_RUN)/test_mdll_pex.log 2>&1
	./simulations/check_mdll.py --raw $(PEX_RUN)/test_mdll_pex.raw | tee $(PEX_RUN)/check.txt

clean:
	@rm -rf build
