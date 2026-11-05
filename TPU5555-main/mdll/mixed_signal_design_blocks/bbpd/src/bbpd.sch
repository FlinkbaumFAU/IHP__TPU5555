v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {MDLL sequential-tracking loop: binary phase comparator + first-order
bang-bang accumulator.

The DCO code is the integral of the SIGN of the phase error. That works
only because clk_gen's cap bank is monotonic (63 identical unit caps
under a thermometer code, code-up => frequency-down) -- the step
direction is then never wrong, so the code walks straight to lock and
then dithers about it.

comp is brought out for observability: it is the lock indicator (at lock
it toggles; away from lock it sits at one value).

load/seed are the hook for the TDC's fast-acquisition path (the paper's
DLF#1). Nothing drives them yet -- tie load low.} -690 -520 0 0 0.4 0.4 {}
N -340 -20 -200 -20 {lab=clk_ref}
N -340 0 -200 0 {lab=div}
N -340 20 -200 20 {lab=resetb}
N 0 0 60 0 {lab=comp}
N 210 -100 330 -100 {lab=clk_ref_d}
N 210 -80 330 -80 {lab=clk_dlf}
N 0 40 60 40 {lab=clk_dlf}
N 0 20 60 20 {lab=clk_ref_d}
N 210 -40 330 -40 {lab=resetb}
N 210 0 330 0 {lab=comp}
N 210 40 330 40 {lab=load}
N 210 80 330 80 {lab=seed[7:0] bus=true}
N 570 0 700 0 {lab=C[7:0] bus=true}
C {bbpd/src/pd.sym} -100 0 0 0 {name=x1}
C {bbpd/src/dlf.sym} 450 0 0 0 {name=x2}
C {ipin.sym} -340 -20 0 0 {name=p1 lab=clk_ref}
C {ipin.sym} -340 0 0 0 {name=p2 lab=div}
C {ipin.sym} -340 20 0 0 {name=p3 lab=resetb}
C {ipin.sym} 210 40 0 0 {name=p4 lab=load}
C {ipin.sym} 210 80 0 0 {name=p5 lab=seed[7:0]}
C {opin.sym} 700 0 0 0 {name=p6 lab=C[7:0]}
C {opin.sym} 60 0 0 0 {name=p7 lab=comp}
C {lab_pin.sym} 210 -100 0 0 {name=p8 sig_type=std_logic lab=clk_ref_d}
C {lab_pin.sym} 210 -80 0 0 {name=p13 sig_type=std_logic lab=clk_dlf}
C {lab_pin.sym} 60 40 2 0 {name=p14 sig_type=std_logic lab=clk_dlf}
C {lab_pin.sym} 60 20 2 0 {name=p12 sig_type=std_logic lab=clk_ref_d}
C {lab_pin.sym} 210 -40 0 0 {name=p9 sig_type=std_logic lab=resetb}
C {lab_pin.sym} 210 0 0 0 {name=p10 sig_type=std_logic lab=comp}
