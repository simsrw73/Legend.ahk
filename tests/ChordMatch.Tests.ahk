#Requires AutoHotkey v2.0

ChordMatch_Hit(pattern, text) => LegendChordMatch.Matches(LegendChordMatch.Parse(pattern), LegendKeyName.FromText(text))

T.Test("ChordMatch: exact keys compare modifiers exactly", ChordMatch_Exact)
ChordMatch_Exact() {
    T.True(ChordMatch_Hit("z", "z"))
    T.True(!ChordMatch_Hit("z", "Ctrl+Z"), "plain z vs Ctrl+Z")
    T.True(ChordMatch_Hit("^s", "Ctrl+S"))
    T.True(!ChordMatch_Hit("^s", "s"))
    T.True(ChordMatch_Hit("Space", "Space"))
    T.True(ChordMatch_Hit("F5", "F5"))
    T.True(ChordMatch_Hit("+", "+"))
}

T.Test("ChordMatch: ? matches any single character key", ChordMatch_Any)
ChordMatch_Any() {
    for text in ["a", "9", ";"]
        T.True(ChordMatch_Hit("?", text), text)
    for text in ["F1", "PgUp", "Space"]
        T.True(!ChordMatch_Hit("?", text), text)
}

T.Test("ChordMatch: globs match named keys only", ChordMatch_Glob)
ChordMatch_Glob() {
    T.True(ChordMatch_Hit("F*", "F1"))
    T.True(ChordMatch_Hit("F*", "F12"))
    T.True(!ChordMatch_Hit("F*", "f"), "letter F")
    T.True(ChordMatch_Hit("*PgUp", "PgUp"))
    T.True(ChordMatch_Hit("Num*", "Numpad1"))
}

T.Test("ChordMatch: ranges by character code, with modifiers", ChordMatch_Range)
ChordMatch_Range() {
    T.True(ChordMatch_Hit("a-f", "c"))
    T.True(!ChordMatch_Hit("a-f", "g"))
    T.True(ChordMatch_Hit("1-9", "5"))
    T.True(!ChordMatch_Hit("1-9", "0"))
    T.True(ChordMatch_Hit(":-@", ";"))
    T.True(ChordMatch_Hit("^a-f", "Ctrl+B"))
    T.True(!ChordMatch_Hit("^a-f", "b"))
}

T.Test("ChordMatch: unknown key names throw", ChordMatch_Unknown)
ChordMatch_Unknown() {
    T.Throws(() => LegendChordMatch.Parse("Entr"))
    T.Throws(() => LegendChordMatch.Parse("zz"))
}

T.Test("ChordMatch: display per style", ChordMatch_Display)
ChordMatch_Display() {
    T.Eq(LegendChordMatch.Parse("z").Display(), "z")
    T.Eq(LegendChordMatch.Parse("^s").Display("text"), "Ctrl+S")
    T.Eq(LegendChordMatch.Parse("^s").Display("symbols"), "⌃S")
    T.Eq(LegendChordMatch.Parse("^s").Display("ahk"), "^s")
    T.Eq(LegendChordMatch.Parse("1-9").Display(), "1–9")
    T.Eq(LegendChordMatch.Parse("^a-f").Display("symbols"), "⌃a–f")
    T.Eq(LegendChordMatch.Parse("Space").Display(), "Space")
    T.Eq(LegendChordMatch.Parse("F*").Display(), "F*")
    T.Eq(LegendChordMatch.Parse("?").Display(), "?")
}

T.Test("ChordMatch: an uppercase letter means Shift + that letter", ChordMatch_Uppercase)
ChordMatch_Uppercase() {
    T.True(ChordMatch_Hit("Z", "Shift+Z"))
    T.True(!ChordMatch_Hit("Z", "z"), "Z is not plain z")
    T.True(!ChordMatch_Hit("z", "Shift+Z"), "z is not Shift+Z")
    T.True(ChordMatch_Hit("+z", "Shift+Z"))
    T.True(ChordMatch_Hit("^Z", "Ctrl+Shift+Z"))
}

T.Test("ChordMatch: Shift + a letter shows as the capital", ChordMatch_ShiftDisplay)
ChordMatch_ShiftDisplay() {
    T.Eq(LegendChordMatch.Parse("Z").Display(), "Z")
    T.Eq(LegendChordMatch.Parse("+z").Display(), "Z")
    T.Eq(LegendChordMatch.Parse("Z").Display("symbols"), "Z")
    T.Eq(LegendChordMatch.Parse("z").Display(), "z")
    T.Eq(LegendChordMatch.Parse("+F5").Display(), "Shift+F5")
    T.Eq(LegendChordMatch.Parse("+;").Display(), "Shift+;")
    T.Eq(LegendChordMatch.Parse("^Z").Display(), "Ctrl+Shift+Z")
}
