#Requires AutoHotkey v2.0

Picker_Key(text) => LegendKeyName.FromText(text)

Picker_Items(n) {
    items := []
    loop n
        items.Push({Text: "item " A_Index, Detail: A_Index <= 2 ? "zen" : "brave"})
    return items
}

; A picker on !s over n items; options are merged over {OnPick: Noop}.
Picker_New(n := 5, options := "") {
    opts := {OnPick: Noop}
    if IsObject(options)
        for name, value in options.OwnProps()
            opts.%name% := value
    picker := LegendPicker("!s", "Test", (*) => Picker_Items(n), opts)
    picker.Open()
    return picker
}

Picker_Letters(picker) {
    out := ""
    for letter in picker.Letters
        out .= letter = "" ? "_" : letter
    return out
}

T.Test("Picker: OnPick is required", Picker_NeedsOnPick)
Picker_NeedsOnPick() {
    T.Throws(() => LegendPicker("!s", "x", (*) => [], {}))
}

T.Test("Picker: Start is clamped; an empty list selects nothing", Picker_Start)
Picker_Start() {
    T.Eq(Picker_New(5, {Start: 2}).Cursor, 2)
    T.Eq(Picker_New(3, {Start: 9}).Cursor, 3)
    empty := Picker_New(0)
    T.Eq(empty.Cursor, 0)
    T.Eq(empty.Selected, "")
    T.Eq(empty.Key(Picker_Key("Enter")), "none")
    T.Eq(empty.Key(Picker_Key("j")), "none")
}

T.Test("Picker: movement wraps; trigger and Shift+trigger step", Picker_Move)
Picker_Move() {
    p := Picker_New(3)
    T.Eq(p.Key(Picker_Key("k")), "redraw")
    T.Eq(p.Cursor, 3, "k from the top wraps")
    p.Key(Picker_Key("j"))
    T.Eq(p.Cursor, 1, "j from the bottom wraps")
    p.Key(Picker_Key("Down")), p.Key(Picker_Key("Ctrl+N"))
    T.Eq(p.Cursor, 3)
    p.Key(Picker_Key("Up")), p.Key(Picker_Key("Ctrl+P"))
    T.Eq(p.Cursor, 1)
    p.Key(Picker_Key("Alt+S"))
    T.Eq(p.Cursor, 2, "trigger moves down")
    p.Key(Picker_Key("Alt+Shift+S"))
    T.Eq(p.Cursor, 1, "Shift+trigger moves up")
    p.Key(Picker_Key("s"))
    T.Eq(p.Cursor, 2, "bare trigger key moves down in normal mode")
    p.Key(Picker_Key("Shift+S"))
    T.Eq(p.Cursor, 1)
}

T.Test("Picker: trigger key with its modifier still held moves", Picker_TriggerHeld)
Picker_TriggerHeld() {
    ; the controller passes the key with the held modifiers (Alt+S); it must not pick
    p := Picker_New(5)
    T.Eq(p.Key(Picker_Key("Alt+S")), "redraw")
    T.Eq(p.Cursor, 2)
}

T.Test("Picker: letters follow the pool, skip hjkl and the trigger key", Picker_LetterPool)
Picker_LetterPool() {
    p := Picker_New(8)
    T.Eq(Picker_Letters(p), "adfg;qwe")
    items := [{Text: "one"}, {Text: "two", Letter: "Q"}, {Text: "three", Letter: "h"}]
    T.Eq(LegendPicker.AssignLetters(items, "S")[2], "q", "fixed letter honoured, lowercased")
    T.Eq(LegendPicker.AssignLetters(items, "S")[3], "d", "h is never assigned")
    many := []
    loop 40
        many.Push({Text: "x"})
    letters := LegendPicker.AssignLetters(many, "S")
    T.Eq(letters[32], "0")
    T.Eq(letters[33], "", "rows beyond the pool get none")
}

