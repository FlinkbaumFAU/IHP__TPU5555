v {xschem version=3.4.7 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N -460 -500 -400 -500 {lab=in}
N -460 900 -400 900 {lab=inb}
N -200 130 -200 160 {lab=out}
N -110 130 -110 160 {lab=out}
N -200 130 -110 130 {lab=out}
N -200 270 -110 270 {lab=outb}
N -110 130 0 130 {lab=out}
N -110 270 0 270 {lab=outb}
N -200 240 -200 270 {lab=outb}
N -110 240 -110 270 {lab=outb}
N -320 -500 -270 -500 {lab=out}
N -370 -430 -270 -430 {lab=out}
N -270 -500 -270 -430 {lab=out}
N -370 -350 -270 -350 {lab=out}
N -270 -430 -270 -350 {lab=out}
N -370 -270 -270 -270 {lab=out}
N -270 -350 -270 -270 {lab=out}
N -370 -190 -270 -190 {lab=out}
N -270 -270 -270 -190 {lab=out}
N -370 -110 -270 -110 {lab=out}
N -270 -190 -270 -110 {lab=out}
N -370 -30 -270 -30 {lab=out}
N -270 -110 -270 -30 {lab=out}
N -370 50 -270 50 {lab=out}
N -270 -30 -270 50 {lab=out}
N -370 130 -270 130 {lab=out}
N -270 50 -270 130 {lab=out}
N -270 130 -200 130 {lab=out}
N -320 900 -270 900 {lab=outb}
N -370 830 -270 830 {lab=outb}
N -270 900 -270 830 {lab=outb}
N -370 750 -270 750 {lab=outb}
N -270 830 -270 750 {lab=outb}
N -370 670 -270 670 {lab=outb}
N -270 750 -270 670 {lab=outb}
N -370 590 -270 590 {lab=outb}
N -270 670 -270 590 {lab=outb}
N -370 510 -270 510 {lab=outb}
N -270 590 -270 510 {lab=outb}
N -370 430 -270 430 {lab=outb}
N -270 510 -270 430 {lab=outb}
N -370 350 -270 350 {lab=outb}
N -270 430 -270 350 {lab=outb}
N -370 270 -270 270 {lab=outb}
N -270 350 -270 270 {lab=outb}
N -270 270 -200 270 {lab=outb}
N -420 -440 -420 170 {lab=co[7:0]
bus=true}
N -420 230 -420 830 {lab=cob[7:0]
bus=true}
N -410 -400 -400 -400 {lab=co[0]}
N -410 -320 -400 -320 {lab=co[1]}
N -410 -240 -400 -240 {lab=co[2]}
N -410 -160 -400 -160 {lab=co[3]}
N -410 -80 -400 -80 {lab=co[4]}
N -410 0 -400 0 {lab=co[5]}
N -410 80 -400 80 {lab=co[6]}
N -410 160 -400 160 {lab=co[7]}
N -410 800 -400 800 {lab=cob[0]}
N -410 720 -400 720 {lab=cob[1]}
N -410 640 -400 640 {lab=cob[2]}
N -410 560 -400 560 {lab=cob[3]}
N -410 480 -400 480 {lab=cob[4]}
N -410 400 -400 400 {lab=cob[5]}
N -410 320 -400 320 {lab=cob[6]}
N -410 240 -400 240 {lab=cob[7]}
C {ipin.sym} -460 -500 0 0 {name=p1 lab=in}
C {ipin.sym} -460 900 2 1 {name=p4 lab=inb}
C {opin.sym} 0 130 0 0 {name=p2 lab=out}
C {opin.sym} 0 270 0 0 {name=p5 lab=outb}
C {ipin.sym} -420 -440 0 0 {name=p3 lab=co[7:0]}
C {ipin.sym} -420 830 0 0 {name=p6 lab=cob[7:0]}
C {sg13g2_inv_2.sym} -360 -500 0 0 {name=x13 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_2.sym} -360 900 2 1 {name=x14 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_1.sym} -110 200 1 1 {name=x11 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {sg13g2_inv_1.sym} -200 200 3 1 {name=x12 VDD=VDD VSS=VSS prefix=sg13g2_ }
C {custom_cap_8.sym} -370 -400 1 0 {name=xco0 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 -390 0 0 {name=lco0 lab=[0]}
C {custom_cap_8.sym} -370 -320 1 0 {name=xco1 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 -310 0 0 {name=lco1 lab=[1]}
C {custom_cap_8.sym} -370 -240 1 0 {name=xco2 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 -230 0 0 {name=lco2 lab=[2]}
C {custom_cap_8.sym} -370 -160 1 0 {name=xco3 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 -150 0 0 {name=lco3 lab=[3]}
C {custom_cap_8.sym} -370 -80 1 0 {name=xco4 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 -70 0 0 {name=lco4 lab=[4]}
C {custom_cap_8.sym} -370 0 1 0 {name=xco5 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 10 0 0 {name=lco5 lab=[5]}
C {custom_cap_8.sym} -370 80 1 0 {name=xco6 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 90 0 0 {name=lco6 lab=[6]}
C {custom_cap_8.sym} -370 160 1 0 {name=xco7 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 170 0 0 {name=lco7 lab=[7]}
C {custom_cap_8.sym} -370 800 1 1 {name=xcob0 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 790 2 1 {name=lcob0 lab=[0]}
C {custom_cap_8.sym} -370 720 1 1 {name=xcob1 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 710 2 1 {name=lcob1 lab=[1]}
C {custom_cap_8.sym} -370 640 1 1 {name=xcob2 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 630 2 1 {name=lcob2 lab=[2]}
C {custom_cap_8.sym} -370 560 1 1 {name=xcob3 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 550 2 1 {name=lcob3 lab=[3]}
C {custom_cap_8.sym} -370 480 1 1 {name=xcob4 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 470 2 1 {name=lcob4 lab=[4]}
C {custom_cap_8.sym} -370 400 1 1 {name=xcob5 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 390 2 1 {name=lcob5 lab=[5]}
C {custom_cap_8.sym} -370 320 1 1 {name=xcob6 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 310 2 1 {name=lcob6 lab=[6]}
C {custom_cap_8.sym} -370 240 1 1 {name=xcob7 VDD=VDD VSS=VSS prefix=custom_ }
C {bus_tap.sym} -420 230 2 1 {name=lcob7 lab=[7]}
