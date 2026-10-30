# Build the release GDS from the LibreLane final GDS.
#
#   klayout -b -r make_release.py -rd src=<run>/final/gds/hdc_chip_top.gds -rd dst=TPU5555.gds
#
# Only two edits are made:
#   1. The top cell hdc_chip_top is renamed to TPU5555.
#   2. The sealring PCell's registration text (layer 63/0) reports the area as
#      "4.8e-06 sq mm"; it is replaced by the correct value computed from the
#      registered size.
# The file is written with the save options required by the Open-Silicon MPW
# (no PCell/context info, zero-length paths converted to boundaries).
import re
import pya

TOP_OLD = "hdc_chip_top"
TOP_NEW = "TPU5555"

ly = pya.Layout()
ly.read(src)

tops = ly.top_cells()
assert len(tops) == 1 and tops[0].name == TOP_OLD, [c.name for c in tops]
assert ly.cell(TOP_NEW) is None
tops[0].name = TOP_NEW

seal = ly.cell("sealring")
assert seal is not None
li = ly.find_layer(63, 0)
fixed = 0
for s in seal.shapes(li).each():
    if not s.is_text():
        continue
    m = re.search(r"x=([\d.]+) um ; y=([\d.]+) um\nCalculated area: \S+ sq mm", s.text_string)
    if m:
        area_mm2 = float(m.group(1)) * float(m.group(2)) * 1e-6
        t = s.text
        t.string = re.sub(r"Calculated area: \S+ sq mm", f"Calculated area: {area_mm2:g} sq mm", s.text_string)
        s.text = t
        fixed += 1
        print("sealring label:", repr(t.string))
assert fixed == 1, fixed

opt = pya.SaveLayoutOptions()
opt.format = "GDS2"
opt.write_context_info = False
opt.gds2_no_zero_length_paths = True
ly.write(dst, opt)
print("written:", dst)
