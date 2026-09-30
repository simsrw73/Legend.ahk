#Requires AutoHotkey v2.0

; Turns the page model into display rows for LegendLayout and LegendOverlay:
;   {Kind: "heading" | "group" | "entry", Key, Text, Style: "bound" | "doc" | "menu", Mods,
;    Status: true | false | "" (chord items with a running indicator)}
; Empty categories and groups produce nothing.
class LegendRows {
    static ForPage(page, style) {
        rows := []
        for cat in page.Categories {
            body := this.ForCategory(cat, style)
            if !body.Length
                continue
            if cat.Name != ""
                rows.Push(this.Row("heading", "", cat.Name))
            rows.Push(body*)
        }
        return rows
    }

    static ForCategory(cat, style) {
        rows := []
        for group in cat.Groups {
            body := this.ForGroup(group, style)
            if !body.Length
                continue
            if group.Name != ""
                rows.Push(this.Row("group", "", group.Name))
            rows.Push(body*)
        }
        return rows
    }

    ; Entries sharing a Row label collapse into one row, shown as bound only if all
    ; of them are bound. Its text is the first Text set, else the first description.
    static ForGroup(group, style) {
        rows := [], merged := Map()
        for shortcut in group.Entries {
            if shortcut.Row = "" {
                rows.Push(this.Row("entry", LegendKeyName.Format(shortcut.Key, style), shortcut.Description, shortcut.Bound ? "bound" : "doc", shortcut.Key.Mods))
                continue
            }
            if !merged.Has(shortcut.Row) {
                row := this.Row("entry", shortcut.Row, shortcut.Text != "" ? shortcut.Text : shortcut.Description, shortcut.Bound ? "bound" : "doc", shortcut.Key.Mods.Clone())
                row.TextSet := shortcut.Text != ""
                merged[shortcut.Row] := row
                rows.Push(row)
                continue
            }
            row := merged[shortcut.Row]
            if !shortcut.Bound
                row.Style := "doc"
            if !row.TextSet && shortcut.Text != ""
                row.Text := shortcut.Text, row.TextSet := true
            row.Mods.Push(shortcut.Key.Mods*)
        }
        return rows
    }

    ; items: [{Letter, Label}]
    static ForMenu(items) {
        rows := []
        for item in items
            rows.Push(this.Row("entry", item.Letter, item.Label " ›", "menu"))
        return rows
    }

    ; Chord menu items (already filtered by LegendChords.Visible).
    static ForChord(items, style) {
        rows := []
        for item in items
            rows.Push(this.Row("entry", item.Pattern.Display(style), item.Label (item.IsMenu ? " ›" : ""),
                "bound", item.Pattern.Mods, item.StatusNow()))
        return rows
    }

    static Row(kind, key, text, style := "", mods := "", status := "") =>
        {Kind: kind, Key: key, Text: text, Style: style, Mods: IsObject(mods) ? mods : [], Status: status, Selected: false}
}
