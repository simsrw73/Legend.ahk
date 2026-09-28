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
        T.Eq(r.Values[item[2]], item[4], item[2])
}

T.Test("Theme: auto resolves to a shipped theme", Theme_Auto)
Theme_Auto() {
    r := LegendTheme.Load("auto")
    T.Eq(r.Warnings.Length, 0)
}
