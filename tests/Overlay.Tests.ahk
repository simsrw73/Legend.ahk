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

; Seven one-entry pages laid out in two columns with the real measurer.
Overlay_TwoColumnNav(theme, measurer) {
    r := Registry_New()
    loop 7
        r.Bind(["Page " A_Index, "c"], "^!F" A_Index, "x", Noop)
    nav := LegendNavigator(r.SortedPages(), (rows, *) => LegendLayout.Paginate(rows, measurer, 100, 2, theme["padding"], 0, theme["columnGap"]))
    nav.Open([])
    return nav
}

T.Test("Overlay: moving the selection never changes an Alt+/ menu's size", Overlay_SelectionSize)
Overlay_SelectionSize() {
    theme := LegendTheme.Resolve(LegendTheme.Read(""))
    m := LegendMeasurer(theme)
    nav := Overlay_TwoColumnNav(theme, m)
    T.Eq(nav.View.Columns.Length, 2, "two columns")
    first := LegendOverlay.Show(nav.View, theme, m, "f", "", false, 0)
    onScreen := 0
    for col in nav.View.Columns
        onScreen += col.Rows.Length
    loop onScreen - 1   ; the last item of this screen, in the last column
        nav.Press("Down")
    T.Eq(nav.View.ScreenIndex, 1)
    last := LegendOverlay.Show(nav.View, theme, m, "f", "", false, 0)
    try {
        WinGetPos(, , &firstW, &firstH, first)
        WinGetPos(, , &lastW, &lastH, last)
        T.Eq(lastW " " lastH, firstW " " firstH, "cursor in the last column")
        first.Selection.Select(first.Selection.Rows.Length)
        first.Selection.Bar.GetPos(&barX, , &barW)
        first.GetClientPos(, , &clientW)
        T.True(barX + barW <= clientW, "the bar stays inside the window")
    } finally
        first.Destroy(), last.Destroy(), m.Destroy()
}

T.Test("Overlay: flat pages register no selectable rows", Overlay_FlatUnchanged)
Overlay_FlatUnchanged() {
    theme := LegendTheme.Resolve(LegendTheme.Read(""))
    m := LegendMeasurer(theme)
    nav := Overlay_TwoColumnNav(theme, m)
    nav.Press("Enter")   ; Page 1 is flat
    flat := LegendOverlay.Show(nav.View, theme, m, "f", "", false, 0)
    try
        T.Eq(flat.Selection.Rows.Length, 0)
    finally
        flat.Destroy(), m.Destroy()
}

T.Test("Overlay: the list body selects view.SelectedIndex", Overlay_ListSelectedIndex)
Overlay_ListSelectedIndex() {
    theme := LegendTheme.Resolve(LegendTheme.Read(""))
    m := LegendMeasurer(theme)
    rows := []
    for text in ["one", "two", "three"]
        rows.Push({Text: text, Detail: "", Icon: 0, Letter: ""})
    shown := LegendOverlay.ShowPicker({Title: "t", Rows: rows, Empty: "", SelectedIndex: 2}, theme, m, "f", 400)
    try
        T.Eq(shown.Selection.Index, 2)
    finally
        shown.Destroy(), m.Destroy()
}
