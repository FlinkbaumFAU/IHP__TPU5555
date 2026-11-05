v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
B 2 510 -600 1310 -200 {flags=graph
y1=0.70130458
y2=4.5295572
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=5.7459511e-07
x2=5.9489442e-07
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0
node="clk_ref; \\"clk_ref 3 +\\"
clk_out; \\"clk_out 3 +\\"
div_out; \\"div 1.5 +\\"
comp; comp 1.5 +"
color="4 5 6 4"
dataset=-1
unitx=1
logx=0
logy=0
digital=0}
B 2 510 -190 1310 210 {flags=graph
y1=0
ypos1=-0.6526826
ypos2=0.36502491
divy=5
subdivy=1
unity=1
x1=5.7459511e-07
x2=5.9489442e-07
divx=5
subdivx=1
xlabmag=1.0
ylabmag=1.0
node="c;c[7],c[6],c[5],c[4],c[3],c[2],c[1],c[0]"
color=4
dataset=-1
unitx=1
logx=0
logy=0
digital=1
y2=1.2}
T {Closed-loop MDLL: clk_gen (DCO + select logic + divide-by-4) with bbpd
(binary phase comparator + loop-filter accumulator) closing the loop.

This is the acceptance gate for the phase-detector rework. Everything else
-- the formal proof of the accumulator, the SAT equivalence, the comparator
polarity sweep -- checks a piece in isolation. Only this checks that the
pieces are hooked up in the direction that makes the loop converge.

The C[7:0] feedback from x2 to x1 IS the loop. div is the other half of it:
clk_gen holds the divider in reset for the whole injection pulse, so div
rises exactly 4 DCO periods after injection release and comparing it with
the next clk_ref edge is the sign of 4*T_DCO - T_REF.} -1000 -560 0 0 0.4 0.4 {}
N -200 -30 -150 -30 {lab=clk_ref}
N -200 -10 -150 -10 {lab=C[7:0] bus=true}
N -200 10 -150 10 {lab=sel}
N -200 30 -150 30 {lab=Resetb}
N 150 -30 200 -30 {lab=clk_out}
N 150 30 200 30 {lab=div}
N -180 260 -130 260 {lab=clk_ref}
N -180 280 -130 280 {lab=div}
N -180 300 -130 300 {lab=Resetb}
N -180 320 -130 320 {lab=load}
N -180 340 -130 340 {lab=seed[7:0] bus=true}
N 130 280 180 280 {lab=C[7:0] bus=true}
N 130 320 180 320 {lab=comp}
N -660 -120 -610 -120 {lab=clk_ref}
N -770 -120 -720 -120 {lab=VSS}
N -660 -40 -610 -40 {lab=Resetb}
N -770 -40 -720 -40 {lab=VSS}
N -660 40 -610 40 {lab=load}
N -770 40 -720 40 {lab=VSS}
N -660 160 -610 160 {lab=seed[7]}
N -770 160 -720 160 {lab=VSS}
N -660 240 -610 240 {lab=seed[6]}
N -770 240 -720 240 {lab=VSS}
N -660 320 -610 320 {lab=seed[5]}
N -770 320 -720 320 {lab=VSS}
N -660 400 -610 400 {lab=seed[4]}
N -770 400 -720 400 {lab=VSS}
N -660 480 -610 480 {lab=seed[3]}
N -770 480 -720 480 {lab=VSS}
N -660 560 -610 560 {lab=seed[2]}
N -770 560 -720 560 {lab=VSS}
N -660 640 -610 640 {lab=seed[1]}
N -770 640 -720 640 {lab=VSS}
N -660 720 -610 720 {lab=seed[0]}
N -770 720 -720 720 {lab=VSS}
C {clk_gen/clk_gen.sym} 0 0 0 0 {name=x1}
C {vsource.sym} -690 -120 1 0 {name=Vref value="PULSE(0 \{VDD\} 0 \{CT\} \{CT\} \{T_REF/2\} \{T_REF\})" savecurrent=false}
C {lab_pin.sym} -610 -120 2 0 {name=p50 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -770 -120 0 0 {name=p51 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 -40 1 0 {name=Vrst value="PWL(0 0 \{T_RESET\} 0 \{T_RESET+CT\} \{VDD\})" savecurrent=false}
C {lab_pin.sym} -610 -40 2 0 {name=p52 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} -770 -40 0 0 {name=p53 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 40 1 0 {name=Vld value="PWL(0 0 \{T_RESET\} 0 \{T_RESET+CT\} \{VDD\} \{T_LOAD\} \{VDD\} \{T_LOAD+CT\} 0)" savecurrent=false}
C {lab_pin.sym} -610 40 2 0 {name=p54 sig_type=std_logic lab=load}
C {lab_pin.sym} -770 40 0 0 {name=p55 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 160 1 0 {name=Vs7 value="\{VDD*s7\}" savecurrent=false}
C {lab_pin.sym} -610 160 2 0 {name=p56 sig_type=std_logic lab=seed[7]}
C {lab_pin.sym} -770 160 0 0 {name=p57 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 240 1 0 {name=Vs6 value="\{VDD*s6\}" savecurrent=false}
C {lab_pin.sym} -610 240 2 0 {name=p58 sig_type=std_logic lab=seed[6]}
C {lab_pin.sym} -770 240 0 0 {name=p59 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 320 1 0 {name=Vs5 value="\{VDD*s5\}" savecurrent=false}
C {lab_pin.sym} -610 320 2 0 {name=p60 sig_type=std_logic lab=seed[5]}
C {lab_pin.sym} -770 320 0 0 {name=p61 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 400 1 0 {name=Vs4 value="\{VDD*s4\}" savecurrent=false}
C {lab_pin.sym} -610 400 2 0 {name=p62 sig_type=std_logic lab=seed[4]}
C {lab_pin.sym} -770 400 0 0 {name=p63 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 480 1 0 {name=Vs3 value="\{VDD*s3\}" savecurrent=false}
C {lab_pin.sym} -610 480 2 0 {name=p64 sig_type=std_logic lab=seed[3]}
C {lab_pin.sym} -770 480 0 0 {name=p65 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 560 1 0 {name=Vs2 value="\{VDD*s2\}" savecurrent=false}
C {lab_pin.sym} -610 560 2 0 {name=p66 sig_type=std_logic lab=seed[2]}
C {lab_pin.sym} -770 560 0 0 {name=p67 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 640 1 0 {name=Vs1 value="\{VDD*s1\}" savecurrent=false}
C {lab_pin.sym} -610 640 2 0 {name=p68 sig_type=std_logic lab=seed[1]}
C {lab_pin.sym} -770 640 0 0 {name=p69 sig_type=std_logic lab=VSS}
C {vsource.sym} -690 720 1 0 {name=Vs0 value="\{VDD*s0\}" savecurrent=false}
C {lab_pin.sym} -610 720 2 0 {name=p70 sig_type=std_logic lab=seed[0]}
C {lab_pin.sym} -770 720 0 0 {name=p71 sig_type=std_logic lab=VSS}
C {vdd.sym} -300 -120 0 0 {name=l1 lab=VDD}
C {gnd.sym} -260 -120 0 0 {name=l2 lab=VSS}
C {bbpd/src/bbpd.sym} 0 300 0 0 {name=x2}
C {lab_pin.sym} -200 -30 0 0 {name=p1 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -200 -10 0 0 {name=p2 sig_type=std_logic lab=C[7:0]}
C {lab_pin.sym} -200 10 0 0 {name=p3 sig_type=std_logic lab=sel}
C {lab_pin.sym} -200 30 0 0 {name=p4 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} 200 -30 2 0 {name=p5 sig_type=std_logic lab=clk_out}
C {lab_pin.sym} 200 30 2 0 {name=p6 sig_type=std_logic lab=div}
C {lab_pin.sym} -180 260 0 0 {name=p7 sig_type=std_logic lab=clk_ref}
C {lab_pin.sym} -180 280 0 0 {name=p8 sig_type=std_logic lab=div}
C {lab_pin.sym} -180 300 0 0 {name=p9 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} -180 320 0 0 {name=p10 sig_type=std_logic lab=load}
C {lab_pin.sym} -180 340 0 0 {name=p11 sig_type=std_logic lab=seed[7:0]}
C {lab_pin.sym} 180 280 2 0 {name=p12 sig_type=std_logic lab=C[7:0]}
C {lab_pin.sym} 180 320 2 0 {name=p13 sig_type=std_logic lab=comp}
C {code_shown.sym} -2380 -740 0 0 {name=LIB only_toplevel=false value="tcleval(
* This whole block is tcleval()'d: xschem runs it through tcl subst when it
* writes the netlist, so env lookups and command substitutions below are
* expanded. The flip side is that a stray dollar sign or open bracket is a tcl
* error, and a failed tcleval turns the ENTIRE block into a single question
* mark -- silently. That is why the save list, which names the C bus bit by
* bit, lives in the CODE block instead, and why these comments are so careful.
* bbpd/Makefile greps the netlist for that question mark.

* dlf.spice is not a schematic: it is generated from build/01-synth/dlf.v by
* common/sim/gen_rtl_spice.py, which in turn needs yosys to have run. xschem's
* Netlist button knows nothing about that chain, so it is resolved here. rc=0 is
* success; on rc=1 read bbpd/build/mk_dlf.log and expect a stale dlf.spice below.
* mk dlf.spice rc=[file mkdir $env(MSDB_ROOT)/bbpd/build][catch \{exec make -s -C $env(MSDB_ROOT)/bbpd simulations/dlf.spice >& $env(MSDB_ROOT)/bbpd/build/mk_dlf.log\}]

.LIB cornerMOSlv.lib mos_tt
.OPTIONS KLU
.INCLUDE sg13g2_stdcell.spice
.INCLUDE custom_stdcell.spice

* Absolute, assembled from MSDB_ROOT (exported by tools/xschem) when the netlist
* is written -- the .sch stores the expression, not the path, so the checkout
* stays portable. A relative include cannot work here because the two ways of
* running this deck have different working directories: make runs ngspice from
* bbpd/, while xschem's Simulate button runs it from netlist_dir, which xschemrc
* derives from the working directory -- and the wrapper makes that the REPO ROOT.
.INCLUDE $env(MSDB_ROOT)/clk_gen/simulations/dco_decode.spice
.INCLUDE $env(MSDB_ROOT)/bbpd/simulations/dlf.spice

* Same reason for the raw file, and the same restriction on brackets -- so the
* path is handed to the CODE block as an ngspice variable. setcs, not set: set
* lower-cases its value, and the repo path has capitals in it.
.control
  setcs rawfile = $env(MSDB_ROOT)/bbpd/simulations/test_fine_loop.raw
.endc
.PARAM VDD=1.2
.PARAM T_REF=10n
.PARAM CT=50p
.PARAM T_RESET=1n
.PARAM T_LOAD=T_REF+2n
* Seeded on the FAST side of lock (DCO code 15; lock is 18..19 at tt). A
* ring clearly late -- div missing, or past T_REF/2 -- reads as early in pd
* and walks the code the wrong way; in the MDLL lock_ctrl restarts acquisition
* then (missed injections, code at a rail). bbpd alone has no such guard.
.PARAM SEED=60
.TEMP 27

* SEED bit by bit, for the Vs7..Vs0 sources. ngspice has no bitwise operators
* in .param, so each bit is int(SEED/2^k) - 2*int(SEED/2^(k+1)). These live in
* the header because xschem emits component instances before the user-code
* block, and the sources reference them.
.param s0=\{int(SEED/1)-2*int(SEED/2)\}
.param s1=\{int(SEED/2)-2*int(SEED/4)\}
.param s2=\{int(SEED/4)-2*int(SEED/8)\}
.param s3=\{int(SEED/8)-2*int(SEED/16)\}
.param s4=\{int(SEED/16)-2*int(SEED/32)\}
.param s5=\{int(SEED/32)-2*int(SEED/64)\}
.param s6=\{int(SEED/64)-2*int(SEED/128)\}
.param s7=\{int(SEED/128)-2*int(SEED/256)\}
)"
place=header}
C {code_shown.sym} -2390 280 0 0 {name=CODE only_toplevel=false value="
VVDD VDD 0 DC \{VDD\}
VVSS VSS 0 0

.control
  set filetype=ascii
  save clk_ref clk_out div sel comp C[7] C[6] C[5] C[4] C[3] C[2] C[1] C[0]
  tran 10p 400n
  * ASCII raw, not wrdata. wrdata cannot take a bracketed node name without
  * quotes, and a quote cannot survive xschem's value=... attribute without
  * escaping -- unescaped it truncates the control block, and the deck then
  * runs the whole transient before losing it. The raw file carries every
  * saved vector under its real name and simulations/check_lock.py reads it
  * directly.
  *
  * rawfile is set by the header block; see the comment there. This block is
  * deliberately NOT tcleval()'d -- the save list above names C[7]..C[0], and tcl
  * would read those brackets as command substitution.
  write $rawfile
  quit
.endc
"}
