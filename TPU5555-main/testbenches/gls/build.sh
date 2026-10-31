#!/bin/bash
# Build the Verilator models for the SPI-level testbench tb_hdc_word40_gate.v.
#
#   ./build.sh gate   post-layout: routed netlist TPU5555 (PlaceAndRoute/netlist is the
#                     powered variant; this uses the unpowered synthesis/netlist/TPU5555.nl.v
#                     written after routing) + PDK Verilog models, behind chip_wrapper.v
#   ./build.sh rtl    reference: the RTL core hdc_word40_top (VHDL, ../../rtl) converted
#                     to Verilog with GHDL + Yosys (prep, no technology mapping)
#
# Run:  build/<model>/Vtb_hdc_word40_gate +TRAIN_PER_CLASS=0 +TEST_PER_CLASS=0 +PRED_FILE=pred_<model>.txt
# Needs: verilator >= 5 (with --timing), a C++20 compiler (GCC >= 10), yosys with the ghdl
# plugin (rtl only), the IHP Open PDK.
# Env: PDK_ROOT, THREADS (multithreaded model, e.g. THREADS=8; output in build/<model>_t<n>),
#      JOBS (parallel C++ compile jobs), EXTRA_VFLAGS (e.g. +define+PROGRESS).
#
# Simulation is functional (zero delay): Verilator ignores the specify blocks of the
# cell models, so timing is covered by STA, not by this simulation.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
MAIN=$(cd "$HERE/../.." && pwd)
PDK_ROOT=${PDK_ROOT:-/opt/IHP-Open-PDK}
P=$PDK_ROOT/ihp-sg13cmos5l/libs.ref
# SG13CMOS5L ships the SRAM wrappers without their shared core model; the
# SG13G2 core model of the same macro family is used.
SRAM_CORE=${SRAM_CORE:-$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_sram/verilog/RM_IHPSG13_1P_core_behavioral_bm_bist.v}
JOBS=${JOBS:-$(nproc)}
MODEL=${1:?usage: build.sh gate|rtl}
THREADS=${THREADS:-}
OUT=$HERE/build/$MODEL${THREADS:+_t$THREADS}
mkdir -p "$OUT"

VFLAGS=(--binary --timing -j "$JOBS" --top-module tb_hdc_word40_gate
        -Wno-fatal -Wno-lint -Wno-style -Wno-SPECIFYIGN
        -O3 --x-assign unique --x-initial unique ${EXTRA_VFLAGS:-}
        "+define+DATA_DIR=\"$HERE/data/\"" --Mdir "$OUT"
        ${THREADS:+--threads "$THREADS"})

case "$MODEL" in
gate)
    # The PDK flop models only work with timing checks, which Verilator ignores;
    # generate a functional copy (see the script). The SRAM wrappers have the same
    # issue in their default branch, so their FUNCTIONAL view is used (the SRAM core
    # model already updates its output with a nonblocking assignment).
    python3 "$HERE/functional_stdcells.py" "$P/sg13cmos5l_stdcell/verilog/sg13cmos5l_stdcell.v" \
        "$OUT/sg13cmos5l_stdcell_functional.v"
    verilator "${VFLAGS[@]}" +define+FUNCTIONAL \
        "$P/sg13cmos5l_stdcell/verilog/sg13cmos5l_udp.v" \
        "$OUT/sg13cmos5l_stdcell_functional.v" \
        "$P/sg13cmos5l_io/verilog/sg13cmos5l_io.v" \
        "$SRAM_CORE" \
        "$P"/sg13cmos5l_sram/verilog/RM_IHPSG13_1P_{1024x16,1024x32,1024x8,256x48}_c2_bm_bist.v \
        "$MAIN/synthesis/netlist/TPU5555.nl.v" \
        "$HERE/chip_wrapper.v" "$HERE/tb_hdc_word40_gate.v"
    ;;
rtl)
    R=$MAIN/rtl
    yosys -q -m ghdl -p "ghdl --std=08 $R/spi_slave.vhdl $R/hdc_spi_loader.vhdl $R/IdentityMemory.vhdl \
        $R/ContinuousMemory.vhdl $R/AssociativeMemory.vhdl $R/ClassCounterRAM.vhdl $R/Accelerator.vhdl \
        $R/hdc_cmd_loader.vhdl $R/hdc_word40_top.vhdl -e hdc_word40_top; \
        prep -top hdc_word40_top; write_verilog -noattr $OUT/hdc_word40_top_rtl.v"
    verilator "${VFLAGS[@]}" "$OUT/hdc_word40_top_rtl.v" "$HERE/tb_hdc_word40_gate.v"
    ;;
*)
    echo "usage: build.sh gate|rtl" >&2; exit 1 ;;
esac
echo "built $OUT/Vtb_hdc_word40_gate"
