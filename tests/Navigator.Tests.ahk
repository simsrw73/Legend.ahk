#Requires AutoHotkey v2.0

; "Zen" fits one screen; "komorebi" (21 rows) does not with 5 rows per screen.
Navigator_New() {
    r := Registry_New()
    r.Page("Zen", "ahk_exe zen.exe")
    r.Bind(["Zen", "Tabs"], "^t", "new tab", Noop)
    r.Bind(["Zen", "Tabs"], "^w", "close tab", Noop)
    for c, cat in ["Focus", "Resize", "Workspaces"]
        loop 3
            r.Bind(["komorebi", cat], "!" Chr(96 + (c - 1) * 3 + A_Index), cat " " A_Index, Noop)
    loop 8
        r.Bind(["komorebi", "Long"], "^!" A_Index, "long " A_Index, Noop)
    nav := LegendNavigator(r.SortedPages(), rows => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    nav.Registry := r
    return nav
}

T.Test("Navigator: no match opens the index", Navigator_Index)
Navigator_Index() {
    nav := Navigator_New()
    nav.Open([])
    T.Eq(nav.View.Title, "Legend")
    T.True(nav.ClaimsLetters)
    T.Eq(nav.Stack[1].Items[1].Letter, "k")
    T.Eq(nav.Stack[1].Items[2].Letter, "z")
}

T.Test("Navigator: drill into a small page shows it flat", Navigator_FlatPage)
Navigator_FlatPage() {
    nav := Navigator_New()
    nav.Open([])
    T.Eq(nav.Press("z"), "redraw")
    T.Eq(nav.View.Title, "Zen")
    T.True(!nav.ClaimsLetters)
    T.Eq(nav.Press("x"), "pass")
    T.Eq(nav.Press("Backspace"), "redraw")
    T.Eq(nav.View.Title, "Legend")
    T.Eq(nav.Press("Backspace"), "none")
}

T.Test("Navigator: one match opens that page above the index", Navigator_OneMatch)
Navigator_OneMatch() {
    nav := Navigator_New()
    nav.Open([nav.Registry.Page("Zen")])
    T.Eq(nav.View.Title, "Zen")
    T.Eq(nav.Stack.Length, 2)
    nav.Press("Backspace")
    T.Eq(nav.View.Title, "Legend")
}

T.Test("Navigator: several matches open an index of them", Navigator_ManyMatches)
Navigator_ManyMatches() {
    nav := Navigator_New()
    nav.Open([nav.Registry.Page("komorebi"), nav.Registry.Page("Zen")])
    T.Eq(nav.View.Title, "Legend › this window")
    T.Eq(nav.Stack[2].Items.Length, 2)
}

T.Test("Navigator: a large page lists categories", Navigator_ListedPage)
Navigator_ListedPage() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("k")
    T.True(nav.ClaimsLetters)
    labels := ""
    for item in nav.Level.Items
        labels .= item.Letter "=" item.Label " "
    T.Eq(labels, "f=Focus r=Resize w=Workspaces l=Long ")
    T.Eq(nav.Press("q"), "none")
    T.Eq(nav.Press("r"), "redraw")
    T.Eq(nav.View.Title, "komorebi › Resize")
}

T.Test("Navigator: paging", Navigator_Paging)
Navigator_Paging() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("k"), nav.Press("l")
    T.Eq(nav.View.ScreenCount, 2)
    T.Eq(nav.Press("Prev"), "none")
    T.Eq(nav.Press("Next"), "redraw")
    T.Eq(nav.View.ScreenIndex, 2)
    T.Eq(nav.Press("Next"), "none")
    T.Eq(nav.Press("Prev"), "redraw")
}

T.Test("Navigator: pin keeps the overlay through combos and focus changes", Navigator_Pin)
Navigator_Pin() {
    nav := Navigator_New()
    nav.Open([])
    T.Eq(nav.Press("Combo"), "close")
    T.Eq(nav.Press("Pin"), "redraw")
    T.True(nav.Pinned)
    T.Eq(nav.Press("Combo"), "none")
    T.Eq(nav.Press("FocusLost"), "none")
    T.Eq(nav.Press("Close"), "close")
    nav.Press("Pin")
    T.Eq(nav.Press("FocusLost"), "close")
}

T.Test("Navigator: letters prefer fixed, then the name, then the pool", Navigator_Letters)
Navigator_Letters() {
    items := [{N: "Zed", F: ""}, {N: "Zen", F: "z"}, {N: "!!", F: ""}, {N: "Zoo", F: "e"}]
    letters := LegendNavigator.AssignLetters(items, i => i.N, i => i.F)
    T.Eq(letters[2], "z")
    T.Eq(letters[4], "e")
    T.Eq(letters[1], "d")
    T.Eq(letters[3], "a")
}

T.Test("Navigator: more than 36 items leaves the rest without letters", Navigator_LetterOverflow)
Navigator_LetterOverflow() {
    items := []
    loop 40
        items.Push({N: "page " A_Index})
    letters := LegendNavigator.AssignLetters(items, i => i.N, i => "")
    seen := Map()
    loop 36 {
        T.True(letters[A_Index] != "" && !seen.Has(letters[A_Index]), "letter " A_Index)
        seen[letters[A_Index]] := true
    }
    T.Eq(letters[40], "")
}

T.Test("Navigator: footer hints follow the view", Navigator_Footer)
Navigator_Footer() {
    nav := Navigator_New()
    nav.Open([])
    T.True(InStr(nav.Footer(), "a–z open"))
    T.True(!InStr(nav.Footer(), "back"))
    nav.Press("k"), nav.Press("l")
    T.True(InStr(nav.Footer(), "⌫ back"))
    T.True(InStr(nav.Footer(), "1/2"))
    nav.Press("Pin")
    T.True(InStr(nav.Footer(), "`` unpin"))
}
