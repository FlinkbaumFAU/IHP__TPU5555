#!/bin/bash
# Signoff reruns on the final release GDS/CDL of TPU5555.
# Paths are those of the machine it was run on (cae02); override W, PDK_DIR, H and KL
# from the environment (defaults: the v.1.0.0 run).
# H must contain the decks/CDLs of TPU5555-main/Flow/scripts/LibreLane (identical copies).
# EXTRA_CDLS: further schematic CDLs, appended after the IO CDL (v.2.0.0: the
# MDLL's pin-only ip/mdll/cdl/mdll_bb.cdl; the MDLL is compared as a black box).
set -u
W=${W:-/scratch.local/fi08deni/eda/tpu5555_signoff}
# PDK_DIR, not PDK: cae02's login environment exports PDK=ihp-sg13g2.
PDK_DIR=${PDK_DIR:-/scratch/IHP-Open-PDK/ihp-sg13cmos5l}
H=${H:-/scratch.local/fi08deni/eda/hdc/asic}
KL=${KL:-/nix/store/c8mymw0gckkiw7lqwnm2l6mqnd99xmzy-klayout-0.30.7/bin/klayout}
EXTRA_CDLS=${EXTRA_CDLS:-}
G=$W/in/TPU5555.gds
cd $W; mkdir -p drc drc_precheck density antenna lvs
{ echo "date: $(date -Is)"; echo "host: $(hostname)"; $KL -v; echo "PDK: $(git -C $(dirname $PDK_DIR) rev-parse HEAD)"; echo "decks: $H (hdc $(git -C $H rev-parse HEAD))"; sha256sum in/* ; } > versions.txt
cat in/TPU5555.cdl $PDK_DIR/libs.ref/sg13cmos5l_stdcell/cdl/sg13cmos5l_stdcell.cdl $H/cdl/sram.cdl $H/ip/bondpad_70x70/cdl/bondpad_70x70.cdl $H/cdl/sg13cmos5l_io.cdl $EXTRA_CDLS > lvs/schematic.cdl
D=$PDK_DIR/libs.tech/klayout/tech/drc
( /usr/bin/time -v $KL -b -zz -r $D/ihp-sg13cmos5l.drc -rd input=$G -rd topcell=TPU5555 -rd report=$W/drc/drc.klayout.lyrdb -rd no_recommended=true -rd run_mode=deep -rd threads=24 > drc/klayout-drc.log 2>&1; echo "exit $?" >> drc/klayout-drc.log ) &
( /usr/bin/time -v $KL -b -zz -r $D/ihp-sg13cmos5l.drc -rd input=$G -rd topcell=TPU5555 -rd report=$W/drc_precheck/drc_precheck.klayout.lyrdb -rd precheck_drc=true -rd no_recommended=true -rd run_mode=deep -rd threads=24 > drc_precheck/klayout-drc-precheck.log 2>&1; echo "exit $?" >> drc_precheck/klayout-drc-precheck.log ) &
( /usr/bin/time -v $KL -b -zz -r $D/rule_decks/density.drc -rd input=$G -rd topcell=TPU5555 -rd report=$W/density/density.klayout.lyrdb -rd threads=24 > density/klayout-density.log 2>&1; echo "exit $?" >> density/klayout-density.log ) &
( /usr/bin/time -v $KL -b -zz -r $H/drc/antenna_cmos5l_pr990.drc -rd input=$G -rd topcell=TPU5555 -rd report=$W/antenna/antenna.klayout.lyrdb -rd drc_json_default=$D/rule_decks/sg13cmos5l_tech_default.json -rd drc_json=$PDK_DIR/libs.tech/klayout/python/sg13cmos5l_pycell_lib/sg13cmos5l_tech_mod.json > antenna/klayout-antenna.log 2>&1; echo "exit $?" >> antenna/klayout-antenna.log ) &
( /usr/bin/time -v $KL -b -zz -r $H/lvs/sg13cmos5l_chip.lvs -rd input=$G -rd schematic=$W/lvs/schematic.cdl -rd report=$W/lvs/lvs.klayout.lvsdb -rd target_netlist=$W/lvs/TPU5555_extracted.cir -rd run_mode=deep > lvs/klayout-lvs.log 2>&1; echo "exit $?" >> lvs/klayout-lvs.log ) &
wait
echo "ALL DONE $(date -Is)" > done.txt
