# lock_ctrl -- coarse-acquisition controller: TDC reading -> DCO code jump,
# then hand over to the bang-bang loop. See rtl/lock_ctrl.v.
#
# Pure RTL block, hardened on its own from the mapped netlist so that the
# placed cells are the LEC-proven ones and its post-PnR clock-to-output delays
# can be handed to the mixed-signal MDLL run (root `make mdll_mixed_sim`).
#
#   rtl/lock_ctrl.v --yosys--> build/01-synth/lock_ctrl.v       mapped, LEC-proven
#   that            --python-> simulations/lock_ctrl.spice      structural subckt
#   that            --yosys--> build/01-synth/lock_ctrl.flat.v  P&R netlist
#   that            --librelane-> pnr/runs/<tag>/final/
#   final run       --sta----> simulations/output_delays.json   tco per output

PDK_ROOT ?= /opt/IHP-Open-PDK/
PDK      := ihp-sg13g2
# The flow tools (librelane, sta, openroad, klayout, magic) come from PATH --
# the nix profile. To run them from a librelane checkout's dev shell instead:
#   make harden NIX_SHELL="nix develop ~/Documents/Passionate/librelane -c"
NIX_SHELL ?=

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)

export PDK_ROOT
export PDK

SYNTH := build/01-synth

.PHONY: all synth lec formal lint sim_acq sim_variants netlist harden delays clean

all: synth

$(SYNTH)/lock_ctrl.v: rtl/lock_ctrl.v synth/synth_lock_ctrl.tcl
	@mkdir -p $(SYNTH)
	yosys -q -c synth/synth_lock_ctrl.tcl -l build/synth_lock_ctrl.log

synth: $(SYNTH)/lock_ctrl.v

# SAT equivalence of the mapped netlist against the RTL.
lec: $(SYNTH)/lock_ctrl.v
	yosys -q -c synth/lec_lock_ctrl.tcl -l build/lec_lock_ctrl.log
	@grep -q "SUCCESS" build/lec_lock_ctrl.log && echo "LEC: PASS"

# Bounded model check of the handover/direction properties.
formal: rtl/lock_ctrl.v synth/props_lock_ctrl.v $(ROOT)/bbpd/rtl/dlf.v
	@mkdir -p build
	yosys -q -c synth/props_lock_ctrl.tcl -l build/props_lock_ctrl.log
	@grep -q "SUCCESS" build/props_lock_ctrl.log && echo "FORMAL: PASS"

lint:
	verilator --lint-only -Wall rtl/lock_ctrl.v

# Behavioural acquisition: the real lock_ctrl + dlf RTL against event-level
# clk_gen/pd/TDC models (simul/tb_acq.v), swept over what the models only know
# approximately -- PVT scale of the DCO and the TDC rings together, TDC LSB
# (i.e. R mismatch against the RTL parameter), injection delay and t_buf --
# plus a TDC over-reporting by 60 %, which forces coarse overshoot onto the
# slow side and so exercises arming-on-injection and the recovery from there.
# Milliseconds per run; the transistor-level closed loop is the root test_mdll.
ACQ_BIN := build/obj_tb_acq/tb_acq

$(ACQ_BIN): simul/tb_acq.v simul/dco_period.vh rtl/lock_ctrl.v $(ROOT)/bbpd/rtl/dlf.v
	@mkdir -p build
	verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style --top-module tb_acq \
	  -Isimul -Mdir build/obj_tb_acq -o tb_acq \
	  simul/tb_acq.v rtl/lock_ctrl.v $(ROOT)/bbpd/rtl/dlf.v > build/verilate_acq.log

# Snapshot of clk_gen's DCO characterisation, tracked so sim_acq does not need
# the ~15 min sweep. Not a dependency: refresh it deliberately after
# `make -C ../clk_gen char`, with `make -B simul/dco_period.vh`.
simul/dco_period.vh:
	python3 -c 'import sys; r=[l.split() for l in open(sys.argv[1])][1:]; \
	  assert len(r)==64, "need 64 codes"; \
	  print("// DCO period per 6-bit code (code[7:2]), in ps, tt / 1.2 V / 27 C.\n" \
	        "// Snapshot of clk_gen/build/char/dco_char.csv (make -C clk_gen char);\n" \
	        "// regenerate with `make -C lock_ctrl -B simul/dco_period.vh` after re-running it.\n" \
	        "// Included inside tb_acq\x27s DCO model; indexed by code[7:2].\n" + \
	        "\n".join(f"    t_dco[{i}] = {round(1e12/float(f))};" for i,(c,f) in enumerate(r)))' \
	  $(ROOT)/clk_gen/build/char/dco_char.csv > $@

