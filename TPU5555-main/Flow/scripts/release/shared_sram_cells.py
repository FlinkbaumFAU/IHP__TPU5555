# klayout -b -r shared_sram_cells.py -rd gds=TPU5555.gds -rd pdk=<IHP-Open-PDK>/ihp-sg13cmos5l
# Lists the child cells of SRAM bitcell sub-cells that the PDK SRAM GDS files share by name.
import pya, glob, os
P = pdk + "/libs.ref/sg13cmos5l_sram/gds/"
rel = pya.Layout(); rel.read(gds)
def kids(ly, name):
    c = ly.cell(name)
    return sorted(set(ly.cell(i.cell_index).name for i in c.each_inst())) if c else None
for cell in ["RM_IHPSG13_1P_BITKIT_CELL_SUB", "RM_IHPSG13_1P_BITKIT_EDGE_LR"]:
    print("==", cell)
    print("  release      :", kids(rel, cell))
    for f in ["RM_IHPSG13_1P_1024x32_c2_bm_bist", "RM_IHPSG13_1P_1024x16_c2_bm_bist", "RM_IHPSG13_1P_1024x8_c2_bm_bist", "RM_IHPSG13_1P_256x48_c2_bm_bist"]:
        ly = pya.Layout(); ly.read(P + f + ".gds")
        print("  %-34s:" % f, kids(ly, cell))
