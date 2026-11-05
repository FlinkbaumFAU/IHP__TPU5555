v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -260 -120 -220 -120 {lab=Div}
N -240 -80 -240 0 {lab=#net1}
N -240 -80 -220 -80 {lab=#net1}
N -300 80 -300 120 {lab=Resetb}
N -340 -100 -220 -100 {lab=tie_hi}
N -220 80 -220 100 {lab=tie_lo}
N -260 80 -260 160 {lab=#net2}
N -260 160 -160 160 {lab=#net2}
N -40 180 0 180 {lab=M_outb}
N -40 -120 0 -120 {lab=#net3}
N -40 -160 0 -160 {lab=M_out}
N 120 -180 160 -180 {lab=Resetb}
N 120 -140 160 -140 {lab=#net4}
N 320 -160 440 -160 {lab=Sel}
N 320 -40 320 140 {lab=Sel}
N 280 -160 320 -160 {lab=Sel}
N -40 140 320 140 {lab=Sel}
N 320 -40 340 -40 {lab=Sel}
N 320 -160 320 -40 {lab=Sel}
N 420 -40 440 -40 {lab=Selb}
C {ipin.sym} -300 120 3 0 {name=p1 lab=Resetb}
C {ipin.sym} -40 -160 2 1 {name=p2 lab=M_out}
C {ipin.sym} 0 180 2 0 {name=p3 lab=M_outb}
C {sg13g2_dfrbp_1.sym} -130 -100 0 0 {name=x1 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {ipin.sym} -260 -120 0 0 {name=p5 lab=Div}
C {sg13g2_mux2_1.sym} -240 40 1 1 {name=x2 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_tiehi.sym} -340 -100 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_tielo.sym} -220 100 0 0 {name=x8 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_nand2_1.sym} -100 160 0 1 {name=x3 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_nand2_1.sym} 60 -140 2 1 {name=x4 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_nand2_1.sym} 220 -160 2 1 {name=x5 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 120 -180 0 0 {name=p4 sig_type=std_logic lab=Resetb}
C {opin.sym} 440 -160 0 0 {name=p6 lab=Sel}
C {sg13g2_inv_2.sym} 380 -40 0 0 {name=x6 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {opin.sym} 440 -40 0 0 {name=p7 lab=Selb}
C {lab_pin.sym} -280 -100 0 0 {name=p8 sig_type=std_logic lab=tie_hi}
C {lab_pin.sym} -220 90 0 1 {name=p9 sig_type=std_logic lab=tie_lo}
