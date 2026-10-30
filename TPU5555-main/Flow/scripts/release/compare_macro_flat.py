# klayout -b -r compare_macro_flat.py -rd gds=TPU5555.gds -rd reff=<PDK macro .gds> -rd name=<macro cell>
# Geometric (deep-mode) XOR of one macro: release GDS vs PDK GDS, all layers, plus texts.
import pya
rel = pya.Layout(); rel.read(gds)
ref = pya.Layout(); ref.read(reff)
a = ref.cell(name); b = rel.cell(name)
dss = pya.DeepShapeStore(); dss.threads = 32
bad = 0
for li in ref.layer_indexes():
    info = ref.get_info(li); lb = rel.find_layer(info.layer, info.datatype)
    ra = pya.Region(a.begin_shapes_rec(li), dss)
    rb = pya.Region(b.begin_shapes_rec(lb), dss) if lb is not None else pya.Region()
    x = ra ^ rb
    ta = sorted((t.string, str(t.trans.disp)) for t in pya.Texts(a.begin_shapes_rec(li)).each())
    tb = sorted((t.string, str(t.trans.disp)) for t in pya.Texts(b.begin_shapes_rec(lb)).each()) if lb is not None else []
    if ra.is_empty() and rb.is_empty() and not ta and not tb: continue
    ok = x.is_empty() and ta == tb
    if not ok: bad += 1
    print(f"{info}: {'same' if ok else 'DIFF'} xor_polys={x.count()} texts {len(ta)}/{len(tb)}", flush=True)
for lb in rel.layer_indexes():
    info = rel.get_info(lb)
    if ref.find_layer(info.layer, info.datatype) is None and not (pya.Region(b.begin_shapes_rec(lb)).is_empty() and pya.Texts(b.begin_shapes_rec(lb)).is_empty()):
        bad += 1; print(f"{info}: extra layer in release", flush=True)
print(f"RESULT {name}: {'GEOMETRICALLY IDENTICAL' if bad == 0 else str(bad) + ' layers differ'}", flush=True)
