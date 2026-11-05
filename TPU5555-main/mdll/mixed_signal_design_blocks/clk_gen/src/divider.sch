v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -130 -20 -90 -20 {lab=clk}
N -130 20 -90 20 {lab=resetb}
N 90 -20 130 -20 {lab=g0}
N 60 150 210 150 {lab=g0}
N 170 130 210 130 {lab=clk}
N 170 170 210 170 {lab=resetb}
N 390 130 430 130 {lab=g1}
N -100 280 -60 280 {lab=g0}
N -100 320 -60 320 {lab=g1}
N 170 280 210 280 {lab=clk}
N 390 280 430 280 {lab=div_g}
N 510 280 550 280 {lab=div}
N 90 300 90 370 {lab=divn1}
N 60 300 90 300 {lab=divn1}
N 210 300 210 380 {lab=gate}
N -130 620 -60 620 {lab=rstb_g}
C {sg13g2_dfrbp_1.sym} 0 0 0 0 {name=x1 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dfrbp_1.sym} 300 150 0 0 {name=x2 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_nor2b_1.sym} 0 300 0 0 {name=x4 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {ipin.sym} -130 -20 0 0 {name=p1 lab=clk}
C {ipin.sym} -130 20 0 0 {name=p2 lab=resetb}
C {opin.sym} 130 -20 0 0 {name=p3 lab=g0}
C {opin.sym} 430 130 0 0 {name=p4 lab=g1}
C {sg13g2_lgcp_1.sym} 300 290 0 0 {name=x5 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {opin.sym} 90 370 0 0 {name=p5 lab=divn1}
C {lab_pin.sym} 170 280 0 0 {name=p12 sig_type=std_logic lab=clk}
C {lab_pin.sym} 170 130 0 0 {name=p8 sig_type=std_logic lab=clk}
C {lab_pin.sym} 170 170 0 0 {name=p9 sig_type=std_logic lab=resetb}
C {lab_pin.sym} -100 280 0 0 {name=p10 sig_type=std_logic lab=g0}
C {lab_pin.sym} -100 320 0 0 {name=p11 sig_type=std_logic lab=g1}
C {opin.sym} 550 280 0 0 {name=p14 lab=div}
C {sg13g2_buf_4.sym} 470 280 0 0 {name=x9 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 210 380 3 1 {name=p13 sig_type=std_logic lab=gate}
C {sg13g2_dfrbpq_1.sym} 0 460 0 0 {name=x6 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -90 440 0 0 {name=p15 sig_type=std_logic lab=divn1}
C {lab_pin.sym} -90 460 0 0 {name=p16 sig_type=std_logic lab=tie_hi}
C {lab_pin.sym} -90 480 0 0 {name=p17 sig_type=std_logic lab=arm_rstb}
C {lab_pin.sym} 90 440 2 0 {name=p18 sig_type=std_logic lab=gate}
C {sg13g2_nor2b_1.sym} 0 600 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -60 580 0 0 {name=p19 sig_type=std_logic lab=div}
C {ipin.sym} -130 620 0 0 {name=p20 lab=rstb_g}
C {lab_pin.sym} 60 600 2 0 {name=p21 sig_type=std_logic lab=arm_rstb}
C {sg13g2_tiehi.sym} -200 400 0 0 {name=x8 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -200 400 2 0 {name=p22 sig_type=std_logic lab=tie_hi}
T {div: the 4th clk rising edge of each run.

x1, x2: the period count, a 2-bit Johnson counter (x1.D = x2.Q_N, x2.D =
x1.Q), so it runs in Gray: g = 00, 01, 11, 10 in periods 0..3 of a run, one bit
per edge. clk_gen's decoder dithers from it (unit N on for the last k periods,
rtl/dco_decode.v), and one bit per edge is what keeps that decode free of
glitches on a running ring. It used to be binary (x3, an xor) -- divn1 = 11
then; now x4 (nor2b) decodes period 3 = 10.

x6 is armed by divn1 (after the 3rd edge) and cleared by div itself through
x7, so exactly the next clk edge passes the clock gate -- the injected edge in
lock, the ring's own 4th edge if it is fast or slow. It is NOT cleared by
resetb (= clk_gen's div_rstb_c, low while sel is high): in lock sel rises
before the injected edge, and that edge must still pass. rstb_g is the global
reset. A ring too fast to wait (code 0 runs 6 edges before sel) still gives
div at its 4th edge, so the TDC sees the error lock_ctrl's model assumes.
x5 is the library's integrated clock gate: GATE is latched while clk is low,
so it only has to settle before that edge, and x7 can drop it while clk is high
without chopping the pulse.
x9 is div's output buffer, drawn here rather than left to LibreLane's port
buffering (off for clk_gen, see pnr/config.yaml), because its delay must be
replicated: mdll.sch passes clk_ref through the same chain -- an always-enabled
lgcp_1, a buf_4, and a nor2b_1 input as a dummy for x7's -- before the TDC and
the bbpd, so x5 and x9 see the same loads as their copies and the gate delays
cancel. x7 reads div after x9 so that x5 drives x9 alone.
x9 is a buf_4, not a buf_1: the top-level div and clk_ref_g wires are not
length-matched, and with buf_1 (~2 ps/fF) re-routes alone moved the residual
from -46 to +20 ps (sg13cmos5l, 2026-10-23). The replica's x7 is a buf_4 too.} -140 700 0 0 0.3 0.3 {}
C {lab_pin.sym} 60 150 2 1 {name=p6 sig_type=std_logic lab=g0}
C {lab_pin.sym} -90 0 0 0 {name=p7 sig_type=std_logic lab=g1b}
C {lab_pin.sym} 390 150 2 0 {name=p23 sig_type=std_logic lab=g1b}
