v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -700 -30 -640 -30 {lab=ring_p}
N -700 -70 -640 -70 {lab=clk_ref}
N -700 80 -640 80 {lab=clk_refb}
N -860 -110 -860 120 {lab=sel}
N -860 120 -640 120 {lab=sel}
N -860 -110 -640 -110 {lab=sel}
N -700 40 -640 40 {lab=ring_n}
N 150 50 330 50 {lab=#net1}
N -530 60 -530 100 {lab=M_out}
N -530 -90 -530 -50 {lab=M_outb}
N 470 -50 650 -50 {lab=#net2}
N -530 60 -500 60 {lab=M_out}
N 470 50 650 50 {lab=#net4}
N 150 -50 330 -50 {lab=#net5}
N -530 -50 -500 -50 {lab=M_outb}
N -560 60 -530 60 {lab=M_out}
N -170 50 10 50 {lab=#net6}
N -170 -50 10 -50 {lab=#net7}
N -420 -50 -310 -50 {lab=#net8}
N -420 60 -310 60 {lab=#net9}
N -560 -50 -530 -50 {lab=M_outb}
N -310 50 -310 60 {lab=#net9}
N -180 -600 -40 -600 {lab=C[7:0]
bus=true}
N 200 -705 260 -705 {lab=co0[7:0]
bus=true}
N 200 -675 260 -675 {lab=cob0[7:0]
bus=true}
N 200 -645 260 -645 {lab=co1[7:0]
bus=true}
N 200 -615 260 -615 {lab=cob1[7:0]
bus=true}
N 200 -585 260 -585 {lab=co2[7:0]
bus=true}
N 200 -555 260 -555 {lab=cob2[7:0]
bus=true}
N 200 -525 260 -525 {lab=co3[7:0]
bus=true}
N 200 -495 260 -495 {lab=cob3[7:0]
bus=true}
N -340 -20 -310 -20 {lab=co0[7:0]
bus=true}
N -340 20 -310 20 {lab=cob0[7:0]
bus=true}
N -20 -20 10 -20 {lab=co1[7:0]
bus=true}
N -20 20 10 20 {lab=cob1[7:0]
bus=true}
N 300 -20 330 -20 {lab=co2[7:0]
bus=true}
N 300 20 330 20 {lab=cob2[7:0]
bus=true}
N 620 -20 650 -20 {lab=co3[7:0]
bus=true}
N 620 20 650 20 {lab=cob3[7:0]
bus=true}
N 800 -50 830 -50 {lab=ring_p}
N 800 -120 800 -50 {lab=ring_p}
N 910 -50 950 -50 {lab=tapb1}
N 1030 -50 1070 -50 {lab=tapb2}
N 1150 -50 1200 -50 {lab=clk_outb}
N 800 50 830 50 {lab=ring_n}
N 800 50 800 120 {lab=ring_n}
N 910 50 950 50 {lab=tap1}
N 1030 50 1070 50 {lab=tap2}
N 1150 50 1200 50 {lab=clk_out}
N 790 -50 800 -50 {lab=ring_p}
N 790 50 800 50 {lab=ring_n}
C {ipin.sym} -700 80 2 1 {name=p3 lab=clk_refb}
C {ipin.sym} -700 -70 2 1 {name=p4 lab=clk_ref}
C {ipin.sym} -860 0 2 1 {name=p1 lab=sel}
C {lab_pin.sym} -700 40 2 1 {name=p2 sig_type=std_logic lab=ring_n}
C {lab_pin.sym} -700 -30 2 1 {name=p5 sig_type=std_logic lab=ring_p}
C {clk_gen/src/delay_cell.sym} -170 0 0 0 {name=x3}
C {clk_gen/src/delay_cell.sym} 150 0 0 0 {name=x4}
C {clk_gen/src/delay_cell.sym} 470 0 0 0 {name=x5}
C {clk_gen/src/delay_cell.sym} 790 0 0 0 {name=x6}
C {opin.sym} 1200 -50 0 0 {name=p7 lab=clk_outb}
C {opin.sym} -530 100 1 0 {name=p9 lab=M_out}
C {opin.sym} -530 -90 3 0 {name=p10 lab=M_outb}
C {sg13g2_inv_2.sym} -460 -50 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_2.sym} -460 60 0 0 {name=x8 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_mux2_2.sym} -600 -50 2 1 {name=x9 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_mux2_2.sym} -600 60 0 0 {name=x1 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_16.sym} 1110 -50 0 0 {name=x2 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_16.sym} 1110 50 0 0 {name=x10 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {opin.sym} 1200 50 0 0 {name=p11 lab=clk_out}
C {ipin.sym} -180 -600 0 0 {name=p8 lab=C[7:0]}
C {clk_gen/src/dco_decode.sym} 80 -600 0 0 {name=x11}
C {lab_pin.sym} 260 -705 0 1 {name=l_co0 sig_type=std_logic lab=co0[7:0]}
C {lab_pin.sym} 260 -675 0 1 {name=l_cob0 sig_type=std_logic lab=cob0[7:0]}
C {lab_pin.sym} 260 -645 0 1 {name=l_co1 sig_type=std_logic lab=co1[7:0]}
C {lab_pin.sym} 260 -615 0 1 {name=l_cob1 sig_type=std_logic lab=cob1[7:0]}
C {lab_pin.sym} 260 -585 0 1 {name=l_co2 sig_type=std_logic lab=co2[7:0]}
C {lab_pin.sym} 260 -555 0 1 {name=l_cob2 sig_type=std_logic lab=cob2[7:0]}
C {lab_pin.sym} 260 -525 0 1 {name=l_co3 sig_type=std_logic lab=co3[7:0]}
C {lab_pin.sym} 260 -495 0 1 {name=l_cob3 sig_type=std_logic lab=cob3[7:0]}
C {lab_pin.sym} -340 -20 2 1 {name=l_x3_co0 sig_type=std_logic lab=co0[7:0]}
C {lab_pin.sym} -340 20 2 1 {name=l_x3_cob0 sig_type=std_logic lab=cob0[7:0]}
C {lab_pin.sym} -20 -20 2 1 {name=l_x4_co1 sig_type=std_logic lab=co1[7:0]}
C {lab_pin.sym} -20 20 2 1 {name=l_x4_cob1 sig_type=std_logic lab=cob1[7:0]}
C {lab_pin.sym} 300 -20 2 1 {name=l_x5_co2 sig_type=std_logic lab=co2[7:0]}
C {lab_pin.sym} 300 20 2 1 {name=l_x5_cob2 sig_type=std_logic lab=cob2[7:0]}
C {lab_pin.sym} 620 -20 2 1 {name=l_x6_co3 sig_type=std_logic lab=co3[7:0]}
C {lab_pin.sym} 620 20 2 1 {name=l_x6_cob3 sig_type=std_logic lab=cob3[7:0]}
C {sg13g2_inv_1.sym} 870 -50 0 0 {name=xb1 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_4.sym} 990 -50 0 0 {name=xb2 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_1.sym} 870 50 0 0 {name=xb3 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_4.sym} 990 50 0 0 {name=xb4 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 800 -120 0 0 {name=p12 sig_type=std_logic lab=ring_p}
C {lab_pin.sym} 800 120 0 0 {name=p13 sig_type=std_logic lab=ring_n}
N -180 -560 -40 -560 {lab=g[1:0] bus=true}
C {ipin.sym} -180 -560 0 0 {name=p_g lab=g[1:0]}
