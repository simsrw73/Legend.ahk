#Requires AutoHotkey v2.0

KeyWatch_New() => LegendKeyWatch(LegendKeyName.FromHotkey("!/").Id)

T.Test("KeyWatch: Ctrl/Alt/Win shortcuts are combos, tracked from key events", KeyWatch_Combo)
KeyWatch_Combo() {
    w := KeyWatch_New()
    T.Eq(w.Down(0xA2, "LControl"), "")
    T.Eq(w.Down(0x53, "s"), "combo")
    w.Up(0xA2)
    T.Eq(w.Down(0x53, "s"), "letter", "Ctrl released before the next key")
}

T.Test("KeyWatch: the help key and menu-mask keys are ignored", KeyWatch_Ignored)
KeyWatch_Ignored() {
    w := KeyWatch_New()
    w.Down(0xA4, "LAlt")
    T.Eq(w.Down(0xBF, "/"), "", "help key")
    T.Eq(w.Down(0xE8, ""), "", "menu mask")
    T.Eq(w.Down(0xFF, ""), "", "vkFF")
    T.Eq(w.Down(0x48, "h"), "combo")
}

T.Test("KeyWatch: plain and shifted letters are letters, overlay keys are not", KeyWatch_Letters)
KeyWatch_Letters() {
    w := KeyWatch_New()
    T.Eq(w.Down(0x41, "a"), "letter")
    T.Eq(w.Down(0x31, "1"), "letter")
    w.Down(0xA0, "LShift")
    T.Eq(w.Down(0x41, "a"), "letter", "Shift+A")
    w.Up(0xA0)
    for name in ["Space", "Backspace", "Escape", "PgDn", "PgUp", "``"]
        T.Eq(w.Down(0x20, name), "", name)
}

T.Test("KeyWatch: modifiers held before watching can be seeded", KeyWatch_Seed)
KeyWatch_Seed() {
    w := KeyWatch_New()
    w.Seed([0xA4])
    T.Eq(w.Down(0x48, "h"), "combo")
}
