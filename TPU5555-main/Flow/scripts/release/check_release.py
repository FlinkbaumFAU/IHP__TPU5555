# Compare the release GDS against the LibreLane final GDS it was built from.
#
#   klayout -b -r check_release.py -rd orig=<run>/final/gds/hdc_chip_top.gds -rd new=TPU5555.gds
#
# Prints every difference found by pya.LayoutDiff after mapping the renamed top
# cell back. Expected result: geometry identical, exactly one text difference
# (the sealring area label fixed by make_release.py). Also counts zero-area
# shapes, using the same criteria as IHP's zero.py.
import pya

a = pya.Layout(); a.read(orig)
b = pya.Layout(); b.read(new)
print("orig top:", [c.name for c in a.top_cells()], "| new top:", [c.name for c in b.top_cells()])
print("new bbox (um):", b.top_cell().dbbox(), "| dbu:", b.dbu)
b.top_cell().name = a.top_cell().name

diffs = []
d = pya.LayoutDiff()
cur = {"cell": None, "layer": None}
d.on_begin_cell = lambda ca, cb: cur.update(cell=(ca or cb).name)
d.on_begin_layer = lambda info, ia, ib: cur.update(layer=str(info))
d.on_text_in_a_only = lambda t, p: diffs.append(("only in orig", cur["cell"], cur["layer"], t.string))
d.on_text_in_b_only = lambda t, p: diffs.append(("only in new", cur["cell"], cur["layer"], t.string))
for ev in ("polygon", "path", "box", "edge"):
    for side, label in (("a", "orig"), ("b", "new")):
        setattr(d, f"on_{ev}_in_{side}_only",
                lambda o, p, ev=ev, label=label: diffs.append((f"{ev} only in {label}", cur["cell"], cur["layer"], str(o))))
d.on_cell_in_a_only = lambda c: diffs.append(("cell only in orig", c.name, "", ""))
d.on_cell_in_b_only = lambda c: diffs.append(("cell only in new", c.name, "", ""))
d.on_instance_in_a_only = lambda i, p: diffs.append(("instance only in orig", cur["cell"], "", str(i)))
d.on_instance_in_b_only = lambda i, p: diffs.append(("instance only in new", cur["cell"], "", str(i)))

identical = d.compare(a, b, pya.LayoutDiff.Verbose | pya.LayoutDiff.SmartCellMapping | pya.LayoutDiff.NoTextOrientation, 0)
print("LayoutDiff identical:", identical)
print("cells:", a.cells(), b.cells())
print("differences:", len(diffs))
for x in diffs:
    print("  ", x)

zero = 0
for li in b.layer_indexes():
    for c in b.each_cell():
        for s in c.shapes(li).each():
            if s.is_box() and (s.box.width() == 0 or s.box.height() == 0): zero += 1
            elif s.is_path() and (s.path.width == 0 or s.path.polygon().area() == 0): zero += 1
            elif (s.is_polygon() or s.is_simple_polygon()) and s.polygon.area() == 0: zero += 1
print("zero-area shapes (all layers):", zero)
