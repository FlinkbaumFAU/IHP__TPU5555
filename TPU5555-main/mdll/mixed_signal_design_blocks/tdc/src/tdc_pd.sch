v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {TDC phase detector -- the "close enough" check.

x1 samples fast_enable on a BUFFERED copy of slow_enable. The slow ring
starts first, so:

    fast_enable already high when the delayed slow edge arrives
        -> clk_ref followed div by less than t_buf (x2..x4),
           or preceded it outright
        -> hit = 1: the phase is inside the band the BBPD handles,
           and the Vernier could not resolve it anyway (a negative
           interval never produces an edge lock)

    fast_enable still low
        -> hit = 0: let the rings run to an edge lock.

t_buf is the hand-over threshold: an error the bang-bang loop should take
over rather than the TDC. It is sized to about one DCO step of e (4 x ~70 ps
at the lock code) plus margin, and wide enough to cover clk_gen's selector
dead band (~0.56 ns). Chain: dlygate4sd3 + 2x sd2 (~0.7 ns of cell delay;
the measured threshold is lower because x1's setup eats into it). A single
buf_1 (~50 ps) let the coarse loop make a one-step jump that the closed loop
showed should have been left to the BBPD; sd3 + sd2 still put the threshold
at 400..450 ps, right at that jump's reading.
reset_b is the TDC's run enable, so hit self-clears when the run ends.} -1280 -580 0 0 0.35 0.35 {}
N -410 -20 -370 -20 {lab=slow_enable}
N -290 -20 -250 -20 {lab=#net2}
N -170 -20 -130 -20 {lab=#net3}
N -50 -20 30 -20 {lab=#net1}
N -400 0 30 0 {lab=fast_enable}
N 210 -20 280 -20 {lab=hit}
N -390 20 30 20 {lab=reset_b}
C {sg13g2_dfrbpq_1.sym} 120 0 0 0 {name=x1 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dlygate4sd3_1.sym} -330 -20 0 0 {name=x2 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dlygate4sd2_1.sym} -210 -20 0 0 {name=x3 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dlygate4sd2_1.sym} -90 -20 0 0 {name=x4 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {ipin.sym} -410 -20 0 0 {name=p1 lab=slow_enable}
C {ipin.sym} -400 0 0 0 {name=p2 lab=fast_enable}
C {ipin.sym} -390 20 0 0 {name=p3 lab=reset_b}
C {opin.sym} 280 -20 0 0 {name=p4 lab=hit}
