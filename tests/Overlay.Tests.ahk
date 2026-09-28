#Requires AutoHotkey v2.0

T.Test("Overlay: & is measured as a literal character", Overlay_AmpersandIsLiteral)
Overlay_AmpersandIsLiteral() {
    m := LegendMeasurer(LegendTheme.Read(""))
    try {
        with := m.Size("Open & close", "body").W
        without := m.Size("Open  close", "body").W
        T.True(with > without, with " vs " without)
    } finally
        m.Destroy()
}

T.Test("Overlay: measurer sizes entries and headings", Overlay_Measure)
Overlay_Measure() {
    m := LegendMeasurer(LegendTheme.Read(""))
    try {
        entry := m(LegendRows.Row("entry", "Ctrl+Shift+T", "Reopen", "bound"))
        T.True(entry.KeyW > 0 && entry.TextW > 0 && entry.H > 6)
        heading := m(LegendRows.Row("heading", "", "Tabs"))
        T.Eq(heading.KeyW, 0)
    } finally
        m.Destroy()
}
