v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -180 -50 -140 -50 {lab=in}
N -180 0 -140 0 {lab=C[7:0] bus=true}
N -180 50 -140 50 {lab=inb}
N 0 -50 80 -50 {lab=out}
N 0 50 80 50 {lab=outb}
N -370 -50 -350 -50 {lab=in}
N -450 -50 -430 -50 {lab=VSS}
N -370 10 -350 10 {lab=inb}
N -450 10 -430 10 {lab=VSS}
N -820 80 -780 80 {lab=VSS}
N -720 80 -680 80 {lab=C[0]}
N -820 140 -780 140 {lab=VSS}
N -720 140 -680 140 {lab=C[1]}
N -820 200 -780 200 {lab=VSS}
N -720 200 -680 200 {lab=C[2]}
N -820 260 -780 260 {lab=VSS}
N -720 260 -680 260 {lab=C[3]}
N -820 320 -780 320 {lab=VSS}
N -720 320 -680 320 {lab=C[4]}
N -820 380 -780 380 {lab=VSS}
N -720 380 -680 380 {lab=C[5]}
N -820 440 -780 440 {lab=VSS}
N -720 440 -680 440 {lab=C[6]}
N -820 500 -780 500 {lab=VSS}
N -720 500 -680 500 {lab=C[7]}
C {clk_gen/src/delay_cell.sym} 0 0 0 0 {name=x1}
C {lab_pin.sym} -180 -50 0 0 {name=p1 sig_type=std_logic lab=in}
C {lab_pin.sym} -180 0 0 0 {name=p2 sig_type=std_logic lab=C[7:0]}
C {lab_pin.sym} -180 50 0 0 {name=p3 sig_type=std_logic lab=inb}
C {sg13g2_inv_1.sym} 120 -50 0 0 {name=x2 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_1.sym} 120 50 0 0 {name=x3 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {lab_pin.sym} 40 -50 2 0 {name=p4 sig_type=std_logic lab=out}
C {lab_pin.sym} 40 50 2 0 {name=p5 sig_type=std_logic lab=outb}
C {vsource.sym} -400 -50 1 0 {name=Vin value="PULSE(0 \{VDD\} 1n \{CT\} \{CT\} \{T_CLK/2-CT\} \{T_CLK\})" savecurrent=false}
C {lab_pin.sym} -350 -50 2 0 {name=p6 sig_type=std_logic lab=in}
C {lab_pin.sym} -450 -50 0 0 {name=p7 sig_type=std_logic lab=VSS}
C {vsource.sym} -400 10 1 0 {name=Vinb value="PULSE(\{VDD\} 0 1n \{CT\} \{CT\} \{T_CLK/2-CT\} \{T_CLK\})" savecurrent=false}
C {lab_pin.sym} -350 10 2 0 {name=p8 sig_type=std_logic lab=inb}
C {lab_pin.sym} -450 10 0 0 {name=p9 sig_type=std_logic lab=VSS}
C {vsource.sym} -750 80 1 0 {name=VC0 value=0 savecurrent=false}
C {lab_pin.sym} -820 80 0 0 {name=p10 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 80 2 0 {name=p11 sig_type=std_logic lab=C[0]}
C {vsource.sym} -750 140 1 0 {name=VC1 value=0 savecurrent=false}
C {lab_pin.sym} -820 140 0 0 {name=p12 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 140 2 0 {name=p13 sig_type=std_logic lab=C[1]}
C {vsource.sym} -750 200 1 0 {name=VC2 value=0 savecurrent=false}
C {lab_pin.sym} -820 200 0 0 {name=p14 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 200 2 0 {name=p15 sig_type=std_logic lab=C[2]}
C {vsource.sym} -750 260 1 0 {name=VC3 value=0 savecurrent=false}
C {lab_pin.sym} -820 260 0 0 {name=p16 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 260 2 0 {name=p17 sig_type=std_logic lab=C[3]}
C {vsource.sym} -750 320 1 0 {name=VC4 value=0 savecurrent=false}
C {lab_pin.sym} -820 320 0 0 {name=p18 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 320 2 0 {name=p19 sig_type=std_logic lab=C[4]}
C {vsource.sym} -750 380 1 0 {name=VC5 value=0 savecurrent=false}
C {lab_pin.sym} -820 380 0 0 {name=p20 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 380 2 0 {name=p21 sig_type=std_logic lab=C[5]}
C {vsource.sym} -750 440 1 0 {name=VC6 value=0 savecurrent=false}
C {lab_pin.sym} -820 440 0 0 {name=p22 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 440 2 0 {name=p23 sig_type=std_logic lab=C[6]}
C {vsource.sym} -750 500 1 0 {name=VC7 value=0 savecurrent=false}
C {lab_pin.sym} -820 500 0 0 {name=p24 sig_type=std_logic lab=VSS}
C {lab_pin.sym} -680 500 2 0 {name=p25 sig_type=std_logic lab=C[7]}
C {code_shown.sym} -450 -400 0 0 {name=LIB only_toplevel=false value="
.LIB cornerMOSlv.lib mos_tt
.OPTIONS KLU
.INCLUDE sg13g2_stdcell.spice
.INCLUDE custom_stdcell.spice
.PARAM VDD=1.2
.PARAM T_CLK=4n
.PARAM CT=50p
.GLOBAL VDD VSS
"
place=header}
C {code_shown.sym} -100 -400 0 0 {name=CODE only_toplevel=false value="
VVDD VDD 0 DC \{VDD\}
VVSS VSS 0 0
.control
  set noaskquit
  echo code tpd > delay_cell_char.csv
  foreach code 0 32 64 96 128 160 192 224 255
    let cc = $code
    let b7 = floor(cc/128) - 2*floor(cc/256)
    let b6 = floor(cc/64)  - 2*floor(cc/128)
    let b5 = floor(cc/32)  - 2*floor(cc/64)
    let b4 = floor(cc/16)  - 2*floor(cc/32)
    let b3 = floor(cc/8)   - 2*floor(cc/16)
    let b2 = floor(cc/4)   - 2*floor(cc/8)
    let b1 = floor(cc/2)   - 2*floor(cc/4)
    let b0 = cc - 2*floor(cc/2)
    let v7 = b7*1.2
    let v6 = b6*1.2
    let v5 = b5*1.2
    let v4 = b4*1.2
    let v3 = b3*1.2
    let v2 = b2*1.2
    let v1 = b1*1.2
    let v0 = b0*1.2
    alter @VC7[dc] = $&v7
    alter @VC6[dc] = $&v6
    alter @VC5[dc] = $&v5
    alter @VC4[dc] = $&v4
    alter @VC3[dc] = $&v3
    alter @VC2[dc] = $&v2
    alter @VC1[dc] = $&v1
    alter @VC0[dc] = $&v0
    tran 10p 20n
    * inverting stage: in rise -> out fall
    meas tran ti when v(in)=0.6 rise=3
    meas tran to when v(out)=0.6 fall=3
    let tpd = to-ti
    echo $code $&tpd >> delay_cell_char.csv
    destroy all
  end
.endc
"}
