v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -150 -40 -110 -40 {lab=M_out}
N -150 0 -110 0 {lab=Div}
N -150 40 -110 40 {lab=M_outb}
N 0 80 0 120 {lab=Resetb}
N 110 -20 150 -20 {lab=Sel}
N 110 20 150 20 {lab=Selb}
N -370 -40 -350 -40 {lab=M_out}
N -450 -40 -430 -40 {lab=VSS}
N -370 20 -350 20 {lab=M_outb}
N -450 20 -430 20 {lab=VSS}
N -370 80 -350 80 {lab=Div}
N -450 80 -430 80 {lab=VSS}
N -370 140 -350 140 {lab=Resetb}
N -450 140 -430 140 {lab=VSS}
C {clk_gen/src/selector.sym} 0 0 0 0 {name=x1}
C {lab_pin.sym} -150 -40 0 0 {name=p1 sig_type=std_logic lab=M_out}
C {lab_pin.sym} -150 0 0 0 {name=p2 sig_type=std_logic lab=Div}
C {lab_pin.sym} -150 40 0 0 {name=p3 sig_type=std_logic lab=M_outb}
C {lab_pin.sym} 0 120 3 0 {name=p4 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} 150 -20 2 0 {name=p5 sig_type=std_logic lab=Sel}
C {lab_pin.sym} 150 20 2 0 {name=p6 sig_type=std_logic lab=Selb}
C {vsource.sym} -400 -40 1 0 {name=V1 value="PULSE(0 \{VDD\} 0 \{CT\} \{CT\} \{T_CLK/2-CT\} \{T_CLK\})" savecurrent=false}
C {lab_pin.sym} -350 -40 2 0 {name=p7 sig_type=std_logic lab=M_out}
C {lab_pin.sym} -450 -40 0 0 {name=p8 sig_type=std_logic lab=VSS}
C {vsource.sym} -400 20 1 0 {name=V2 value="PULSE(\{VDD\} 0 0 \{CT\} \{CT\} \{T_CLK/2-CT\} \{T_CLK\})" savecurrent=false}
C {lab_pin.sym} -350 20 2 0 {name=p9 sig_type=std_logic lab=M_outb}
C {lab_pin.sym} -450 20 0 0 {name=p10 sig_type=std_logic lab=VSS}
C {vsource.sym} -400 80 1 0 {name=V3 value="PULSE(0 \{VDD\} \{T_DIV/2\} \{CT\} \{CT\} \{T_CLK-CT\} \{T_DIV\})" savecurrent=false}
C {lab_pin.sym} -350 80 2 0 {name=p11 sig_type=std_logic lab=Div}
C {lab_pin.sym} -450 80 0 0 {name=p12 sig_type=std_logic lab=VSS}
C {vsource.sym} -400 140 1 0 {name=V4 value="PWL(0 0 \{T_RESET\} 0 \{T_RESET + CT\} \{VDD\})" savecurrent=false}
C {lab_pin.sym} -350 140 2 0 {name=p13 sig_type=std_logic lab=Resetb}
C {lab_pin.sym} -450 140 0 0 {name=p14 sig_type=std_logic lab=VSS}
C {code_shown.sym} -450 -400 0 0 {name=LIB only_toplevel=false value="
.LIB cornerMOSlv.lib mos_tt
.OPTIONS KLU
.INCLUDE sg13g2_stdcell.spice
.PARAM VDD=1.2
.PARAM T_CLK=2.5n
.PARAM T_DIV=10n
.PARAM CT=50p
.PARAM T_RESET=3n
.GLOBAL VDD VSS GND
"
place=header}
C {code_shown.sym} -100 -400 0 0 {name=CODE only_toplevel=false value="
VVDD VDD 0 DC \{VDD\}
VVSS VSS 0 0
.control
  save all
  tran 10p 60n
  * pass criteria: Sel pulses once per Div period (10n),
  * pulse width ~ half an M_out period (injection window)
  meas tran ts1 when v(Sel)=0.6 rise=2
  meas tran tf1 when v(Sel)=0.6 fall=2
  let selw = tf1-ts1
  echo SEL_WIDTH $&selw
  meas tran ts2 when v(Sel)=0.6 rise=3
  let selp = ts2-ts1
  echo SEL_PERIOD $&selp
  write test_selector.raw
.endc
"}