# The loop as built. bbpd (src/pd.sch, rtl/dlf.v): x2 retimes 0.42 ns and dlf
# updates 1.2 ns after clk_ref, and the code reaches clk_gen's cap bank ~1.3 ns
# after that (Gray -> binary, routing, decoder) -- in ps at tt, scaled with
# DCO_PCT like the delay cells they are made of. clk_gen dithers code[1:0]
# over the last k periods of a run (rtl/dco_decode.v): +DITHER=2.
ACQ_TIMING = +DITHER=2 +D_X2=$$((420*pct/100)) +D_DLF=$$((1200*pct/100)) +D_CODE=$$((1300*pct/100))

sim_acq: $(ACQ_BIN)
	@for pct in 80 100 125; do ts=$$((1064*pct/100)); \
	  for lsb in 14 17 21; do tf=$$((ts - lsb*pct/100)); \
	    for dinj in 200 330 500; do for tbuf in 30 60 150 300; do for tdc in 100 160; do \
	      $(ACQ_BIN) +DCO_PCT=$$pct +T_S=$$ts +T_F=$$tf +D_INJ=$$dinj +T_BUF=$$tbuf \
	        +TDC_PCT=$$tdc $(ACQ_TIMING) | grep -E "^(PASS|FAIL|NOTE)"; \
	done; done; done; done; done > build/sim_acq.txt
	@echo "$$(grep -c ^PASS build/sim_acq.txt) pass, $$(grep -c "^FAIL: D_INJ" build/sim_acq.txt) fail, $$(grep -c ^NOTE build/sim_acq.txt) dither notes -- build/sim_acq.txt"
	@! grep -q ^FAIL build/sim_acq.txt

# Loop variants (dither, dlf update time, out-of-lock restart) and fault
# injection on tb_acq: see the header of simul/sweep_variants.py.
sim_variants: $(ACQ_BIN)
	simul/sweep_variants.py | tee build/sweep_variants.txt
	simul/sweep_variants.py --faults | tee build/sweep_faults.txt

# Structural translation of the mapped netlist. Port order is the pin order
# of src/lock_ctrl.sym.
simulations/lock_ctrl.spice: $(ROOT)/common/sim/gen_rtl_spice.py $(SYNTH)/lock_ctrl.v
	$(ROOT)/common/sim/gen_rtl_spice.py --module lock_ctrl --nl $(SYNTH)/lock_ctrl.v \
	  --ports clk resetb inj busy hit 'tdc_s[7:0]' 'tdc_f[7:0]' 'code[7:0]' \
	          start sel load 'seed[7:0]' locked \
	  --title "coarse-acquisition controller (TDC -> DCO code)" -o $@

# --- hardening -------------------------------------------------------------

$(SYNTH)/lock_ctrl.flat.v: pnr/prep_netlist.tcl $(SYNTH)/lock_ctrl.v
	yosys -q -c pnr/prep_netlist.tcl -l build/prep_netlist.log

netlist: $(SYNTH)/lock_ctrl.flat.v

harden: $(SYNTH)/lock_ctrl.flat.v
	$(NIX_SHELL) librelane pnr/config.yaml

# The same block on SG13CMOS5L: netlist_cmos5l, harden_cmos5l.
TOP := lock_ctrl
include $(ROOT)/common/pnr/cmos5l.mk

# Clock-to-output delay of every output port at the three signoff corners,
# from the latest run's post-PnR STA. Tracked: the mixed-signal MDLL deck reads
# it, and it should only change when the block is re-hardened.
delays:
	$(NIX_SHELL) $(ROOT)/common/pnr/output_delays.py \
	  $$(ls -d pnr/runs/RUN_* | tail -1) simulations/output_delays.json

clean:
	@rm -rf build
