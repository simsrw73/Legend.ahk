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
    nav := LegendNavigator(r.SortedPages(), (rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
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
    T.True(InStr(nav.Footer(), "↵ open"))
    T.True(!InStr(nav.Footer(), "back"))
    nav.Press("k"), nav.Press("l")
    T.True(InStr(nav.Footer(), "⌫ back"))
    T.True(InStr(nav.Footer(), "1/2"))
    nav.Press("Pin")
    T.True(InStr(nav.Footer(), "`` unpin"))
}

T.Test("Navigator: relayout keeps the level and clamps the screen", Navigator_Relayout)
Navigator_Relayout() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("k"), nav.Press("l"), nav.Press("Next")
    T.Eq(nav.View.ScreenIndex, 2)
    nav.Press("Pin")
    nav.Relayout((rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 10000, 1), "symbols")
    T.Eq(nav.Stack.Length, 3)
    T.Eq(nav.View.Title, "komorebi › Long")
    T.Eq(nav.View.ScreenCount, 1)
    T.Eq(nav.View.ScreenIndex, 1)
    T.True(nav.Pinned, "pin kept")
    T.Eq(nav.View.Columns[1].Rows[1].Key, "⌃⌥1", "new style applied")
    nav.Press("Backspace")
    T.Eq(nav.View.Title, "komorebi")
    T.True(!nav.ClaimsLetters, "page now fits and is shown flat")
}

T.Test("Navigator: footer includes display hints", Navigator_FooterExtras)
Navigator_FooterExtras() {
    nav := Navigator_New()
    nav.Open([])
    f := nav.Footer("tab text", "= comfortable")
    T.True(InStr(f, "tab text") && InStr(f, "= comfortable"), f)
}

Navigator_Chord() => LegendChord("#Space", "Launch", [
    LegendChordItem("z", "Zed", Noop),
    LegendChordItem("w", "Research", "", [LegendChordItem("b", "Brave", Noop)]),
    LegendChordItem("t", "Hidden", Noop, "", {If: () => false}),
    LegendChordItem("t", "Shown", Noop)
])

