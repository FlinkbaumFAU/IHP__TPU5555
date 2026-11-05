v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {MDLL top level.

clk_gen   gated ring: N=4 DCO periods from each injection, then div, then it
          waits for clk_ref. The wait e = T_REF - 4*T_DCO is the frequency error.
tdc       measures e: slow ring started by div, fast ring by the next clk_ref.
          Armed by lock_ctrl (tdc_sel), not by clk_ref, so a run only starts
          when one is asked for -- see lock_ctrl/rtl/lock_ctrl.v.
bbpd      pd samples the sign of e every reference period; dlf integrates it
          into code[7:0], or takes lock_ctrl's seed while load is high.
lock_ctrl forces the fastest code, jumps the code by K*e per TDC reading, and
          hands over to the bang-bang loop (locked) on hit or once a jump
          would be smaller than one DCO step.

Unused outputs end in noconn so that any other single-pin net is still an
error: tdc.valid (sticky, superseded by the busy handshake) and bbpd.comp
(consumed inside bbpd). clk_gen.sel is the injection window: it rises about
half a DCO period before div and stays high until just after the injecting
clk_ref edge, so lock_ctrl arms the TDC only on edges that inject (inj_sel)
and, once locked, restarts acquisition when edges stop injecting.

x5..x8: clk_ref replica. div leaves clk_gen through an integrated clock gate
and a buffer (divider x5 lgcp_1 -> x9 buf_4), with the divider's self-clear
x7 (a nor2b_1 input) on div. The TDC and the bbpd compare div against clk_ref,
so clk_ref reaches both through the same chain: x5 (lgcp_1, always enabled by
the tie x6) -> x7 (buf_4) -> clk_ref_g, and x8 (nor2b_1, output unused) puts
the self-clear's input load on clk_ref_g. Same cells, same loads -- the tdc's
Clk_out/Clk_ref and the bbpd's div/clk_ref pins are matched inside the blocks
-- so the delay cancels instead of becoming a static error in e (checked
post-layout by `make match_report`). clk_gen (injection) and lock_ctrl keep
the raw clk_ref.} -1560 -580 0 0 0.35 0.35 {}
T {x9..x13: start controller. The external resetb is asynchronous; released
as it was, mid-period, the ring started a run at the release itself (sel falls
with Resetb, selector.sch x5) and the divider counted from there, while dlf
still stepped its reset code -- the first div came from a run of mixed codes
that began nowhere near a clk_ref edge.

x9, x10  synchroniser on the RISING clk_ref -> rstb_gen (clk_gen). It rises
         clk-to-q after a rising clk_ref edge, which is a normal injection: in
         reset sel is forced high, so M_outb already follows clk_ref, and the
         ring end ring_p still holds its low-half level (high) until the edge
         has gone round, about T_DCO/2 later. sel may fall anywhere in that
         window without a glitch, exactly as it does after an injecting edge.
         Released in the low half instead, the ring would start at the release.
x12      falling clk_ref, D = rstb_gen -> rstb_ctl (lock_ctrl, bbpd/dlf), half
         a period later. lock_ctrl must not run while clk_gen is in reset: sel
         is forced high there and would look like an injecting edge. Its first
         edge is the one after the ring's first run.
dlf resets to code START (lock_ctrl's), with load/seed re-registers preset to
load START, so the first run is already at START: bbpd/rtl/dlf.v.} -1560 300 0 0 0.35 0.35 {}
C {sg13g2_tiehi.sym} -1000 520 0 0 {name=x13 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -1000 520 2 0 {name=p222 sig_type=std_logic lab=start_one}
C {sg13g2_dfrbp_1.sym} -800 600 0 0 {name=x9 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -890 580 0 0 {name=p223 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -890 600 0 0 {name=p224 sig_type=std_logic lab=start_one}
C {lab_pin.sym} -890 620 0 0 {name=p225 sig_type=std_logic lab=resetb}
C {lab_pin.sym} -710 580 2 0 {name=p226 sig_type=std_logic lab=rstb_s1}
C {noconn.sym} -710 600 2 0 {name=l27}
C {sg13g2_dfrbp_1.sym} -800 720 0 0 {name=x10 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -890 700 0 0 {name=p227 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -890 720 0 0 {name=p228 sig_type=std_logic lab=rstb_s1}
C {lab_pin.sym} -890 740 0 0 {name=p229 sig_type=std_logic lab=resetb}
C {lab_pin.sym} -710 700 2 0 {name=p230 sig_type=std_logic lab=rstb_gen}
C {noconn.sym} -710 720 2 0 {name=l28}
C {sg13g2_inv_1.sym} -960 860 0 0 {name=x11 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -1000 860 0 0 {name=p231 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -920 860 2 0 {name=p232 sig_type=std_logic lab=clk_ref_n}
C {sg13g2_dfrbp_1.sym} -800 840 0 0 {name=x12 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -890 820 0 0 {name=p233 sig_type=std_logic lab=clk_ref_n}
C {lab_pin.sym} -890 840 0 0 {name=p234 sig_type=std_logic lab=rstb_gen}
C {lab_pin.sym} -890 860 0 0 {name=p235 sig_type=std_logic lab=resetb}
C {lab_pin.sym} -710 820 2 0 {name=p236 sig_type=std_logic lab=rstb_ctl}
C {noconn.sym} -710 840 2 0 {name=l29}
C {clk_gen/clk_gen.sym} 0 0 0 0 {name=x1}
C {lab_pin.sym} -150 -30 0 0 {name=p1 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -150 -10 0 0 {name=p2 sig_type=std_logic lab=code[7:0]}
C {lab_pin.sym} -150 10 0 0 {name=p3 sig_type=std_logic lab=inj_sel}
C {lab_pin.sym} -150 30 0 0 {name=p5 sig_type=std_logic lab=rstb_gen}
C {lab_pin.sym} 150 -30 2 0 {name=p6 sig_type=std_logic lab=clk_out}
C {lab_pin.sym} 150 30 2 0 {name=p7 sig_type=std_logic lab=div}
C {tdc/src/tdc.sym} 700 0 0 0 {name=x2 VDD=VDD VSS=VSS}
C {lab_pin.sym} 550 -60 0 0 {name=p8 sig_type=std_logic lab=div}
C {lab_pin.sym} 550 -20 0 0 {name=p9 sig_type=std_logic lab=clk_ref_g}
C {lab_pin.sym} 550 20 0 0 {name=p10 sig_type=std_logic lab=tdc_sel}
C {lab_pin.sym} 550 60 0 0 {name=p11 sig_type=std_logic lab=tdc_start}
C {lab_pin.sym} 850 -60 2 0 {name=p12 sig_type=std_logic lab=tdc_s[7:0]}
C {lab_pin.sym} 850 -20 2 0 {name=p13 sig_type=std_logic lab=tdc_f[7:0]}
C {lab_pin.sym} 850 20 2 0 {name=p14 sig_type=std_logic lab=hit}
C {lab_pin.sym} 850 60 2 0 {name=p15 sig_type=std_logic lab=tdc_valid}
C {noconn.sym} 850 60 0 0 {name=l16}
C {lab_pin.sym} 850 80 2 0 {name=p17 sig_type=std_logic lab=busy}
C {bbpd/src/bbpd.sym} 0 400 0 0 {name=x3}
C {lab_pin.sym} -130 360 0 0 {name=p18 sig_type=std_logic lab=clk_ref_g}
C {lab_pin.sym} -130 380 0 0 {name=p19 sig_type=std_logic lab=div}
C {lab_pin.sym} -130 400 0 0 {name=p20 sig_type=std_logic lab=rstb_ctl}
C {lab_pin.sym} -130 420 0 0 {name=p21 sig_type=std_logic lab=load}
C {lab_pin.sym} -130 440 0 0 {name=p22 sig_type=std_logic lab=seed[7:0]}
C {lab_pin.sym} 130 380 2 0 {name=p23 sig_type=std_logic lab=code[7:0]}
C {lab_pin.sym} 130 420 2 0 {name=p24 sig_type=std_logic lab=comp}
C {noconn.sym} 130 420 0 0 {name=l25}
C {lock_ctrl/src/lock_ctrl.sym} 700 400 0 0 {name=x4}
C {ipin.sym} -500 -100 0 0 {name=p100 lab=clk_ref}
C {ipin.sym} -500 -60 0 0 {name=p101 lab=resetb}
C {opin.sym} -400 -100 0 0 {name=p102 lab=clk_out}
C {opin.sym} -400 -60 0 0 {name=p103 lab=locked}
C {opin.sym} -400 -20 0 0 {name=p104 lab=code[7:0]}
C {lab_pin.sym} 580 260 0 0 {name=p201 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} 580 300 0 0 {name=p202 sig_type=std_logic lab=rstb_ctl}
C {lab_pin.sym} 580 340 0 0 {name=p203 sig_type=std_logic lab=inj_sel}
C {lab_pin.sym} 580 380 0 0 {name=p204 sig_type=std_logic lab=busy}
C {lab_pin.sym} 580 420 0 0 {name=p205 sig_type=std_logic lab=hit}
C {lab_pin.sym} 580 460 0 0 {name=p206 sig_type=std_logic lab=tdc_s[7:0]}
C {lab_pin.sym} 580 500 0 0 {name=p207 sig_type=std_logic lab=tdc_f[7:0]}
C {lab_pin.sym} 580 540 0 0 {name=p208 sig_type=std_logic lab=code[7:0]}
C {lab_pin.sym} 820 260 2 0 {name=p209 sig_type=std_logic lab=tdc_start}
C {lab_pin.sym} 820 300 2 0 {name=p210 sig_type=std_logic lab=tdc_sel}
C {lab_pin.sym} 820 340 2 0 {name=p211 sig_type=std_logic lab=load}
C {lab_pin.sym} 820 380 2 0 {name=p212 sig_type=std_logic lab=seed[7:0]}
C {lab_pin.sym} 820 420 2 0 {name=p213 sig_type=std_logic lab=locked}
C {sg13g2_lgcp_1.sym} -300 -300 0 0 {name=x5 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -390 -310 0 0 {name=p214 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -390 -290 0 0 {name=p215 sig_type=std_logic lab=ref_gate}
C {lab_pin.sym} -210 -310 2 0 {name=p216 sig_type=std_logic lab=clk_ref_x5}
C {sg13g2_buf_4.sym} -130 -310 0 0 {name=x7 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -170 -310 0 0 {name=p218 sig_type=std_logic lab=clk_ref_x5}
C {lab_pin.sym} -90 -310 2 0 {name=p219 sig_type=std_logic lab=clk_ref_g}
C {sg13g2_nor2b_1.sym} -130 -200 0 0 {name=x8 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -190 -220 0 0 {name=p220 sig_type=std_logic lab=clk_ref_g}
C {lab_pin.sym} -190 -180 0 0 {name=p221 sig_type=std_logic lab=ref_gate}
C {noconn.sym} -70 -200 2 0 {name=l26}
C {sg13g2_tiehi.sym} -450 -200 0 0 {name=x6 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} -450 -200 2 0 {name=p217 sig_type=std_logic lab=ref_gate}
