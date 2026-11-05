v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Arming guard (x7..x10).

The selector arms on divn1 (after the 3rd edge) and raises sel on the next
M_out rising edge. That is only right if clk_ref has FALLEN since the last
injection: a ring so fast that 3.5 periods end in the first, high half of the
same reference period would otherwise see clk_ref high, have sel glitch (the
mux feeds clk_refb = 0, M_out drops, sel clears) and free-run -- 8 edges per
period at code 0. A LATE ring arms in the next high half with the fall already
seen, and still realigns immediately, as before.

x7  ref_fell: set by the falling clk_ref edge, cleared while sel is high
    (div_rstb = Resetb * Selb).
x8  armed: ref_fell sampled on M_out's falling edges, so it only ever changes
    while M_out is low -- sel still rises only on an M_out rising edge, and
    the divider's ICG still captures exactly one clock edge. While the ring
    is gated M_out stays high, so armed (and sel) hold; the injection's M_out
    fall clears it.
x9  the selector sees M_out * armed instead of M_out.} -1180 20 0 0 0.3 0.3 {}
T {Divider reset release (x12): div_rstb asserts the divider reset at once,
but releases it only on the next FALLING clk_out edge. A ring slightly slow
delivers its 4th rising edge after sel has fallen; with an asynchronous
release that edge was counted as #1 of the next run, which then came up one
DCO period short and read "early" -- a false lock near code 96..100 in the
closed fine loop. Held in reset until clk_out falls, the late edge is not
counted, and the ICG window still covers it, so it leaves as a (late) div.
Only the release is synchronous: x13 asserts the divider reset (and opens the
ICG) straight from Selb, one gate as before -- x12's reset-to-Q (~270 ps) on
that path made the ICG miss the 4th edge at code 0.
div_rstb_s enters x13 on A, its fastest input (~8 ps over C at ff): x12 -> x11
recovery is clk_gen's tightest STA check (pnr/base.sdc).} -1580 610 0 0 0.3 0.3 {}
N -330 -140 -190 -140 {lab=sel_i}
N -350 -140 -330 -140 {lab=sel_i}
N -470 -140 -430 -140 {lab=sel}
N -330 -140 -330 -10 {lab=sel_i}
N -270 -290 -270 -250 {lab=clk_ref}
N -270 -290 -190 -290 {lab=clk_ref}
N -190 -290 -190 -160 {lab=clk_ref}
N -270 -170 -270 -120 {lab=clk_refb}
N -270 -120 -190 -120 {lab=clk_refb}
N -30 -230 -30 -200 {lab=C[7:0] bus=true}
N -220 90 -220 130 {lab=Resetb}
N -90 -80 -90 50 {lab=M_outb}
N -110 50 -90 50 {lab=M_outb}
N -220 130 -110 130 {lab=Resetb}
N -330 30 -330 170 {lab=selb}
N -330 170 -110 170 {lab=selb}
N -90 -80 -60 -80 {lab=M_outb}
N 130 -160 300 -160 {lab=ring_out}
N 380 -160 430 -160 {lab=clk_out}
N -110 10 -70 10 {lab=divn1}
N 10 150 50 150 {lab=div_rstb}
N 420 50 460 50 {lab=ring_out}
N 420 90 460 90 {lab=div_rstb_c}
N 680 20 720 20 {lab=g[0]}
N 680 50 720 50 {lab=g[1]}
N 680 80 720 80 {lab=div}
N 390 -130 430 -130 {lab=div}
N 680 110 720 110 {lab=divn1}
N 420 120 460 120 {lab=Resetb}
N 0 -80 0 -60 {lab=M_out}
C {clk_gen/src/dco.sym} -30 -140 0 0 {name=x1}
C {clk_gen/src/selector.sym} -220 10 0 1 {name=x4}
C {clk_gen/src/divider.sym} 570 70 0 0 {name=x11}
C {sg13g2_inv_1.sym} -270 -210 1 0 {name=x5 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 50 150 2 0 {name=p17 sig_type=std_logic lab=div_rstb}
C {lab_pin.sym} -90 -70 0 0 {name=p29 sig_type=std_logic lab=M_outb}
C {lab_pin.sym} 0 -60 2 0 {name=p30 sig_type=std_logic lab=M_out}
C {sg13g2_and2_2.sym} -50 150 0 0 {name=x6 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 720 20 2 0 {name=p38 sig_type=std_logic lab=g[0]}
C {lab_pin.sym} 720 50 2 0 {name=p39 sig_type=std_logic lab=g[1]}
C {lab_pin.sym} 720 80 2 0 {name=p40 sig_type=std_logic lab=div}
C {lab_pin.sym} 390 -130 0 0 {name=p43 sig_type=std_logic lab=div}
C {opin.sym} 430 -130 0 0 {name=p44 lab=div}
C {lab_pin.sym} 420 50 0 0 {name=p41 sig_type=std_logic lab=ring_out}
C {sg13g2_buf_1.sym} 340 -160 0 0 {name=x14 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 300 -160 2 1 {name=p91 sig_type=std_logic lab=ring_out}
C {lab_pin.sym} -350 -140 2 1 {name=p92 sig_type=std_logic lab=sel_i}
C {lab_pin.sym} 420 90 0 0 {name=p42 sig_type=std_logic lab=div_rstb_c}
C {lab_pin.sym} 420 120 0 0 {name=p90 sig_type=std_logic lab=Resetb}
C {ipin.sym} -270 -290 0 0 {name=p1 lab=clk_ref}
C {opin.sym} 430 -160 0 0 {name=p2 lab=clk_out}
C {opin.sym} -470 -140 2 0 {name=p3 lab=sel}
C {sg13g2_buf_1.sym} -390 -140 2 0 {name=x15 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {ipin.sym} -220 130 0 0 {name=p4 lab=Resetb}
C {ipin.sym} -30 -230 1 0 {name=p5 lab=C[7:0]}
C {lab_pin.sym} 720 110 2 0 {name=p6 sig_type=std_logic lab=divn1}
C {lab_pin.sym} -70 10 2 0 {name=p7 sig_type=std_logic lab=divn1}
C {lab_pin.sym} -110 -30 0 1 {name=p50 sig_type=std_logic lab=M_out_g}
C {lab_pin.sym} -270 -120 0 0 {name=p51 sig_type=std_logic lab=clk_refb}
C {sg13g2_dfrbp_1.sym} -500 520 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -590 500 0 0 {name=p52 sig_type=std_logic lab=clk_refb}
C {lab_pin.sym} -590 520 0 0 {name=p53 sig_type=std_logic lab=arm_one}
C {lab_pin.sym} -590 540 0 0 {name=p54 sig_type=std_logic lab=div_rstb}
C {lab_pin.sym} -410 500 2 0 {name=p55 sig_type=std_logic lab=ref_fell}
C {sg13g2_dfrbp_1.sym} -500 680 0 0 {name=x8 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -590 660 0 0 {name=p56 sig_type=std_logic lab=M_outb}
C {lab_pin.sym} -590 680 0 0 {name=p57 sig_type=std_logic lab=ref_fell}
C {lab_pin.sym} -590 700 0 0 {name=p58 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} -410 660 2 0 {name=p59 sig_type=std_logic lab=armed}
C {sg13g2_and2_1.sym} -250 680 0 0 {name=x9 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -310 660 0 0 {name=p60 sig_type=std_logic lab=M_out}
C {lab_pin.sym} -310 700 0 0 {name=p61 sig_type=std_logic lab=armed}
C {lab_pin.sym} -190 680 2 0 {name=p62 sig_type=std_logic lab=M_out_g}
C {sg13g2_tiehi.sym} -680 600 0 0 {name=x10 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -680 600 2 0 {name=p63 sig_type=std_logic lab=arm_one}
C {lab_pin.sym} 130 -120 2 0 {name=p64 sig_type=std_logic lab=clk_outb}
C {sg13g2_dfrbp_1.sym} -500 860 0 0 {name=x12 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -590 840 0 0 {name=p65 sig_type=std_logic lab=clk_outb}
C {lab_pin.sym} -590 860 0 0 {name=p66 sig_type=std_logic lab=arm_one}
C {lab_pin.sym} -590 880 0 0 {name=p67 sig_type=std_logic lab=div_rstb}
C {lab_pin.sym} -410 840 2 0 {name=p68 sig_type=std_logic lab=div_rstb_s}
C {noconn.sym} -410 860 2 0 {name=l69}
C {lab_pin.sym} -110 170 0 0 {name=p70 sig_type=std_logic lab=selb}
C {sg13g2_and3_2.sym} -200 1000 0 0 {name=x13 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -260 960 0 0 {name=p71 sig_type=std_logic lab=div_rstb_s}
C {lab_pin.sym} -260 1000 0 0 {name=p72 sig_type=std_logic lab=selb}
C {lab_pin.sym} -260 1040 0 0 {name=p73 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} -140 1000 2 0 {name=p74 sig_type=std_logic lab=div_rstb_c}
N 30 -230 30 -200 {lab=g[1:0] bus=true}
C {lab_pin.sym} 30 -230 3 0 {name=p75 sig_type=std_logic lab=g[1:0]}
