v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 160 40 290 40 {
lab=slow_osci}
N 160 -20 250 -20 {
lab=fast_osci}
N 250 -20 250 20 {
lab=fast_osci}
N 250 20 290 20 {
lab=fast_osci}
N 250 -20 520 -20 {
lab=fast_osci}
N 520 -20 520 20 {
lab=fast_osci}
N 520 20 560 20 {
lab=fast_osci}
N 470 20 500 20 {
lab=q1}
N 500 20 500 40 {
lab=q1}
N 500 40 560 40 {
lab=q1}
N 500 -60 500 20 {
lab=q1}
N 500 -60 770 -60 {
lab=q1}
N 740 -20 740 20 {
lab=q2}
N 740 -20 770 -20 {
lab=q2}
N 890 -40 890 20 {
lab=#net1}
N 890 20 910 20 {
lab=#net1}
N 290 60 290 90 {
lab=reset}
N 560 60 560 90 {
lab=reset}
N 910 60 910 90 {
lab=reset}
N 880 40 910 40 {
lab=one}
N 290 90 560 90 {
lab=reset}
N 560 90 910 90 {
lab=reset}
N 910 90 1090 90 {
lab=reset}
N 1090 20 1160 20 {
lab=detect}
N 160 90 290 90 {
lab=reset}
C {sg13g2_dfrbp_1.sym} 380 40 0 0 {name=x3 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dfrbp_1.sym} 650 40 0 0 {name=x4 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_nand2_1.sym} 830 -40 0 0 {name=x5 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dfrbp_1.sym} 1000 40 0 0 {name=x6 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 880 40 0 0 {name=p5 sig_type=std_logic lab=one}
C {sg13g2_tiehi.sym} 880 140 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 880 140 2 0 {name=p8 sig_type=std_logic lab=one}
C {ipin.sym} 160 40 0 0 {name=p3 lab=slow_osci}
C {ipin.sym} 160 -20 0 0 {name=p4 lab=fast_osci}
C {ipin.sym} 160 90 0 0 {name=p1 lab=reset}
C {opin.sym} 1160 20 0 0 {name=p2 lab=detect}
C {lab_pin.sym} 500 -60 0 0 {name=p6 sig_type=std_logic lab=q1}
C {lab_pin.sym} 740 -20 0 0 {name=p7 sig_type=std_logic lab=q2}