T.Test("Picker: a letter picks its row", Picker_LetterPick)
Picker_LetterPick() {
    p := Picker_New(5)
    T.Eq(p.Key(Picker_Key("f")), "pick")
    T.Eq(p.Selected.Text, "item 3")
    T.Eq(p.Key(Picker_Key("Shift+F")), "none", "Shift+letter is not a pick")
}

T.Test("Picker: Enter picks, Esc and Ctrl+G cancel, = asks for density", Picker_Actions)
Picker_Actions() {
    p := Picker_New(5, {Start: 2})
    T.Eq(p.Key(Picker_Key("Enter")), "pick")
    T.Eq(p.Selected.Text, "item 2")
    T.Eq(p.Key(Picker_Key("Esc")), "cancel")
    T.Eq(p.Key(Picker_Key("Ctrl+G")), "cancel")
    T.Eq(p.Key(Picker_Key("=")), "density")
    T.Eq(p.Key(Picker_Key("x")), "none", "a letter with no row")
}

T.Test("Picker: h/l cycle scopes and reload from the source", Picker_Scopes)
Picker_Scopes() {
    seen := []
    source := (scope) => (seen.Push(scope), Picker_Items(StrLen(scope)))
    p := LegendPicker("!s", "Test", source, {OnPick: Noop, Scopes: ["ab", "abc", "abcd"], Scope: "abc"})
    p.Open()
    T.Eq(p.Scope, "abc")
    T.Eq(p.Visible.Length, 3)
    T.Eq(p.Key(Picker_Key("l")), "redraw")
    T.Eq(p.Scope, "abcd")
    p.Key(Picker_Key("l"))
    T.Eq(p.Scope, "ab", "wraps")
    p.Key(Picker_Key("h"))
    T.Eq(p.Scope, "abcd")
    T.Eq(seen.Length, 4)
    T.Eq(p.TitleLine, "Test · abcd")
    T.Eq(Picker_New(3).Key(Picker_Key("l")), "none", "no scopes")
    T.Throws(() => LegendPicker("!s", "x", (*) => [], {OnPick: Noop, Scopes: ["a"], Scope: "b"}))
}

T.Test("Picker: paging by PageSize", Picker_Paging)
Picker_Paging() {
    p := Picker_New(5)
    p.PageSize := 2
    T.Eq(p.ScreenCount, 3)
    T.Eq(p.ScreenRows().Length, 2)
    T.Eq(p.Key(Picker_Key("PgDn")), "redraw")
    T.Eq(p.Cursor, 3)
    T.Eq(p.ScreenIndex, 2)
    p.Key(Picker_Key("PgDn")), p.Key(Picker_Key("PgDn"))
    T.Eq(p.Cursor, 5)
    T.Eq(p.Key(Picker_Key("PgDn")), "none")
    rows := p.ScreenRows()
    T.Eq(rows.Length, 1)
    T.Eq(rows[1].Text, "item 5")
    T.True(rows[1].Selected)
    T.Eq(rows[1].Letter, p.Letters[5])
    p.Key(Picker_Key("PgUp"))
    T.Eq(p.Cursor, 3)
    unpaged := Picker_New(5)
    T.Eq(unpaged.Key(Picker_Key("PgDn")), "none", "PageSize 0 = one screen")
}

T.Test("Picker: the Pickers reference page lists triggers", Picker_Reference)
Picker_Reference() {
    r := Registry_New()
    shown := LegendPicker("!s", "Windows", (*) => [], {OnPick: Noop, Scopes: ["this monitor"]})
    hidden := LegendPicker("!e", "Files", (*) => [], {OnPick: Noop, Reference: false})
    r.AddPicker(shown, Noop)
    r.AddPicker(hidden, Noop)
    T.Eq(r.BindLog.Length, 2)
    entries := Registry_AllEntries(r.Get("Pickers"))
    T.Eq(entries.Length, 1)
    T.Eq(entries[1].Key.Id, "Alt+S")
    T.Eq(entries[1].Description, "Windows · this monitor")
}

