gds read custom_stdcell.gds

set cells [list "custom_cap_1" "custom_cap_2" "custom_cap_4" "custom_cap_8" "custom_cap_16" "custom_einvn_16" "custom_einvn_1"]
exec mkdir -p lef_out
cd lef_out

foreach cell $cells {
    load $cell
    property LEFsite CoreSite
    property LEFclass Core
    property LEFsymmetry "X Y"
    property LEFproperties "CatenaDesignType \"deviceLevel\""
    lef writeall -hide
}
exit
