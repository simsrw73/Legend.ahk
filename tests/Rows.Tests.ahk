#Requires AutoHotkey v2.0

Rows_Kinds(rows) {
    out := ""
    for row in rows
        out .= (A_Index > 1 ? "," : "") row.Kind
    return out
}

T.Test("Rows: page gives headings, groups and entries in order", Rows_PageOrder)
Rows_PageOrder() {
    r := Registry_New()
    r.Bind(["p", "Focus"], "!h", "left", Noop)
    r.Bind(["p", "Resize", "Wide"], "!=", "wider", Noop)
    r.Page("p").Category("Empty")
    rows := LegendRows.ForPage(r.Page("p"), "text")
    T.Eq(Rows_Kinds(rows), "heading,entry,heading,group,entry")
    T.Eq(rows[1].Text, "Focus")
    T.Eq(rows[2].Key, "Alt+H")
    T.Eq(rows[2].Style, "bound")
    T.Eq(rows[4].Text, "Wide")
}

T.Test("Rows: unnamed category and group add no heading", Rows_Unnamed)
Rows_Unnamed() {
    r := Registry_New()
    r.Doc(["p", ""], "F1", "help")
    rows := LegendRows.ForPage(r.Page("p"), "text")
    T.Eq(Rows_Kinds(rows), "entry")
    T.Eq(rows[1].Style, "doc")
}

T.Test("Rows: merged rows collapse and take the first Text", Rows_Merged)
Rows_Merged() {
    r := Registry_New()
    r.Page("p").Category("Focus", [
        ["!h", "focus left", Noop, {Row: "Alt+H/J/K/L"}],
        ["!j", "focus down", Noop, {Row: "Alt+H/J/K/L", Text: "focus ← ↓ ↑ →"}],
        ["!k", "focus up", Noop, {Row: "Alt+H/J/K/L", Text: "ignored"}],
        ["!+l", "move right", Noop]])
    rows := LegendRows.ForCategory(r.Page("p").Categories[1], "text")
    T.Eq(rows.Length, 2)
    T.Eq(rows[1].Key, "Alt+H/J/K/L")
    T.Eq(rows[1].Text, "focus ← ↓ ↑ →")
    T.Eq(rows[1].Style, "bound")
    T.Eq(rows[2].Key, "Alt+Shift+L")
}

T.Test("Rows: a merged row with any doc entry is doc", Rows_MergedDoc)
Rows_MergedDoc() {
    r := Registry_New()
    page := r.Page("p")
    page.Category("Focus", [["!h", "left", Noop, {Row: "Alt+H/L"}]])
    r.AddEntry(page, "Focus", "", LegendKeyName.FromText("Alt+L"), "right", false, {Row: "Alt+H/L"})
    rows := LegendRows.ForCategory(page.Categories[1], "text")
    T.Eq(rows.Length, 1)
    T.Eq(rows[1].Style, "doc")
    T.Eq(rows[1].Text, "left")
}

T.Test("Rows: key style and modifiers", Rows_Style)
Rows_Style() {
    r := Registry_New()
    r.Bind(["p", "c"], "^!h", "x", Noop)
    row := LegendRows.ForPage(r.Page("p"), "symbols")[2]
    T.Eq(row.Key, "⌃⌥H")
    T.Eq(row.Mods.Length, 2)
}

T.Test("Rows: menu rows", Rows_Menu)
Rows_Menu() {
    rows := LegendRows.ForMenu([{Letter: "z", Label: "Zen"}])
    T.Eq(rows[1].Key, "z")
    T.Eq(rows[1].Text, "Zen ›")
    T.Eq(rows[1].Style, "menu")
}

T.Test("Rows: chord rows show key, label, submenu mark and status", Rows_Chord)
Rows_Chord() {
    items := [LegendChordItem("z", "Zed", Noop, "", {Status: () => true}),
              LegendChordItem("w", "Research", "", []),
              LegendChordItem("^s", "Save", Noop)]
    rows := LegendRows.ForChord(items, "symbols")
    T.Eq(rows[1].Key, "z")
    T.Eq(rows[1].Status, true)
    T.Eq(rows[2].Text, "Research ›")
    T.Eq(rows[2].Status, "")
    T.Eq(rows[3].Key, "⌃S")
    T.Eq(rows[3].Style, "bound")
}