Picker_Type(picker, text) {
    for char in StrSplit(text)
        picker.Key(Picker_Key(char = " " ? "Space" : char))
}

T.Test("Picker: / filters by terms over Text and Detail", Picker_Filter)
Picker_Filter() {
    p := Picker_New(5, {Start: 4})
    T.Eq(p.Key(Picker_Key("/")), "redraw")
    T.Eq(p.Mode, "filter")
    T.Eq(p.Letters.Length, 0, "letters hidden")
    Picker_Type(p, "zen")
    T.Eq(p.Query, "zen")
    T.Eq(p.Visible.Length, 2)
    T.Eq(p.Cursor, 1, "first match selected")
    Picker_Type(p, " 2")
    T.Eq(p.Visible.Length, 1)
    T.Eq(p.Selected.Text, "item 2")
    T.Eq(p.TitleLine, "Test / zen 2▏")
    T.Eq(p.Key(Picker_Key("Enter")), "pick")
}

T.Test("Picker: j/k type in filter mode; arrows and Ctrl+N/P move", Picker_FilterKeys)
Picker_FilterKeys() {
    p := Picker_New(5)
    p.Key(Picker_Key("/"))
    Picker_Type(p, "item")
    p.Key(Picker_Key("Down")), p.Key(Picker_Key("Ctrl+N"))
    T.Eq(p.Cursor, 3)
    p.Key(Picker_Key("Up"))
    T.Eq(p.Cursor, 2)
    p.Key(Picker_Key("Alt+S"))
    T.Eq(p.Cursor, 3, "trigger still moves")
    p.Key(Picker_Key("j"))
    T.Eq(p.Query, "itemj")
    T.Eq(p.Key(Picker_Key("=")), "redraw", "= types")
    T.Eq(p.Query, "itemj=")
}

T.Test("Picker: the bare trigger key types in filter mode", Picker_FilterTypesTriggerKey)
Picker_FilterTypesTriggerKey() {
    p := Picker_New(5)
    p.Key(Picker_Key("/"))
    p.Key(Picker_Key("s"))
    T.Eq(p.Query, "s")
    p.Key(Picker_Key("Shift+S"))
    T.Eq(p.Query, "ss", "Shift+letter types lowercase")
}

T.Test("Picker: no match leaves Enter harmless", Picker_FilterNoMatch)
Picker_FilterNoMatch() {
    p := Picker_New(5)
    p.Key(Picker_Key("/"))
    Picker_Type(p, "nothing")
    T.Eq(p.Visible.Length, 0)
    T.Eq(p.Selected, "")
    T.Eq(p.Key(Picker_Key("Enter")), "none")
    T.Eq(p.Key(Picker_Key("Down")), "none")
}

T.Test("Picker: Esc clears the filter and keeps the selection; Esc again cancels", Picker_FilterEscKeepsSelection)
Picker_FilterEscKeepsSelection() {
    p := Picker_New(5)
    p.Key(Picker_Key("/"))
    Picker_Type(p, "brave")
    p.Key(Picker_Key("Down"))
    T.Eq(p.Selected.Text, "item 4")
    T.Eq(p.Key(Picker_Key("Esc")), "redraw")
    T.Eq(p.Mode, "normal")
    T.Eq(p.Query, "")
    T.Eq(p.Visible.Length, 5)
    T.Eq(p.Selected.Text, "item 4")
    T.Eq(Picker_Letters(p), "adfg;")
    T.Eq(p.Key(Picker_Key("Esc")), "cancel")
}