Navigator_ChordNav() {
    nav := LegendNavigator([], (rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    nav.OpenChord(Navigator_Chord())
    return nav
}

T.Test("Navigator: chord levels show visible items", Navigator_ChordLevel)
Navigator_ChordLevel() {
    nav := Navigator_ChordNav()
    T.Eq(nav.Mode, "chord")
    T.Eq(nav.View.Title, "Launch")
    texts := ""
    for row in nav.View.Columns[1].Rows
        texts .= row.Key "=" row.Text ";"
    T.Eq(texts, "z=Zed;w=Research ›;t=Shown;")
    T.True(!nav.ClaimsLetters)
}

T.Test("Navigator: chord presses descend, run or miss", Navigator_ChordPress)
Navigator_ChordPress() {
    nav := Navigator_ChordNav()
    T.Eq(nav.PressChord(LegendKeyName.FromText("x")), "miss")
    T.Eq(nav.PressChord(LegendKeyName.FromText("w")), "redraw")
    T.Eq(nav.View.Title, "Launch › Research")
    T.Eq(nav.PressChord(LegendKeyName.FromText("b")), "run")
    T.Eq(nav.RunItem.Label, "Brave")
    T.Eq(nav.Press("Backspace"), "redraw")
    T.Eq(nav.View.Title, "Launch")
    T.Eq(nav.PressChord(LegendKeyName.FromText("t")), "run")
    T.Eq(nav.RunItem.Label, "Shown")
}

T.Test("Navigator: chord footer and relayout", Navigator_ChordFooter)
Navigator_ChordFooter() {
    nav := Navigator_ChordNav()
    nav.PressChord(LegendKeyName.FromText("w"))
    f := nav.Footer("tab text")
    T.True(InStr(f, "esc close") && InStr(f, "⌫ back") && InStr(f, "tab text"), f)
    T.True(!InStr(f, "pin"), f)
    nav.Relayout((rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 1000, 1), "ahk")
    T.Eq(nav.View.Title, "Launch › Research")
    T.Eq(nav.Stack.Length, 2)
}

T.Test("Navigator: titles with no letters or digits take letters from the pool", Navigator_NoLetterTitles)
Navigator_NoLetterTitles() {
    items := [{N: "→ ←"}, {N: "日本語"}, {N: "a"}, {N: ""}]
    letters := LegendNavigator.AssignLetters(items, i => i.N, i => "")
    T.Eq(letters[1], "a")
    T.Eq(letters[2], "b")
    T.Eq(letters[3], "c")   ; its own "a" is taken
    T.Eq(letters[4], "d")
}

; Seven one-entry pages: the index has 7 items, 5 per screen (FakeMeasure rows are 20 px).
Navigator_Many() {
    r := Registry_New()
    loop 7
        r.Bind(["Page " A_Index, "c"], "^!F" A_Index, "x", Noop)
    nav := LegendNavigator(r.SortedPages(), (rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    nav.Open([])
    return nav
}

T.Test("Navigator: the menu cursor starts on the first item and wraps", Navigator_CursorWraps)
Navigator_CursorWraps() {
    nav := Navigator_Many()
    T.Eq(nav.Level.Cursor, 1)
    T.Eq(nav.Press("Up"), "redraw")
    T.Eq(nav.Level.Cursor, 7)
    T.Eq(nav.View.ScreenIndex, 2)
    nav.Press("Down")
    T.Eq(nav.Level.Cursor, 1)
    T.Eq(nav.View.ScreenIndex, 1)
}

T.Test("Navigator: the screen follows the cursor; paging moves it to the screen's first item", Navigator_CursorFollowsScreen)
Navigator_CursorFollowsScreen() {
    nav := Navigator_Many()
    loop 5
        nav.Press("Down")
    T.Eq(nav.Level.Cursor, 6)
    T.Eq(nav.View.ScreenIndex, 2)
    nav.Press("Prev")
    T.Eq(nav.View.ScreenIndex, 1)
    T.Eq(nav.Level.Cursor, 1)
    nav.Press("Next")
    T.Eq(nav.Level.Cursor, 6)
}

T.Test("Navigator: Enter opens the selected item and the view marks it", Navigator_CursorEnter)
Navigator_CursorEnter() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("Down")
    T.Eq(nav.View.SelectedIndex, 2)
    T.Eq(nav.Press("Enter"), "redraw")
    T.Eq(nav.View.Title, "Zen")
}

T.Test("Navigator: Backspace returns with the cursor on the first item", Navigator_CursorBack)
Navigator_CursorBack() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("k")
    nav.Press("Down"), nav.Press("Down")
    T.Eq(nav.Level.Cursor, 3)
    nav.Press("r")
    nav.Press("Backspace")
    T.Eq(nav.View.Title, "komorebi")
    T.Eq(nav.Level.Cursor, 1)
}

T.Test("Navigator: flat pages ignore Down, Up and Enter", Navigator_CursorFlat)
Navigator_CursorFlat() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("z")
    T.Eq(nav.Level.Cursor, 0)
    T.Eq(nav.Press("Down"), "none")
    T.Eq(nav.Press("Up"), "none")
    T.Eq(nav.Press("Enter"), "none")
}

T.Test("Navigator: relayout keeps the selected item", Navigator_CursorRelayout)
Navigator_CursorRelayout() {
    nav := Navigator_Many()
    loop 5
        nav.Press("Down")
    nav.Relayout((rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 10000, 1), "text")
    T.Eq(nav.Level.Cursor, 6)
    T.Eq(nav.View.ScreenIndex, 1)
}

T.Test("Navigator: footers use the shared key names", Navigator_FooterKeys)
Navigator_FooterKeys() {
    nav := Navigator_Many()
    f := nav.Footer()
    T.True(InStr(f, "↵ open   ·   ^n/^p move   ·   ^f/^b 1/2"), f)
    T.True(!InStr(f, "spc/") && !InStr(f, "a–z"), f)
    nav.Press("Enter")
    f := nav.Footer()
    T.True(!InStr(f, "↵ open") && !InStr(f, "^n/^p"), f)
    chord := LegendNavigator([], (rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    items := []
    loop 7
        items.Push(LegendChordItem(Chr(96 + A_Index), "item " A_Index, Noop))
    chord.OpenChord(LegendChord("#Space", "Many", items))
    f := chord.Footer()
    T.True(InStr(f, "esc close   ·   ⌫ back   ·   ^f/^b 1/2"), f)
}

T.Test("Navigator: LayoutKey ignores cursor moves within a screen", Navigator_LayoutKey)
Navigator_LayoutKey() {
    nav := Navigator_Many()
    key := nav.LayoutKey
    nav.Press("Down")
    T.Eq(nav.LayoutKey, key, "cursor move")
    T.Eq(nav.SelectedIndex, 2)
    T.Eq(nav.View.SelectedIndex, 2)
    loop 4
        nav.Press("Down")
    T.True(nav.LayoutKey != key, "next screen")
    T.Eq(nav.SelectedIndex, 1, "item 6 is first on screen 2")
    key := nav.LayoutKey
    nav.Press("Pin")
    T.True(nav.LayoutKey != key, "pin")
    key := nav.LayoutKey
    nav.Relayout((rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 100, 1), "text")
    T.True(nav.LayoutKey != key, "relayout")
    key := nav.LayoutKey
    nav.Press("Enter")
    T.True(nav.LayoutKey != key, "opened a level")
    T.Eq(nav.SelectedIndex, 0, "flat page")
    key := nav.LayoutKey
    nav.Press("Backspace")
    T.True(nav.LayoutKey != key, "back")
}

T.Test("Navigator: the cursor walks down columns and across screens", Navigator_CursorColumns)
Navigator_CursorColumns() {
    r := Registry_New()
    loop 7
        r.Bind(["Page " A_Index, "c"], "^!F" A_Index, "x", Noop)
    ; 3 rows per column, 2 columns per screen: screen 1 holds items 1–6, screen 2 item 7
    nav := LegendNavigator(r.SortedPages(), (rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 60, 2))
    nav.Open([])
    T.Eq(nav.View.Columns.Length, 2)
    loop 3
        nav.Press("Down")
    T.Eq(nav.Level.Cursor, 4, "top of column 2")
    T.Eq(nav.View.ScreenIndex, 1)
    T.Eq(nav.SelectedIndex, 4)
    loop 3
        nav.Press("Down")
    T.Eq(nav.Level.Cursor, 7)
    T.Eq(nav.View.ScreenIndex, 2)
    T.Eq(nav.SelectedIndex, 1)
    nav.Press("Prev")
    T.Eq(nav.Level.Cursor, 1)
    nav.Press("Next")
    T.Eq(nav.Level.Cursor, 7, "first item of screen 2")
    nav.Press("Up")
    T.Eq(nav.Level.Cursor, 6)
    T.Eq(nav.View.ScreenIndex, 1)
    T.Eq(nav.SelectedIndex, 6, "bottom of column 2")
}

T.Test("Navigator: layout keys never repeat across navigators", Navigator_LayoutKeyUnique)
Navigator_LayoutKeyUnique() {
    first := Navigator_Many()
    second := Navigator_Many()
    T.True(first.LayoutKey != second.LayoutKey, first.LayoutKey " = " second.LayoutKey)
}

T.Test("Navigator: paginate is told whether it lays out a page, a menu or a chord", Navigator_PaginateKinds)
Navigator_PaginateKinds() {
    kinds := []
    record := (rows, kind) => (kinds.Push(kind), LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    r := Registry_New()
    r.Bind(["Zen", "Tabs"], "^t", "new tab", Noop)
    nav := LegendNavigator(r.SortedPages(), record)
    nav.Open([])
    nav.Press("Enter")
    T.Eq(kinds[1], "menu", "the index")
    T.Eq(kinds[2], "page", "a page")
    chord := LegendNavigator([], record)
    chord.OpenChord(LegendChord("#F12", "Launch", [Legend.Run("z", "Zed", Noop)]))
    T.Eq(kinds[3], "chord")
}
