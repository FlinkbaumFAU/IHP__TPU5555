v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -150 -20 -110 -20 {lab=clk}
N -150 20 -110 20 {lab=resetb}
N 110 -30 150 -30 {lab=clk2}
N 110 0 150 0 {lab=clk4}
N 110 30 150 30 {lab=div}
N -370 -20 -350 -20 {lab=clk}
N -450 -20 -430 -20 {lab=VSS}
N -370 40 -350 40 {lab=resetb}
N -450 40 -430 40 {lab=VSS}
C {clk_gen/src/divider.sym} 0 0 0 0 {name=x1}
C {lab_pin.sym} -150 -20 0 0 {name=p1 sig_type=std_logic lab=clk}
C {lab_pin.sym} -150 20 0 0 {name=p2 sig_type=std_logic lab=resetb}
C {lab_pin.sym} 150 -30 2 0 {name=p3 sig_type=std_logic lab=clk2}
C {lab_pin.sym} 150 0 2 0 {name=p4 sig_type=std_logic lab=clk4}
C {lab_pin.sym} 150 30 2 0 {name=p5 sig_type=std_logic lab=div}
C {vsource.sym} -400 -20 1 0 {name=V1 value="PULSE(0 \{VDD\} 0 \{CT\} \{CT\} \{T_CLK/2\} \{T_CLK\})" savecurrent=false}
C {lab_pin.sym} -350 -20 2 0 {name=p6 sig_type=std_logic lab=clk}
C {lab_pin.sym} -450 -20 0 0 {name=p7 sig_type=std_logic lab=VSS}
C {vsource.sym} -400 40 1 0 {name=V2 value="PWL(0 0 \{T_RESET\} 0 \{T_RESET + CT\} \{VDD\})" savecurrent=false}
C {lab_pin.sym} -350 40 2 0 {name=p8 sig_type=std_logic lab=resetb}
C {lab_pin.sym} -450 40 0 0 {name=p9 sig_type=std_logic lab=VSS}
C {code_shown.sym} -450 -400 0 0 {name=LIB only_toplevel=false value="
.LIB cornerMOSlv.lib mos_tt
.OPTIONS KLU
.INCLUDE sg13g2_stdcell.spice
.PARAM VDD=1.2
.PARAM T_CLK=2.5n
.PARAM CT=50p
.PARAM T_RESET=3n
.GLOBAL VDD VSS
"
place=header}
C {code_shown.sym} -100 -400 0 0 {name=CODE only_toplevel=false value="
VVDD VDD 0 DC \{VDD\}
VVSS VSS 0 0
.control
  save all
  tran 10p 100n
  * pass criterion: clk4 period == 4x clk period, div pulses once per 4 clk cycles
  meas tran tclk1 when v(clk)=0.6 rise=10
  meas tran tclk2 when v(clk)=0.6 rise=30
  let tclk = (tclk2-tclk1)/20
  meas tran t41 when v(clk4)=0.6 rise=3
  meas tran t42 when v(clk4)=0.6 rise=8
  let t4 = (t42-t41)/5
  let ratio = t4/tclk
  echo DIV_RATIO $&ratio
  meas tran tdiv1 when v(div)=0.6 rise=3
  meas tran tdiv2 when v(div)=0.6 rise=8
  let tdiv = (tdiv2-tdiv1)/5
  let dratio = tdiv/tclk
  echo DIV_PULSE_RATIO $&dratio
  write test_divider.raw
.endc
"}