T.Test("Picker: Backspace edits; on an empty query it leaves filter mode", Picker_FilterBackspace)
Picker_FilterBackspace() {
    p := Picker_New(5)
    p.Key(Picker_Key("/"))
    Picker_Type(p, "ze")
    p.Key(Picker_Key("Backspace"))
    T.Eq(p.Query, "z")
    p.Key(Picker_Key("Backspace"))
    T.Eq(p.Query, "")
    T.Eq(p.Mode, "filter")
    p.Key(Picker_Key("Backspace"))
    T.Eq(p.Mode, "normal")
    T.Eq(p.Key(Picker_Key("Ctrl+G")), "cancel")
}

T.Test("Picker: CharOf", Picker_CharOf)
Picker_CharOf() {
    T.Eq(LegendPicker.CharOf(Picker_Key("A")), "a")
    T.Eq(LegendPicker.CharOf(Picker_Key("Shift+A")), "a")
    T.Eq(LegendPicker.CharOf(Picker_Key("Space")), " ")
    T.Eq(LegendPicker.CharOf(Picker_Key("Ctrl+A")), "")
    T.Eq(LegendPicker.CharOf(Picker_Key("F1")), "")
}

T.Test("Picker: a batch of keys applies in order and reports one outcome", Picker_Batch)
Picker_Batch() {
    p := Picker_New(5)
    held := []
    loop 3
        held.Push(Picker_Key("j"))
    r := p.KeyBatch(held)
    T.Eq(r.Action, "redraw")
    T.Eq(p.Cursor, 4)
    T.Eq(p.KeyBatch([Picker_Key("x"), Picker_Key("y")]).Action, "none")
    r := p.KeyBatch([Picker_Key("="), Picker_Key("j"), Picker_Key("=")])
    T.Eq(r.Action, "redraw")
    T.Eq(r.Density, 2)
    r := p.KeyBatch([Picker_Key("j"), Picker_Key("Enter"), Picker_Key("j")])
    T.Eq(r.Action, "pick")
    T.Eq(p.Cursor, 1, "j wrapped 5 → 1, Enter picked, the last j was dropped")
    T.Eq(p.KeyBatch([Picker_Key("Esc"), Picker_Key("k")]).Action, "cancel")
}

T.Test("Picker: LayoutKey changes with the layout, not with the cursor", Picker_LayoutKey)
Picker_LayoutKey() {
    p := Picker_New(5)
    p.PageSize := 3
    first := p.LayoutKey
    p.Key(Picker_Key("j"))
    T.Eq(p.LayoutKey, first, "moving within a screen")
    p.Key(Picker_Key("j")), p.Key(Picker_Key("j"))
    T.True(p.LayoutKey != first, "moving onto the next screen")
    p := Picker_New(5)
    first := p.LayoutKey
    p.Key(Picker_Key("/"))
    T.True(p.LayoutKey != first, "filter mode")
    second := p.LayoutKey
    p.Key(Picker_Key("z"))
    T.True(p.LayoutKey != second, "query typed")
    q := Picker_New(3, {Scopes: ["x", "y"]})
    first := q.LayoutKey
    q.Key(Picker_Key("l"))
    T.True(q.LayoutKey != first, "scope")
}

T.Test("Picker: LayoutKey changes on every load, even to the same array", Picker_LayoutKeyReload)
Picker_LayoutKeyReload() {
    items := Picker_Items(3)
    p := LegendPicker("!s", "Test", (*) => items, {OnPick: Noop, Scopes: ["x", "y"]})
    p.Open()
    first := p.LayoutKey
    p.Key(Picker_Key("l")), p.Key(Picker_Key("h"))   ; same scope, same array object
    T.True(p.LayoutKey != first, "a reload must force a rebuild")
}

T.Test("Picker: Esc from a filter with no match returns to the row selected before /", Picker_FilterEscNoMatch)
Picker_FilterEscNoMatch() {
    p := Picker_New(5, {Start: 2})
    p.Key(Picker_Key("/"))
    Picker_Type(p, "nothing")
    T.Eq(p.Selected, "")
    p.Key(Picker_Key("Esc"))
    T.Eq(p.Selected.Text, "item 2")
}
