# SG13CMOS5L hardening of a block -- included by each block's Makefile, which
# defines TOP, SYNTH, ROOT, PDK_ROOT and NIX_SHELL first.
#
#   $(SYNTH)/$(TOP).flat.v  --retarget.py-->  build/sg13cmos5l/$(TOP).flat.v
#   that  --librelane pnr/config.yaml-->      pnr/runs/CMOS5L_<date>/final/
#
# Everything up to the flat netlist is sg13g2 and shared with `make harden`:
# SG13CMOS5L's standard cells are sg13g2's under another prefix (same models,
# LEF, CDL and Liberty), so retarget.py only renames them and the LEC-proven
# mapping carries over. pnr/config.yaml's "pdk::ihp-sg13cmos5l" section holds
# what differs. Run tags start with CMOS5L_ so that the root Makefile's
# `macros` (RUN_*) and `macros_cmos5l` (CMOS5L_*) each find their own runs.
#
# --manual-pdk: ciel does not provide ihp-sg13cmos5l. The PDK root is
# $(CMOS5L_PDK_ROOT), which common/pnr/cmos5l_pdk.sh builds from $(PDK_ROOT):
# the installed PDK, except a LibreLane config from before IHP-Open-PDK
# 23854a19 (that commit adopted names no released LibreLane reads yet; see the
# script). LIBRELANE_FLAGS passes anything else.

CMOS5L_PDK      := ihp-sg13cmos5l
CMOS5L          := build/sg13cmos5l
CMOS5L_PDK_ROOT := $(abspath $(ROOT))/build/pdk_cmos5l
LIBRELANE_FLAGS ?=

$(CMOS5L_PDK_ROOT)/.stamp: $(ROOT)/common/pnr/cmos5l_pdk.sh
	PDK_ROOT=$(PDK_ROOT) $< $(CMOS5L_PDK_ROOT)

.PHONY: netlist_cmos5l harden_cmos5l

$(CMOS5L)/$(TOP).flat.v: $(SYNTH)/$(TOP).flat.v $(ROOT)/common/pnr/retarget.py
	$(ROOT)/common/pnr/retarget.py --check --pdk-root $(PDK_ROOT) --to sg13cmos5l $< $@

netlist_cmos5l: $(CMOS5L)/$(TOP).flat.v

harden_cmos5l: $(CMOS5L)/$(TOP).flat.v $(CMOS5L_PDK_ROOT)/.stamp
	$(NIX_SHELL) librelane --manual-pdk --pdk-root $(CMOS5L_PDK_ROOT) --pdk $(CMOS5L_PDK) \
	  --run-tag CMOS5L_$$(date +%Y-%m-%d_%H-%M-%S) $(LIBRELANE_FLAGS) pnr/config.yaml
