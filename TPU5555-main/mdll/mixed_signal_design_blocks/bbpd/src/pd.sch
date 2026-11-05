v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Binary phase comparator -- the paper's BBPD.

x1  samples clk_ref on the DIVIDER edge. div rises exactly N=4 DCO periods
    after the injection pulse releases the divider reset, so comp_raw is the
    sign of 4*T_DCO - T_REF:
        1 = div late  -> ring too slow
        0 = div early -> ring too fast
    There is no dead zone. The flop is ambiguous only when the two edges
    coincide, which IS the lock point and is exactly where a bang-bang
    detector should dither.

x2  retimes comp_raw ~0.4 ns after clk_ref (x7), and dlf updates the code
    ~1.2 ns after it (clk_dlf, x8..x10): the decision on a run acts on the
    very next run, not the one after (lock_ctrl/simul/sweep_variants.py).
    That leaves x1/x2 only a few tau to resolve (tau ~56 ps tt, ~100 ps ss,
    simulations/char_meta.py), so comp is routinely unresolved when dlf
    samples it. dlf is built for that: Gray state, comp reaching at most two
    bits through AND gates, any outcome within +-2 LSB (rtl/dlf.v).
    x1 is deliberately the small cell -- the less its own clock and data pins
    are loaded, the narrower its metastability window.

x7..x10 are delay cells (dlygate4sd3) and a buffer, not a clock tree: they scale with
    PVT like the logic they wait for (lock_ctrl's load/seed: 0.81 ns tt,
    1.28 ns ss) and LibreLane runs no CTS on this block. x10 drives dlf's 17
    flops. clk_ref_d (x6) clocks dlf's re-register of load/seed.

x6  buffers clk_ref for everything EXCEPT x1: the delay chains and, via
    clk_ref_d, dlf's re-register. The clk_ref pin then sees x1/D + one buf_2
    input (~4 fF) instead of ~49 fF, close to the div pin's x1/CLK. mdll.sch
    makes clk_ref_g with a replica of the gates div leaves clk_gen through;
    that only cancels if both drive the same load here and at the tdc.} -1700 -550 0 0 0.4 0.4 {}
N -420 -20 -90 -20 {lab=div}
N -420 0 -90 0 {lab=clk_ref}
N 90 -20 140 -20 {lab=comp_raw}
N -200 160 110 160 {lab=clk_x2}
N 460 30 510 30 {lab=comp}
N 140 -20 140 50 {lab=comp_raw}
N 110 30 110 160 {lab=clk_x2}
N 110 30 280 30 {lab=clk_x2}
N -270 20 -90 20 {lab=resetb}
N -300 160 -280 160 {lab=clk_ref_d}
N -360 90 -340 90 {lab=clk_ref}
N -260 90 -220 90 {lab=clk_ref_d}
N -270 20 -270 70 {lab=resetb}
N -270 70 280 70 {lab=resetb}
N 260 50 280 50 {lab=comp_raw}
C {sg13g2_dfrbpq_1.sym} 0 0 0 0 {name=x1 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dfrbpq_2.sym} 370 50 0 0 {name=x2 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dlygate4sd3_1.sym} -240 160 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {ipin.sym} -420 -20 0 0 {name=p1 lab=div}
C {ipin.sym} -420 0 0 0 {name=p2 lab=clk_ref}
C {ipin.sym} -270 20 0 0 {name=p3 lab=resetb}
C {opin.sym} 510 30 0 0 {name=p4 lab=comp}
C {lab_pin.sym} 140 -20 2 0 {name=p5 sig_type=std_logic lab=comp_raw}
C {lab_pin.sym} 110 160 2 0 {name=p10 sig_type=std_logic lab=clk_x2}
C {lab_pin.sym} 260 50 0 0 {name=p6 sig_type=std_logic lab=comp_raw}
C {sg13g2_buf_2.sym} -300 90 0 0 {name=x6 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -360 90 0 0 {name=p15 sig_type=std_logic lab=clk_ref}
C {opin.sym} -220 90 0 0 {name=p16 lab=clk_ref_d}
C {lab_pin.sym} -300 160 0 0 {name=p17 sig_type=std_logic lab=clk_ref_d}
N -320 260 -280 260 {lab=clk_x2}
N -200 260 -160 260 {lab=dly1}
N -80 260 -40 260 {lab=dly2}
N 40 260 120 260 {lab=clk_dlf}
C {sg13g2_dlygate4sd3_1.sym} -240 260 0 0 {name=x8 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_dlygate4sd3_1.sym} -120 260 0 0 {name=x9 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_buf_4.sym} 0 260 0 0 {name=x10 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -320 260 0 0 {name=p18 sig_type=std_logic lab=clk_x2}
C {opin.sym} 120 260 0 0 {name=p19 lab=clk_dlf}
