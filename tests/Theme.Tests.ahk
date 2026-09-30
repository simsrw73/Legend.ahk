#Requires AutoHotkey v2.0

T.Test("Theme: partial file falls back to defaults and warns on bad values", Theme_Partial)
Theme_Partial() {
    warnings := []
    v := LegendTheme.Read(A_ScriptDir "\fixtures\themes\partial.ini", warnings)
    T.Eq(v["keyDoc"], "B4BEFE")
    T.Eq(v["background"], "000000", "# prefix accepted")
    T.Eq(v["title"], "7F849C", "invalid → default")
    T.Eq(v["maxColumns"], 3, "out of range → default")
    T.Eq(v["rounded"], false)
    T.Eq(v["keyStyle"], "symbols")
    T.Eq(v["bodySize"], 11, "missing → default")
    T.Eq(warnings.Length, 2)
}

T.Test("Theme: host folders are searched before built-in themes", Theme_Search)
Theme_Search() {
    r := LegendTheme.Load("partial", [A_ScriptDir "\fixtures\themes"])
    T.Eq(r.Values["keyDoc"], "B4BEFE")
    latte := LegendTheme.Load("catppuccin-latte")
    T.Eq(latte.Values["background"], "EFF1F5")
    T.Eq(latte.Warnings.Length, 0)
}

T.Test("Theme: missing theme warns and uses defaults", Theme_Missing)
Theme_Missing() {
    r := LegendTheme.Load("nope")
    T.Eq(r.Warnings.Length, 1)
    T.Eq(r.Values["background"], "11111B")
}

T.Test("Theme: shipped Mocha file equals the defaults", Theme_MochaMatchesDefaults)
Theme_MochaMatchesDefaults() {
    r := LegendTheme.Load("catppuccin-mocha")
    T.Eq(r.Warnings.Length, 0)
    for item in LegendTheme.Schema
        if item[4] != ""   ; "" defaults are derived in Resolve; Mocha may set them
            T.Eq(r.Values[item[2]], item[4], item[2])
}

T.Test("Theme: auto resolves to a shipped theme", Theme_Auto)
Theme_Auto() {
    r := LegendTheme.Load("auto")
    T.Eq(r.Warnings.Length, 0)
}

T.Test("Theme: comfortable density is the default", Theme_DensityDefault)
Theme_DensityDefault() {
    v := LegendTheme.Resolve(LegendTheme.Read(""))
    T.Eq(v["density"], "comfortable")
    T.Eq(v["padding"], 28)
    T.Eq(v["rowSpacing"], 12)
    T.Eq(v["columnGap"], 56)
}

T.Test("Theme: compact density restores the original spacing", Theme_DensityCompact)
Theme_DensityCompact() {
    v := LegendTheme.Resolve(LegendTheme.Read(""), "compact")
    T.Eq(v["density"], "compact")
    T.Eq(v["padding"], 20)
    T.Eq(v["rowSpacing"], 6)
    T.Eq(v["columnGap"], 40)
}

T.Test("Theme: explicit spacing beats the density preset", Theme_ExplicitSpacing)
Theme_ExplicitSpacing() {
    base := LegendTheme.Read(A_ScriptDir "\fixtures\themes\spaced.ini")
    T.Eq(LegendTheme.Resolve(base, "compact")["padding"], 10)
    T.Eq(LegendTheme.Resolve(base, "comfortable")["padding"], 10)
    T.Eq(LegendTheme.Resolve(base, "compact")["rowSpacing"], 6)
}

T.Test("Theme: legend auto shows only for symbol styles", Theme_LegendAuto)
Theme_LegendAuto() {
    base := LegendTheme.Read("")
    T.Eq(base["legend"], "auto")
    T.Eq(LegendTheme.Resolve(base)["legend"], "off", "text style")
    r := LegendTheme.Resolve(base, "", "symbols")
    T.Eq(r["keyStyle"], "symbols")
    T.Eq(r["legend"], "bottom")
    base["legend"] := "off"
    T.Eq(LegendTheme.Resolve(base, "", "ahk")["legend"], "off", "explicit off stays off")
    T.Eq(base["keyStyle"], "text", "Resolve does not modify its input")
}

T.Test("Theme: running-indicator colors", Theme_Indicators)
Theme_Indicators() {
    T.Eq(LegendTheme.Read("")["indicatorOn"], "A6E3A1")
    T.Eq(LegendTheme.Read("")["indicatorOff"], "45475A")
    latte := LegendTheme.Load("catppuccin-latte").Values
    T.Eq(latte["indicatorOn"], "40A02B")
    T.Eq(latte["indicatorOff"], "BCC0CC")
}

T.Test("Theme: picker colors fall back to existing colors", Theme_PickerFallback)
Theme_PickerFallback() {
    v := LegendTheme.Read("")
    T.Eq(v["selection"], "", "unset before Resolve")
    r := LegendTheme.Resolve(v)
    T.Eq(r["selection"], "313244")
    T.Eq(r["selectionText"], "CDD6F4")
    T.Eq(r["outline"], "89B4FA")
    mocha := LegendTheme.Resolve(LegendTheme.Load("catppuccin-mocha").Values)
    T.Eq(mocha["selection"], "45475A")
    latte := LegendTheme.Resolve(LegendTheme.Load("catppuccin-latte").Values)
    T.Eq(latte["outline"], "1E66F5")
}
