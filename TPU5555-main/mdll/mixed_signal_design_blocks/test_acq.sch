v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
T {Open-loop acquisition timing: clk_gen at a FIXED code driving the TDC.

No feedback. The question this answers is what interval the TDC actually
measures when it is wired to clk_gen: the loop needs T_REF - 4*T_DCO (div vs.
the next clk_ref), and simulations/char_acq.py sweeps CODE and compares the
TDC reading against that.

Wired as in mdll.sch: TDC Clk_out <- div, Clk_ref <- clk_ref. Sel <- clk_ref
stands in for lock_ctrl's arming strobe (it arms on every second edge; at a
fixed fast code every edge injects, so every arm is a valid one).
Result (tt): dt = e - 30 ps at every fast code, slope 1; R = T_s/LSB ~ 60.
With Clk_out <- clk_out instead, the TDC measures nothing useful: the gated
ring does not toggle between div and the injection.} -700 -560 0 0 0.35 0.35 {}
C {clk_gen/clk_gen.sym} 0 0 0 0 {name=x1}
C {vdd.sym} -300 -200 0 0 {name=l1 lab=VDD}
C {gnd.sym} -260 -200 0 0 {name=l2 lab=VSS}
C {lab_pin.sym} -150 -30 0 0 {name=p1 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -150 -10 0 0 {name=p2 sig_type=std_logic lab=C[7:0]}
C {lab_pin.sym} -150 10 0 0 {name=p3 sig_type=std_logic lab=sel}
C {lab_pin.sym} -150 30 0 0 {name=p4 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} 150 -30 2 0 {name=p5 sig_type=std_logic lab=clk_out}
C {lab_pin.sym} 150 30 2 0 {name=p6 sig_type=std_logic lab=div}
C {tdc/src/tdc.sym} 600 0 0 0 {name=x2 VDD=VDD VSS=VSS}
C {lab_pin.sym} 450 -60 0 0 {name=p7 sig_type=std_logic lab=div}
C {lab_pin.sym} 450 -20 0 0 {name=p8 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} 450 20 0 0 {name=p9 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} 450 60 0 0 {name=p10 sig_type=std_logic lab=Start}
C {lab_pin.sym} 750 -60 2 0 {name=p11 sig_type=std_logic lab=tdc_s[7:0]}
C {lab_pin.sym} 750 -20 2 0 {name=p12 sig_type=std_logic lab=tdc_f[7:0]}
C {lab_pin.sym} 750 20 2 0 {name=p13 sig_type=std_logic lab=hit}
C {lab_pin.sym} 750 60 2 0 {name=p14 sig_type=std_logic lab=valid}
C {lab_pin.sym} 750 80 2 0 {name=p15 sig_type=std_logic lab=busy}
C {vsource.sym} -700 100 1 0 {name=Vref value="PULSE(0 \{VDD\} 0 \{CT\} \{CT\} \{T_REF/2\} \{T_REF\})" savecurrent=false}
N -670 100 -620 100 {lab=clk_ref}
N -780 100 -730 100 {lab=VSS}
C {lab_pin.sym} -620 100 2 0 {name=p16 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -780 100 0 0 {name=p17 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 180 1 0 {name=Vrst value="PWL(0 0 \{T_RESET\} 0 \{T_RESET+CT\} \{VDD\})" savecurrent=false}
N -670 180 -620 180 {lab=Resetb}
N -780 180 -730 180 {lab=VSS}
C {lab_pin.sym} -620 180 2 0 {name=p18 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} -780 180 0 0 {name=p19 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 260 1 0 {name=Vstart value="PWL(0 0 \{T_RESET\} 0 \{T_RESET+CT\} \{VDD\})" savecurrent=false}
N -670 260 -620 260 {lab=Start}
N -780 260 -730 260 {lab=VSS}
C {lab_pin.sym} -620 260 2 0 {name=p20 sig_type=std_logic lab=Start}
C {lab_pin.sym} -780 260 0 0 {name=p21 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 360 1 0 {name=Vc7 value="\{VDD*c7\}" savecurrent=false}
N -670 360 -620 360 {lab=C[7]}
N -780 360 -730 360 {lab=VSS}
C {lab_pin.sym} -620 360 2 0 {name=p22 sig_type=std_logic lab=C[7]}
C {lab_pin.sym} -780 360 0 0 {name=p23 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 440 1 0 {name=Vc6 value="\{VDD*c6\}" savecurrent=false}
N -670 440 -620 440 {lab=C[6]}
N -780 440 -730 440 {lab=VSS}
C {lab_pin.sym} -620 440 2 0 {name=p24 sig_type=std_logic lab=C[6]}
C {lab_pin.sym} -780 440 0 0 {name=p25 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 520 1 0 {name=Vc5 value="\{VDD*c5\}" savecurrent=false}
N -670 520 -620 520 {lab=C[5]}
N -780 520 -730 520 {lab=VSS}
C {lab_pin.sym} -620 520 2 0 {name=p26 sig_type=std_logic lab=C[5]}
C {lab_pin.sym} -780 520 0 0 {name=p27 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 600 1 0 {name=Vc4 value="\{VDD*c4\}" savecurrent=false}
N -670 600 -620 600 {lab=C[4]}
N -780 600 -730 600 {lab=VSS}
C {lab_pin.sym} -620 600 2 0 {name=p28 sig_type=std_logic lab=C[4]}
C {lab_pin.sym} -780 600 0 0 {name=p29 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 680 1 0 {name=Vc3 value="\{VDD*c3\}" savecurrent=false}
N -670 680 -620 680 {lab=C[3]}
N -780 680 -730 680 {lab=VSS}
C {lab_pin.sym} -620 680 2 0 {name=p30 sig_type=std_logic lab=C[3]}
C {lab_pin.sym} -780 680 0 0 {name=p31 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 760 1 0 {name=Vc2 value="\{VDD*c2\}" savecurrent=false}
N -670 760 -620 760 {lab=C[2]}
N -780 760 -730 760 {lab=VSS}
C {lab_pin.sym} -620 760 2 0 {name=p32 sig_type=std_logic lab=C[2]}
C {lab_pin.sym} -780 760 0 0 {name=p33 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 840 1 0 {name=Vc1 value="\{VDD*c1\}" savecurrent=false}
N -670 840 -620 840 {lab=C[1]}
N -780 840 -730 840 {lab=VSS}
C {lab_pin.sym} -620 840 2 0 {name=p34 sig_type=std_logic lab=C[1]}
C {lab_pin.sym} -780 840 0 0 {name=p35 sig_type=std_logic lab=VSS}
C {vsource.sym} -700 920 1 0 {name=Vc0 value="\{VDD*c0\}" savecurrent=false}
N -670 920 -620 920 {lab=C[0]}
N -780 920 -730 920 {lab=VSS}
C {lab_pin.sym} -620 920 2 0 {name=p36 sig_type=std_logic lab=C[0]}
C {lab_pin.sym} -780 920 0 0 {name=p37 sig_type=std_logic lab=VSS}
C {code_shown.sym} -1500 -560 0 0 {name=LIB only_toplevel=false value="tcleval(
* This block is tcleval()'d: xschem runs it through tcl subst when writing the
* netlist. A stray dollar sign or open bracket is therefore a tcl error, and a
* failed tcleval turns the WHOLE block into a single question mark, silently.
* The root Makefile greps the netlist for it. See CLAUDE.md.

* Generated models, rebuilt by the Netlist button. rc=0 is success; otherwise
* read the named log and expect a stale model below.
* mk dco_decode.spice rc=[file mkdir $env(MSDB_ROOT)/build][catch \{exec make -s -C $env(MSDB_ROOT)/clk_gen simulations/dco_decode.spice >& $env(MSDB_ROOT)/build/mk_dco_decode.log\}]
* mk counter.spice rc=[catch \{exec make -s -C $env(MSDB_ROOT)/tdc simulations/counter.spice >& $env(MSDB_ROOT)/build/mk_counter.log\}]

.LIB cornerMOSlv.lib mos_tt
.OPTIONS KLU
.INCLUDE sg13g2_stdcell.spice
.INCLUDE custom_stdcell.spice
.INCLUDE $env(MSDB_ROOT)/clk_gen/simulations/dco_decode.spice
.INCLUDE $env(MSDB_ROOT)/tdc/simulations/counter.spice

* Handed to the CODE block as an ngspice variable: that block names bus bits,
* so it cannot be tcleval'd. setcs, not set: set lower-cases its value.
.control
  setcs rawfile = $env(MSDB_ROOT)/simulations/test_acq.raw
.endc
.PARAM VDD=1.2
.PARAM T_REF=10n
.PARAM CT=50p
.PARAM T_RESET=\{T_REF + 0.1n\}
.PARAM CODE=0
.TEMP 27

* CODE bit by bit for Vc7..Vc0 (ngspice .param has no bitwise operators).
.param c0=\{int(CODE/1)-2*int(CODE/2)\}
.param c1=\{int(CODE/2)-2*int(CODE/4)\}
.param c2=\{int(CODE/4)-2*int(CODE/8)\}
.param c3=\{int(CODE/8)-2*int(CODE/16)\}
.param c4=\{int(CODE/16)-2*int(CODE/32)\}
.param c5=\{int(CODE/32)-2*int(CODE/64)\}
.param c6=\{int(CODE/64)-2*int(CODE/128)\}
.param c7=\{int(CODE/128)-2*int(CODE/256)\}
)"
place=header}
C {code_shown.sym} -1500 200 0 0 {name=CODE only_toplevel=false value="
VVDD VDD 0 DC \{VDD\}
VVSS VSS 0 0
.control
  set filetype=ascii
  save clk_ref clk_out div sel Resetb Start hit valid busy
  save tdc_s[7] tdc_s[6] tdc_s[5] tdc_s[4] tdc_s[3] tdc_s[2] tdc_s[1] tdc_s[0]
  save tdc_f[7] tdc_f[6] tdc_f[5] tdc_f[4] tdc_f[3] tdc_f[2] tdc_f[1] tdc_f[0]
  save x2.OS x2.OF x2.Reset x2.Detect x2.hit_raw
  tran 5p 120n
  write $rawfile
  quit
.endc
"}
