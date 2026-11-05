v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Vernier TDC.

Reset generator (x8, x9): x8 toggles on every rising Sel, so x9 is clocked on
every SECOND one and raises Reset -- the run enable. A run ends when the
edge-lock detector fires (Detect) or the phase detector reports that the
rings started too close together (hit_raw); either pulls x9's RESET_B low
through x10. Dropping Reset clears everything that fed x10, so x9's reset
self-releases and the next armed Sel edge starts a new run.

Start flops (x6, x7) hold each ring enabled from the first clk_out / clk_ref
edge after Reset rises: slow ring on clk_out, fast ring on clk_ref.

Capture register (xcs, xcf, xch, xcv): Detect/hit_raw also clock the counts
out BEFORE the self-clear reaches the counters. That race is invisible to STA
-- see the Makefile's tdc_sim check for the measured margin.} -1300 -620 0 0 0.35 0.35 {}
N -130 -60 -60 -60 {
lab=OS}
N -130 280 -20 280 {
lab=OF}
N -60 -60 -60 0 {
lab=OS}
N -60 0 0 0 {
lab=OS}
N 200 -20 270 -20 {
lab=Detect}
N -60 -140 -60 -60 {
lab=OS}
N -60 -140 70 -140 {
lab=OS}
N -20 280 70 280 {
lab=OF}
N -260 280 -230 280 {
lab=FO_enable}
N -60 20 0 20 {
lab=Reset}
N 30 320 70 320 {
lab=Reset}
N 30 -100 70 -100 {
lab=Reset}
N 280 -120 310 -120 {
lab=ccount[7:0]}
N 280 300 310 300 {
lab=fcount[7:0]}
N 280 -150 280 -120 {
lab=ccount[7:0]}
N 250 -120 280 -120 {
lab=ccount[7:0]}
N 280 300 280 330 {
lab=fcount[7:0]}
N 250 300 280 300 {
lab=fcount[7:0]}
N -260 -60 -230 -60 {lab=SO_enable}
N -520 -60 -490 -60 {lab=Clk_out}
N -520 280 -490 280 {lab=Clk_ref}
N -620 -40 -490 -40 {lab=one}
N -620 300 -490 300 {lab=one}
N -1020 0 -1020 60 {lab=#net1}
N -1230 60 -1020 60 {lab=#net1}
N -1230 0 -1230 60 {lab=#net1}
N -1230 0 -1200 0 {lab=#net1}
N -1250 -20 -1200 -20 {lab=Sel}
N -1020 -20 -960 -20 {lab=#net2}
N -980 0 -960 0 {lab=one}
N -740 -20 -490 -20 {lab=Reset}
N -740 320 -490 320 {lab=Reset}
N -780 -20 -740 -20 {lab=Reset}
N -960 20 -960 60 {lab=#net3}
N -1000 180 -1000 320 {lab=Start}
N -960 290 -960 320 {lab=Detect}
N -960 180 -960 210 {lab=#net4}
N -920 180 -920 210 {lab=#net5}
N -740 -20 -740 320 {lab=Reset}
N -620 -40 -620 300 {lab=one}
N -20 -20 -0 -20 {lab=OF}
N -20 -20 -20 280 {lab=OF}
N -980 -130 -980 0 {lab=one}
N -980 -130 -620 -130 {lab=one}
N -980 -180 -980 -130 {lab=one}
N -620 -130 -620 -40 {lab=one}
N -260 -60 -260 80 {lab=SO_enable}
N -270 80 -260 80 {lab=SO_enable}
N -310 -60 -260 -60 {lab=SO_enable}
N -260 100 -260 280 {lab=FO_enable}
N -270 100 -260 100 {lab=FO_enable}
N -310 280 -260 280 {
lab=FO_enable}
N -60 20 -60 120 {lab=Reset}
N -270 120 -60 120 {lab=Reset}
C {lab_pin.sym} -80 280 3 0 {name=p1 sig_type=std_logic lab=OF}
C {lab_pin.sym} -80 -60 1 0 {name=p2 sig_type=std_logic lab=OS}
C {lab_pin.sym} 270 -20 2 0 {name=p6 sig_type=std_logic lab=Detect}
C {tdc/edge_lock/edge_lock_dector.sym} 150 0 0 0 {name=x3 VDD=VDD VSS=VSS}
C {tdc/osci/src/fast_osci.sym} -80 280 0 0 {name=x4 VDD=VDD VSS=VSS}
C {tdc/osci/src/slow_osci.sym} -80 -60 0 0 {name=x5 VDD=VDD VSS=VSS}
C {tdc/counter/src/counter.sym} 160 -120 0 0 {name=x1 VDD=VDD VSS=VSS}
C {tdc/counter/src/counter.sym} 160 300 0 0 {name=x2 VDD=VDD VSS=VSS}
C {lab_pin.sym} 30 320 0 0 {name=p9 sig_type=std_logic lab=Reset}
C {lab_pin.sym} 30 -100 0 0 {name=p12 sig_type=std_logic lab=Reset}
C {lab_pin.sym} 280 -150 1 0 {name=p15 sig_type=std_logic lab=ccount[7:0]}
C {lab_pin.sym} 280 330 3 0 {name=p16 sig_type=std_logic lab=fcount[7:0]}
C {sg13g2_dfrbp_1.sym} -400 -40 0 0 {name=x6 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dfrbp_1.sym} -400 300 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {ipin.sym} -1000 320 3 0 {name=p3 lab=Start}
C {ipin.sym} -1250 -20 0 0 {name=p4 lab=Sel}
C {ipin.sym} -520 -60 0 0 {name=p7 lab=Clk_out}
C {ipin.sym} -520 280 0 0 {name=p10 lab=Clk_ref}
C {sg13g2_dfrbp_1.sym} -1110 0 0 0 {name=x8 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dfrbp_1.sym} -870 0 0 0 {name=x9 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_and3_1.sym} -960 120 3 0 {name=x10 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_1.sym} -960 250 3 0 {name=x11 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_1.sym} -920 250 3 0 {name=x12 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -960 320 3 0 {name=p11 sig_type=std_logic lab=Detect}
C {lab_pin.sym} -740 -20 1 0 {name=p13 sig_type=std_logic lab=Reset}
C {lab_pin.sym} -60 20 0 0 {name=p14 sig_type=std_logic lab=Reset}
C {lab_pin.sym} -260 -60 1 0 {name=p8 sig_type=std_logic lab=SO_enable}
C {lab_pin.sym} -260 280 1 1 {name=p17 sig_type=std_logic lab=FO_enable}
C {lab_pin.sym} -1200 20 0 0 {name=p20 sig_type=std_logic lab=Start}
C {lab_pin.sym} -920 290 3 0 {name=p21 sig_type=std_logic lab=hit_raw}
C {sg13g2_tiehi.sym} -980 -180 0 0 {name=x13 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -980 -130 0 0 {name=p22 sig_type=std_logic lab=one}
C {tdc/src/tdc_pd.sym} -390 100 0 1 {name=x14 VDD=VDD VSS=VSS}
C {lab_pin.sym} -510 100 2 1 {name=p26 sig_type=std_logic lab=hit_raw}
C {sg13g2_or2_1.sym} 620 -200 0 0 {name=x15 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 560 -220 0 0 {name=p27 sig_type=std_logic lab=Detect}
C {lab_pin.sym} 560 -180 0 0 {name=p28 sig_type=std_logic lab=hit_raw}
C {lab_pin.sym} 680 -200 2 0 {name=p29 sig_type=std_logic lab=cap_clk}
C {sg13g2_dfrbpq_1.sym} 900 -100 0 0 {name=xcs[7:0] VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 810 -120 0 0 {name=p30 sig_type=std_logic lab=cap_clk}
C {lab_pin.sym} 810 -100 0 0 {name=p31 sig_type=std_logic lab=ccount[7:0]}
C {lab_pin.sym} 810 -80 0 0 {name=p32 sig_type=std_logic lab=Start}
C {opin.sym} 990 -120 0 0 {name=p33 lab=tdc_s[7:0]}
C {sg13g2_dfrbpq_1.sym} 900 100 0 0 {name=xcf[7:0] VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 810 80 0 0 {name=p34 sig_type=std_logic lab=cap_clk}
C {lab_pin.sym} 810 100 0 0 {name=p35 sig_type=std_logic lab=fcount[7:0]}
C {lab_pin.sym} 810 120 0 0 {name=p36 sig_type=std_logic lab=Start}
C {opin.sym} 990 80 0 0 {name=p37 lab=tdc_f[7:0]}
C {sg13g2_dfrbpq_1.sym} 900 300 0 0 {name=xch VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 810 280 0 0 {name=p38 sig_type=std_logic lab=cap_clk}
C {lab_pin.sym} 810 300 0 0 {name=p39 sig_type=std_logic lab=hit_raw}
C {lab_pin.sym} 810 320 0 0 {name=p40 sig_type=std_logic lab=Start}
C {opin.sym} 990 280 0 0 {name=p41 lab=hit}
C {sg13g2_dfrbpq_1.sym} 900 500 0 0 {name=xcv VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 810 480 0 0 {name=p42 sig_type=std_logic lab=cap_clk}
C {lab_pin.sym} 810 500 0 0 {name=p43 sig_type=std_logic lab=one}
C {lab_pin.sym} 810 520 0 0 {name=p44 sig_type=std_logic lab=Start}
C {opin.sym} 990 480 0 0 {name=p45 lab=valid}
C {sg13g2_buf_1.sym} 900 650 0 0 {name=x16 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 860 650 0 0 {name=p46 sig_type=std_logic lab=Reset}
C {opin.sym} 940 650 0 0 {name=p47 lab=busy}
