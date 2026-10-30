# klayout -b -r compare_hard_ip.py -rd gds=TPU5555.gds -rd pdk=<IHP-Open-PDK>/ihp-sg13cmos5l
# Compare every hard-IP cell (and all its sub-cells) of the release GDS with the PDK GDS:
# per cell, per layer: merged-polygon XOR, text strings+positions, and child instances.
import pya, glob, os, sys
rel = pya.Layout(); rel.read(gds)
files = sorted(glob.glob(pdk + "/libs.ref/sg13cmos5l_sram/gds/RM_IHPSG13_1P_*.gds")) + [pdk + "/libs.ref/sg13cmos5l_io/gds/sg13cmos5l_io.gds"]
def insts(cell):
    return sorted((cell.layout().cell(i.cell_index).name, str(i.trans) if not i.is_complex() else str(i.cplx_trans), i.a.to_s(), i.b.to_s(), i.na, i.nb) for i in cell.each_inst())
for f in files:
    ref = pya.Layout(); ref.read(f)
    for top in ref.top_cells():
        if rel.cell(top.name) is None: continue
        problems = []; ncells = 0; dropped_layers = set()
        for ci in [top.cell_index()] + list(top.called_cells()):
            a = ref.cell(ci); b = rel.cell(a.name); ncells += 1
            if b is None: problems.append(f"cell {a.name} missing"); continue
            if insts(a) != insts(b): problems.append(f"{a.name}: instances differ")
            for li in ref.layer_indexes():
                info = ref.get_info(li); lb = rel.find_layer(info.layer, info.datatype)
                ra = pya.Region(a.shapes(li)); ta = sorted((t.string, str(t.trans.disp)) for t in pya.Texts(a.shapes(li)).each())
                if lb is None:
                    if not ra.is_empty() or ta: dropped_layers.add(str(info)); problems.append(f"{a.name} {info}: layer missing in release ({ra.count()} polys, {len(ta)} texts)")
                    continue
                rb = pya.Region(b.shapes(lb)); tb = sorted((t.string, str(t.trans.disp)) for t in pya.Texts(b.shapes(lb)).each())
                if not (ra ^ rb).is_empty(): problems.append(f"{a.name} {info}: geometry differs")
                if ta != tb: problems.append(f"{a.name} {info}: texts differ ({len(ta)} vs {len(tb)})")
            for lb in rel.layer_indexes():
                info = rel.get_info(lb)
                if ref.find_layer(info.layer, info.datatype) is None and not b.shapes(lb).is_empty():
                    problems.append(f"{a.name} {info}: extra layer in release")
        print(("IDENTICAL " if not problems else "DIFFERENT ") + f"{top.name} ({ncells} cells checked)", problems[:6], flush=True)
print("DONE", flush=True)
