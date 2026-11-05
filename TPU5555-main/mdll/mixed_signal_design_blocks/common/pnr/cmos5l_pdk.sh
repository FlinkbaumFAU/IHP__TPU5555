#!/bin/sh
# Build the PDK root the CMOS5L LibreLane runs use: $PDK_ROOT as installed,
# except ihp-sg13cmos5l/libs.tech/librelane, which is taken from an older
# IHP-Open-PDK revision.
#
# Why: IHP-Open-PDK commit 23854a19 ("libs.tech/librelane: sync sg13cmos5l and
# sg13g2, general cleanup", 2026-10-15) moved the PDK's LibreLane config to the
# variable names of LibreLane's `dev` branch -- LIB -> CELL_LIBS + PAD_LIBS,
# KLAYOUT_*_OPTIONS -> KLAYOUT_*_DEFINES. Every released LibreLane (main
# 64ef808, the nix profile's 3.0.16) still reads LIB and stops at PDK load:
# "Required PDK variable 'LIB' did not get a specified value". The cells,
# LEF, Liberty, GDS and the KLayout decks stay the current ones; only the
# LibreLane glue is the revision before that commit. (The sg13g2 runs are not
# affected: LibreLane takes sg13g2 from ciel, which predates the rename.)
# Drop this once LibreLane releases the new names.
#
#   common/pnr/cmos5l_pdk.sh <out_dir>      # out_dir becomes the PDK root
#
# PDK_ROOT (default /opt/IHP-Open-PDK) must be a git checkout; REV overrides
# the revision the LibreLane config comes from.
set -eu
out=$1
src=${PDK_ROOT:-/opt/IHP-Open-PDK}
src=${src%/}
rev=${REV:-23854a19^}
# A checkout older than the rename (no 23854a19, e.g. bf079026) still has the
# old names in its own config: take that one.
if [ -z "${REV:-}" ] && ! git -C "$src" merge-base --is-ancestor 23854a19 HEAD 2>/dev/null; then
    rev=HEAD
fi

# The blocks' harden_cmos5l may start together and all ask for it: build once.
lock="$out.lock"
until mkdir "$lock" 2>/dev/null; do sleep 1; done
trap 'rmdir "$lock"' EXIT
if [ -f "$out/.stamp" ] && [ "$out/.stamp" -nt "$0" ]; then
    exit 0
fi

rm -rf "$out"
mkdir -p "$out/ihp-sg13cmos5l/libs.tech"
for e in "$src"/ihp-sg13cmos5l/*; do
    [ "$(basename "$e")" = libs.tech ] || ln -s "$e" "$out/ihp-sg13cmos5l/"
done
for e in "$src"/ihp-sg13cmos5l/libs.tech/*; do
    [ "$(basename "$e")" = librelane ] || ln -s "$e" "$out/ihp-sg13cmos5l/libs.tech/"
done
git -C "$src" archive "$rev" ihp-sg13cmos5l/libs.tech/librelane | tar -x -C "$out"
# CMOS5L's KLayout decks link into ihp-sg13g2 relative to the PDK root.
ln -s "$src/ihp-sg13g2" "$out/ihp-sg13g2"
touch "$out/.stamp"
echo "$out: ihp-sg13cmos5l from $src, libs.tech/librelane from $(git -C "$src" rev-parse --short "$rev")"
