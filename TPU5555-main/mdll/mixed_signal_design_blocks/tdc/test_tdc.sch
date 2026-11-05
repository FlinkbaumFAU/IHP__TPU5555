v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
B 2 340 -620 1140 -220 {flags=graph
y1=-0.059
y2=1.3
ypos1=0.10517622
ypos2=0.75224327
divy=5
subdivy=1
unity=1
x1=4.7361679e-09
x2=6.4574706e-09
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0
node="clk_out
clk_ref
tdc_f;tdc_f[7], tdc_f[6], tdc_f[5], tdc_f[4], tdc_f[3], tdc_f[2], tdc_f[1], tdc_f[0]
tdc_s;tdc_s[7], tdc_s[6], tdc_s[5], tdc_s[4], tdc_s[3], tdc_s[2], tdc_s[1], tdc_s[0]"
color="4 5 6 7"
dataset=-1
unitx=1
logx=0
logy=0
digital=1}
B 2 340 -130 1140 270 {flags=graph
y1=1.1008
y2=3.9328
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=4.7361679e-09
x2=6.4574706e-09
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0
dataset=-1
unitx=1
logx=0
logy=0
color="4 5 6"
node="OS;x1.os 1.5 +
OF;x1.of 1.5 +
detect;x1.detect"}
T {Vernier TDC testbench.

Clk_out runs at 400 MHz, Clk_ref at 100 MHz. Sel pulses once per reference
period, just after a Clk_out edge, the way clk_gen's selector fires after div.
x1 arms on every second Sel. After arming, the first Clk_out edge (3.5 ns,
23.5 ns, ...) starts the slow ring. Clk_ref is placed DT after that edge and
starts the fast ring, so DT is the interval being measured.

Expected with the rings as trimmed (T_slow ~1056 ps, dT ~17.8 ps):
  DT < t_buf        -> hit = 1, no Vernier run
  DT > t_buf        -> tdc_s*T_slow - tdc_f*T_fast ~ DT
  and a new capture every run, re-armed every second Sel.} -340 -730 0 0 0.35 0.35 {}
N -570 -120 -520 -120 {lab=Clk_out}
N -680 -120 -630 -120 {lab=VSS}
N -570 -40 -520 -40 {lab=Clk_ref}
N -680 -40 -630 -40 {lab=VSS}
N -570 40 -520 40 {lab=Sel}
N -680 40 -630 40 {lab=VSS}
N -570 120 -520 120 {lab=Start}
N -680 120 -630 120 {lab=VSS}
C {tdc/src/tdc.sym} 0 0 0 0 {name=x1 VDD=VDD VSS=VSS}
C {lab_pin.sym} -150 -60 0 0 {name=p1 sig_type=std_logic lab=Clk_out}
C {lab_pin.sym} -150 -20 0 0 {name=p2 sig_type=std_logic lab=Clk_ref}
C {lab_pin.sym} -150 20 0 0 {name=p3 sig_type=std_logic lab=Sel}
C {lab_pin.sym} -150 60 0 0 {name=p4 sig_type=std_logic lab=Start}
C {lab_pin.sym} 150 -60 2 0 {name=p5 sig_type=std_logic lab=tdc_s[7:0]}
C {lab_pin.sym} 150 -20 2 0 {name=p6 sig_type=std_logic lab=tdc_f[7:0]}
C {lab_pin.sym} 150 20 2 0 {name=p7 sig_type=std_logic lab=hit}
C {lab_pin.sym} 150 60 2 0 {name=p8 sig_type=std_logic lab=valid}
C {lab_pin.sym} 150 80 2 0 {name=p9 sig_type=std_logic lab=busy}
C {vsource.sym} -600 -120 1 0 {name=VCO value="PULSE(0 \{VDD\} 1n \{CT\} \{CT\} 1.25n 2.5n)" savecurrent=false}
C {lab_pin.sym} -520 -120 2 0 {name=p20 sig_type=std_logic lab=Clk_out}
C {lab_pin.sym} -680 -120 0 0 {name=p21 sig_type=std_logic lab=VSS}
C {vsource.sym} -600 -40 1 0 {name=VREF value="PULSE(0 \{VDD\} \{3.5n+DT\} \{CT\} \{CT\} 5n 10n)" savecurrent=false}
C {lab_pin.sym} -520 -40 2 0 {name=p22 sig_type=std_logic lab=Clk_ref}
C {lab_pin.sym} -680 -40 0 0 {name=p23 sig_type=std_logic lab=VSS}
C {vsource.sym} -600 40 1 0 {name=VSEL value="PULSE(0 \{VDD\} 1.15n \{CT\} \{CT\} 0.4n 10n)" savecurrent=false}
C {lab_pin.sym} -520 40 2 0 {name=p24 sig_type=std_logic lab=Sel}
C {lab_pin.sym} -680 40 0 0 {name=p25 sig_type=std_logic lab=VSS}
C {vsource.sym} -600 120 1 0 {name=VSTART value="PWL(0 0 0.5n 0 0.53n \{VDD\})" savecurrent=false}
C {lab_pin.sym} -520 120 2 0 {name=p26 sig_type=std_logic lab=Start}
C {lab_pin.sym} -680 120 0 0 {name=p27 sig_type=std_logic lab=VSS}
C {code_shown.sym} -1500 -700 0 0 {name=LIB only_toplevel=false value="tcleval(
* This block is tcleval()'d: xschem runs it through tcl subst when writing the
* netlist. A stray dollar sign or open bracket is therefore a tcl error, and a
* failed tcleval turns the WHOLE block into a single question mark, silently.
* tdc/Makefile greps the netlist for it. See CLAUDE.md.

* counter.spice is generated from the synthesised netlist, not drawn, so the
* Netlist button rebuilds it here. rc=0 is success; otherwise read
* tdc/build/mk_counter.log and expect a stale model below.
* mk counter.spice rc=[file mkdir $env(MSDB_ROOT)/tdc/build][catch \{exec make -s -C $env(MSDB_ROOT)/tdc simulations/counter.spice >& $env(MSDB_ROOT)/tdc/build/mk_counter.log\}]

.LIB cornerMOSlv.lib mos_tt
.OPTIONS KLU
.INCLUDE sg13g2_stdcell.spice
.INCLUDE custom_stdcell.spice
.INCLUDE $env(MSDB_ROOT)/tdc/simulations/counter.spice

.control
  setcs rawfile = $env(MSDB_ROOT)/tdc/simulations/test_tdc.raw
.endc
.PARAM VDD=1.2
.PARAM CT=30p
.PARAM DT=400p
.TEMP 27
)"
place=header}
C {code_shown.sym} -1500 0 0 0 {name=CODE only_toplevel=false value="
VVDD VDD 0 DC \{VDD\}
VVSS VSS 0 0

.control
  set filetype=ascii
  save Clk_out Clk_ref Sel Start hit valid busy
  save tdc_s[7] tdc_s[6] tdc_s[5] tdc_s[4] tdc_s[3] tdc_s[2] tdc_s[1] tdc_s[0]
  save tdc_f[7] tdc_f[6] tdc_f[5] tdc_f[4] tdc_f[3] tdc_f[2] tdc_f[1] tdc_f[0]
  save x1.OS x1.OF x1.Detect x1.hit_raw x1.cap_clk x1.Reset
  tran 5p 50n
  * Not tcleval()'d: the save list names bus bits with brackets.
  write $rawfile
  quit
.endc
"}
