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

; Proportional: lists taller than half of maxHeight take the column count whose real
; width / height is closest to the aspect, balanced in height. Entries here are 20
; tall and at most 156 wide.
Layout_Prop(rows, maxHeight, maxColumns, aspect, maxWidth := 0, columnGap := 0) =>
    LegendLayout.Proportional(rows, FakeMeasure, maxHeight, maxColumns, 16, maxWidth, columnGap, aspect)

T.Test("Layout: proportional keeps a small list in one column", Layout_PropSmall)
Layout_PropSmall() {
    screens := Layout_Prop(Layout_Entries(3), 1000, 3, 1.78)
    T.Eq(screens.Length, 1)
    T.Eq(Layout_Counts(screens[1]), "3")
}

T.Test("Layout: proportional keeps a list within half of maxHeight in one column", Layout_PropHalf)
Layout_PropHalf() {
    ; 20 rows = 400 ≤ 1000 / 2: one column, even though two would be closer to 1.78
    T.Eq(Layout_Counts(Layout_Prop(Layout_Entries(20), 1000, 3, 1.78)[1]), "20")
}

T.Test("Layout: proportional judges column counts by their real shape", Layout_PropRealShape)
Layout_PropRealShape() {
    ; 25 rows (500 tall, 156 wide at most): √(1.78·500/156) ≈ 2.4 would say 2 columns,
    ; but 2 measure 312×260 (1.2) and 3 measure 448×180 (2.5): 3 is closer to 1.78
    T.Eq(Layout_Counts(Layout_Prop(Layout_Entries(25), 900, 3, 1.78)[1]), "9,9,7")
}

T.Test("Layout: proportional picks the column count from the aspect", Layout_PropAspect)
Layout_PropAspect() {
    ; 30 rows: 600 tall, 156 wide. √(1.78·600/156) ≈ 2.6 → 3; √(0.5·600/156) ≈ 1.4 → 1
    T.Eq(Layout_Counts(Layout_Prop(Layout_Entries(30), 1000, 3, 1.78)[1]), "10,10,10")
    T.Eq(Layout_Counts(Layout_Prop(Layout_Entries(30), 1000, 3, 0.5)[1]), "30")
}

T.Test("Layout: proportional balances columns the height cap forces", Layout_PropBalance)
Layout_PropBalance() {
    ; a tall aspect wants one column, but 240 > 100 needs three: 4,4,4, not 5,5,2
    T.Eq(Layout_Counts(Layout_Prop(Layout_Entries(12), 100, 3, 0.1)[1]), "4,4,4")
}

T.Test("Layout: proportional never ends a column on a heading", Layout_PropHeading)
Layout_PropHeading() {
    rows := Layout_Entries(4)
    rows.Push(LegendRows.Row("heading", "", "Next"))
    rows.Push(Layout_Entries(3)*)
    ; 8 rows, a tall aspect and a 100 cap → 2 columns; the heading opens the second
    screen := Layout_Prop(rows, 100, 3, 0.1)[1]
    T.Eq(Layout_Counts(screen), "4,4")
    T.Eq(screen[2].Rows[1].Kind, "heading")
}

T.Test("Layout: proportional narrows to fit maxWidth", Layout_PropWidth)
Layout_PropWidth() {
    ; the aspect wants 3 columns (3·156 + 2·20 = 508) but only 2 fit in 340
    T.Eq(Layout_Counts(Layout_Prop(Layout_Entries(30), 1000, 3, 1.78, 340, 20)[1]), "15,15")
}

T.Test("Layout: proportional falls back to vertical screens past maxColumns", Layout_PropScreens)
Layout_PropScreens() {
    screens := Layout_Prop(Layout_Entries(20), 100, 3, 1.78)
    T.Eq(screens.Length, 2)
    T.Eq(Layout_Counts(screens[1]), "5,5,5")
    T.Eq(Layout_Counts(screens[2]), "5")
}

T.Test("Layout: proportional prefers breaking at a category when nearly as even", Layout_PropCategoryBreak)
Layout_PropCategoryBreak() {
    ; A: heading + 6 entries (140), B: heading + 4 (100). The most even split (120) cuts
    ; A; a 140 column (within 20%) ends A, so B starts the second column.
    rows := [LegendRows.Row("heading", "", "A")]
    rows.Push(Layout_Entries(6)*)
    rows.Push(LegendRows.Row("heading", "", "B"))
    rows.Push(Layout_Entries(4)*)
    screen := Layout_Prop(rows, 150, 3, 0.1)[1]
    T.Eq(Layout_Counts(screen), "7,5")
    T.Eq(screen[2].Rows[1].Text, "B")
}
