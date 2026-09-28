#Requires AutoHotkey v2.0

Layout_Entries(n) {
    rows := []
    loop n
        rows.Push(LegendRows.Row("entry", "Ctrl+" A_Index, "item " A_Index, "bound"))
    return rows
}

Layout_Counts(screen) {
    out := ""
    for col in screen
        out .= (A_Index > 1 ? "," : "") col.Rows.Length
    return out
}

T.Test("Layout: small content is one screen, one column", Layout_Single)
Layout_Single() {
    screens := LegendLayout.Paginate(Layout_Entries(3), FakeMeasure, 100, 3)
    T.Eq(screens.Length, 1)
    T.Eq(Layout_Counts(screens[1]), "3")
    T.Eq(screens[1][1].Height, 60)
}

T.Test("Layout: overflow fills columns, then screens", Layout_Overflow)
Layout_Overflow() {
    T.Eq(Layout_Counts(LegendLayout.Paginate(Layout_Entries(12), FakeMeasure, 100, 3)[1]), "5,5,2")
    screens := LegendLayout.Paginate(Layout_Entries(20), FakeMeasure, 100, 3)
    T.Eq(screens.Length, 2)
    T.Eq(Layout_Counts(screens[1]), "5,5,5")
    T.Eq(Layout_Counts(screens[2]), "5")
}

T.Test("Layout: a heading never ends a column", Layout_Orphan)
Layout_Orphan() {
    rows := Layout_Entries(4)
    rows.Push(LegendRows.Row("heading", "", "Next"))
    rows.Push(Layout_Entries(1)*)
    screen := LegendLayout.Paginate(rows, FakeMeasure, 100, 3)[1]
    T.Eq(Layout_Counts(screen), "4,2")
    T.Eq(screen[2].Rows[1].Kind, "heading")
    T.Eq(screen[1].Height, 80)
}

T.Test("Layout: widths fit the content", Layout_Widths)
Layout_Widths() {
    rows := [LegendRows.Row("entry", "Ctrl+T", "New tab", "doc"),
             LegendRows.Row("entry", "F1", "Help", "doc"),
             LegendRows.Row("heading", "", "A very long heading")]
    col := LegendLayout.Paginate(rows, FakeMeasure, 1000, 3, 16)[1][1]
    T.Eq(col.KeyWidth, 60)
    T.Eq(col.Width, 190, "heading is widest")
    rows.Pop()
    T.Eq(LegendLayout.Paginate(rows, FakeMeasure, 1000, 3, 16)[1][1].Width, 146)
}

T.Test("Layout: no rows gives one empty screen", Layout_Empty)
Layout_Empty() {
    screens := LegendLayout.Paginate([], FakeMeasure, 100, 3)
    T.Eq(screens.Length, 1)
    T.Eq(screens[1].Length, 0)
}

T.Test("Layout: columns that would pass maxWidth start a new screen", Layout_MaxWidth)
Layout_MaxWidth() {
    ; columns are 136, 156 and 156 wide (key + gap 16 + text; "Ctrl+10" is wider),
    ; so two plus a 20 gap fit in 320 and the third starts a new screen
    screens := LegendLayout.Paginate(Layout_Entries(12), FakeMeasure, 100, 3, 16, 320, 20)
    T.Eq(screens.Length, 2)
    T.Eq(Layout_Counts(screens[1]), "5,5")
    T.Eq(Layout_Counts(screens[2]), "2")
    ; a single column wider than maxWidth still gets a screen of its own
    T.Eq(LegendLayout.Paginate(Layout_Entries(3), FakeMeasure, 100, 3, 16, 50, 20).Length, 1)
}
