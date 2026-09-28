#Requires AutoHotkey v2.0

T.Test("Overlay: & is measured as a literal character", Overlay_AmpersandIsLiteral)
Overlay_AmpersandIsLiteral() {
    m := LegendMeasurer(LegendTheme.Resolve(LegendTheme.Read("")))
    try {
        with := m.Size("Open & close", "body").W
        without := m.Size("Open  close", "body").W
        T.True(with > without, with " vs " without)
    } finally
        m.Destroy()
}

T.Test("Overlay: measurer sizes entries and headings", Overlay_Measure)
Overlay_Measure() {
    m := LegendMeasurer(LegendTheme.Resolve(LegendTheme.Read("")))
    try {
        entry := m(LegendRows.Row("entry", "Ctrl+Shift+T", "Reopen", "bound"))
        T.True(entry.KeyW > 0 && entry.TextW > 0 && entry.H > 6)
        heading := m(LegendRows.Row("heading", "", "Tabs"))
        T.Eq(heading.KeyW, 0)
    } finally
        m.Destroy()
}

T.Test("Overlay: a status dot widens the text column", Overlay_StatusWidth)
Overlay_StatusWidth() {
    m := LegendMeasurer(LegendTheme.Resolve(LegendTheme.Read("")))
    try {
        plain := m(LegendRows.Row("entry", "z", "Zed", "bound"))
        dotted := m(LegendRows.Row("entry", "z", "Zed", "bound", [], true))
        T.True(dotted.TextW > plain.TextW, dotted.TextW " vs " plain.TextW)
    } finally
        m.Destroy()
}
