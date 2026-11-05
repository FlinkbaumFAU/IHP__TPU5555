v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
B 2 530 -700 1330 -300 {flags=graph
y1=0
ypos1=0.12
ypos2=1.32
divy=5
subdivy=1
unity=1
x1=4.2370223e-07
x2=4.3382242e-07
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0
node="code;code[7],code[6],code[5],code[4],code[3],code[2],code[1],code[0]
seed;x1.seed[7],x1.seed[6],x1.seed[5],x1.seed[4],x1.seed[3],x1.seed[2],x1.seed[1],x1.seed[0]
tdc_start;x1.tdc_start
tdc_f;x1.tdc_f[7],x1.tdc_f[6],x1.tdc_f[5],x1.tdc_f[4],x1.tdc_f[3],x1.tdc_f[2],x1.tdc_f[1],x1.tdc_f[0]
tdc_s;x1.tdc_s[7],x1.tdc_s[6],x1.tdc_s[5],x1.tdc_s[4],x1.tdc_s[3],x1.tdc_s[2],x1.tdc_s[1],x1.tdc_s[0]
busy;x1.busy
tdc_sel; x1.tdc_sel
locked
resetb
hit; x1.hit"
color="4 5 6 7 8 9 10 11 12 13"
dataset=-1
unitx=1
logx=0
logy=0
digital=1
y2=1.2}
B 2 530 -300 1330 100 {flags=graph
y1=-0.8012603
y2=3.1790562
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=4.2370223e-07
x2=4.3382242e-07
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0
dataset=-1
unitx=1
logx=0
logy=0
color="4 5 6 7"
node="clk_out; clk_out 1.5 +
clk_ref; clk_ref 1.5 +
clk_ref_g; x1.clk_ref_g
div; x1.div"}
T {MDLL closed loop: acquisition from reset to lock.

After reset lock_ctrl forces code 0x00 (fastest), then jumps the code by K*e
per TDC reading until the TDC reports hit or a jump would be under one DCO
step, and hands over (locked) to the bang-bang loop in bbpd.

simulations/check_mdll.py is the acceptance gate: coarse phase bounded,
exactly one handover, final code dithering around the lock point.} -700 -400 0 0 0.35 0.35 {}
N -570 100 -520 100 {lab=clk_ref}
N -680 100 -630 100 {lab=VSS}
N -570 180 -520 180 {lab=resetb}
N -680 180 -630 180 {lab=VSS}
C {mdll.sym} 0 0 0 0 {name=x1}
C {vdd.sym} -300 -150 0 0 {name=l1 lab=VDD}
C {gnd.sym} -260 -150 0 0 {name=l2 lab=VSS}
C {lab_pin.sym} -150 -20 0 0 {name=p1 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -150 20 0 0 {name=p2 sig_type=std_logic lab=resetb}
C {lab_pin.sym} 150 -30 2 0 {name=p3 sig_type=std_logic lab=clk_out}
C {lab_pin.sym} 150 0 2 0 {name=p4 sig_type=std_logic lab=locked}
C {lab_pin.sym} 150 30 2 0 {name=p5 sig_type=std_logic lab=code[7:0]}
C {vsource.sym} -600 100 1 0 {name=Vref value="PULSE(0 \{VDD\} 0 \{CT\} \{CT\} \{T_REF/2\} \{T_REF\})" savecurrent=false}
C {lab_pin.sym} -520 100 2 0 {name=p6 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -680 100 0 0 {name=p7 sig_type=std_logic lab=VSS}
C {vsource.sym} -600 180 1 0 {name=Vrst value="PWL(0 0 \{T_RESET\} 0 \{T_RESET+CT\} \{VDD\})" savecurrent=false}
C {lab_pin.sym} -520 180 2 0 {name=p8 sig_type=std_logic lab=resetb}
C {lab_pin.sym} -680 180 0 0 {name=p9 sig_type=std_logic lab=VSS}
C {code_shown.sym} -1500 -400 0 0 {name=LIB only_toplevel=false value="tcleval(
* This block is tcleval()'d: xschem runs it through tcl subst when writing the
* netlist. A stray dollar sign or open bracket is therefore a tcl error, and a
* failed tcleval turns the WHOLE block into a single question mark, silently.
* The root Makefile greps the netlist for it. See CLAUDE.md.

* Generated models of synthesised RTL, rebuilt by the Netlist button. rc=0 is
* success; otherwise read build/mk_*.log and expect a stale model below.
* mk dco_decode.spice rc=[file mkdir $env(MSDB_ROOT)/build][catch \{exec make -s -C $env(MSDB_ROOT)/clk_gen simulations/dco_decode.spice >& $env(MSDB_ROOT)/build/mk_dco_decode.log\}]
* mk dlf.spice rc=[catch \{exec make -s -C $env(MSDB_ROOT)/bbpd simulations/dlf.spice >& $env(MSDB_ROOT)/build/mk_dlf.log\}]
* mk counter.spice rc=[catch \{exec make -s -C $env(MSDB_ROOT)/tdc simulations/counter.spice >& $env(MSDB_ROOT)/build/mk_counter.log\}]
* mk lock_ctrl.spice rc=[catch \{exec make -s -C $env(MSDB_ROOT)/lock_ctrl simulations/lock_ctrl.spice >& $env(MSDB_ROOT)/build/mk_lock_ctrl.log\}]

.LIB cornerMOSlv.lib mos_tt
.OPTIONS KLU
* RSHUNT next to KLU (CLAUDE.md): with clk_gen's inv_2 / cap_8 ring the
* operating point failed at a ring node (timestep too small) under KLU alone.
.OPTIONS RSHUNT=1e12
.INCLUDE sg13g2_stdcell.spice
.INCLUDE custom_stdcell.spice
.INCLUDE $env(MSDB_ROOT)/clk_gen/simulations/dco_decode.spice
.INCLUDE $env(MSDB_ROOT)/bbpd/simulations/dlf.spice
.INCLUDE $env(MSDB_ROOT)/tdc/simulations/counter.spice
.INCLUDE $env(MSDB_ROOT)/lock_ctrl/simulations/lock_ctrl.spice

* Handed to the CODE block as an ngspice variable: that block names bus bits,
* so it cannot be tcleval'd. setcs, not set: set lower-cases its value.
.control
  setcs rawfile = $env(MSDB_ROOT)/simulations/test_mdll.raw
.endc
.PARAM VDD=1.2
.PARAM T_REF=10n
.PARAM CT=50p
.PARAM T_RESET=1n
.TEMP 27
)"
place=header}
C {code_shown.sym} -1500 150 0 0 {name=CODE only_toplevel=false value="
VVDD VDD 0 DC \{VDD\}
VVSS VSS 0 0
* x1.div and x1.clk_ref_g: the pair the tdc and the bbpd compare (the
* replica match, pnr/match_report.py).
* The run pauses once at 300 ns (stop), writes what it has so far to
* <rawfile>.300ns -- the acquisition phase, readable hours before a long run
* ends -- then drops the breakpoint (otherwise resume would stop again at
* once, the condition still being true) and continues to the end.
.control
  set filetype=ascii
  save clk_ref clk_out locked resetb x1.div x1.clk_ref_g x1.load x1.tdc_sel x1.tdc_start x1.busy x1.hit
  save x1.rstb_gen x1.rstb_ctl x1.inj_sel
  save code[7] code[6] code[5] code[4] code[3] code[2] code[1] code[0]
  save x1.seed[7] x1.seed[6] x1.seed[5] x1.seed[4] x1.seed[3] x1.seed[2] x1.seed[1] x1.seed[0]
  save x1.tdc_s[7] x1.tdc_s[6] x1.tdc_s[5] x1.tdc_s[4] x1.tdc_s[3] x1.tdc_s[2] x1.tdc_s[1] x1.tdc_s[0]
  save x1.tdc_f[7] x1.tdc_f[6] x1.tdc_f[5] x1.tdc_f[4] x1.tdc_f[3] x1.tdc_f[2] x1.tdc_f[1] x1.tdc_f[0]
  stop when time > 300n
  tran 10p 1200n
  setcs rawpart = \{$rawfile\}.300ns
  write $rawpart
  delete all
  resume
  write $rawfile
  quit
.endc
"}
