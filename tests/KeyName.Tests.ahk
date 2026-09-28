#Requires AutoHotkey v2.0

T.Test("KeyName: AHK modifiers parse in canonical order", KeyName_AhkOrder)
KeyName_AhkOrder() {
    T.Eq(LegendKeyName.FromHotkey("+!h").Id, "Alt+Shift+H")
    T.Eq(LegendKeyName.FromHotkey("!+h").Id, "Alt+Shift+H")
    T.Eq(LegendKeyName.FromHotkey("~$^a").Id, "Ctrl+A")
}

T.Test("KeyName: AHK punctuation and named keys", KeyName_AhkSpecial)
KeyName_AhkSpecial() {
    T.Eq(LegendKeyName.FromHotkey("^;").Id, "Ctrl+;")
    T.Eq(LegendKeyName.FromHotkey("!=").Id, "Alt+=")
    T.Eq(LegendKeyName.FromHotkey("!+").Id, "Alt++")
    T.Eq(LegendKeyName.FromHotkey("#Space").Id, "Win+Space")
    T.Eq(LegendKeyName.FromHotkey("!+Enter").Id, "Alt+Shift+Enter")
    T.Eq(LegendKeyName.FromHotkey("!``").Id, "Alt+``")
    T.Eq(LegendKeyName.FromHotkey("F5").Id, "F5")
}

T.Test("KeyName: unusual AHK hotkeys stay verbatim", KeyName_AhkVerbatim)
KeyName_AhkVerbatim() {
    T.Eq(LegendKeyName.FromHotkey("a & b").Id, "=a & b")
    T.Eq(LegendKeyName.FromHotkey("sc029").Id, "=sc029")
    T.Eq(LegendKeyName.FromHotkey("^a up").Id, "=^a up")
}

T.Test("KeyName: written notation matches AHK notation", KeyName_TextMatchesAhk)
KeyName_TextMatchesAhk() {
    T.Eq(LegendKeyName.FromText("Alt+Shift+H").Id, LegendKeyName.FromHotkey("!+h").Id)
    T.Eq(LegendKeyName.FromText("shift+ctrl+t").Id, "Ctrl+Shift+T")
    T.Eq(LegendKeyName.FromText("Win+Space").Id, LegendKeyName.FromHotkey("#Space").Id)
}

T.Test("KeyName: written punctuation, aliases and arrows", KeyName_TextSpecial)
KeyName_TextSpecial() {
    T.Eq(LegendKeyName.FromText("Ctrl+|").Id, "Ctrl+|")
    T.Eq(LegendKeyName.FromText("Ctrl++").Id, "Ctrl++")
    T.Eq(LegendKeyName.FromText("Ctrl+Plus").Id, "Ctrl++")
    T.Eq(LegendKeyName.FromText("Ctrl+=").Id, "Ctrl+=")
    T.Eq(LegendKeyName.FromText("Ctrl+Escape").Id, "Ctrl+Esc")
    T.Eq(LegendKeyName.FromText("Win+→").Id, "Win+Right")
    T.Eq(LegendKeyName.FromText("Ctrl+PageDown").Id, "Ctrl+PgDn")
    T.Eq(LegendKeyName.FromText("F12").Id, "F12")
    T.Eq(LegendKeyName.FromText("Ctrl+``").Id, "Ctrl+``")
}

T.Test("KeyName: ranges and sequences stay verbatim", KeyName_TextVerbatim)
KeyName_TextVerbatim() {
    T.Eq(LegendKeyName.FromText("Ctrl+1–8").Id, "=Ctrl+1–8")
    T.Eq(LegendKeyName.FromText("Alt+H/J/K/L").Id, "=Alt+H/J/K/L")
    T.Eq(LegendKeyName.FromText("Ctrl+K Ctrl+S").Id, "=Ctrl+K Ctrl+S")
}

T.Test("KeyName: unknown written keys throw", KeyName_TextErrors)
KeyName_TextErrors() {
    T.Throws(() => LegendKeyName.FromText("Ctrl+Entr"), "typo")
    T.Throws(() => LegendKeyName.FromText("Ctrl+"), "dangling plus")
    T.Throws(() => LegendKeyName.FromText(""), "empty")
}

T.Test("KeyName: FromParts matches FromHotkey", KeyName_FromParts)
KeyName_FromParts() {
    T.Eq(LegendKeyName.FromParts(["Alt"], "/").Id, LegendKeyName.FromHotkey("!/").Id)
    T.Eq(LegendKeyName.FromParts(["Shift", "Ctrl"], "escape").Id, "Ctrl+Shift+Esc")
}

T.Test("KeyName: format styles", KeyName_Format)
KeyName_Format() {
    k := LegendKeyName.FromText("Alt+Shift+H")
    T.Eq(LegendKeyName.Format(k, "text"), "Alt+Shift+H")
    T.Eq(LegendKeyName.Format(k, "symbols"), "⌥⇧H")
    T.Eq(LegendKeyName.Format(k, "ahk"), "!+h")
    T.Eq(LegendKeyName.Format(LegendKeyName.FromText("Ctrl+Enter"), "symbols"), "⌃↵")
    T.Eq(LegendKeyName.Format(LegendKeyName.FromText("Win+Space"), "ahk"), "#Space")
    v := LegendKeyName.FromText("Ctrl+1–8")
    T.Eq(LegendKeyName.Format(v, "symbols"), "Ctrl+1–8")
}

T.Test("KeyName: legend line lists used modifiers in order", KeyName_LegendLine)
KeyName_LegendLine() {
    T.Eq(LegendKeyName.LegendLine(["Win", "Ctrl", "Ctrl"], "symbols"), "⊞ Win   ⌃ Ctrl")
    T.Eq(LegendKeyName.LegendLine(["Alt"], "ahk"), "! Alt")
    T.Eq(LegendKeyName.LegendLine(["Alt"], "text"), "")
    T.Eq(LegendKeyName.LegendLine([], "symbols"), "")
}

T.Test("KeyName: modifier prefixes per style", KeyName_FormatMods)
KeyName_FormatMods() {
    T.Eq(LegendKeyName.FormatMods(["Ctrl", "Shift"], "text"), "Ctrl+Shift+")
    T.Eq(LegendKeyName.FormatMods(["Ctrl", "Shift"], "symbols"), "⌃⇧")
    T.Eq(LegendKeyName.FormatMods(["Ctrl", "Shift"], "ahk"), "^+")
    T.Eq(LegendKeyName.FormatMods([], "text"), "")
}

T.Test("KeyName: sequences format step by step", KeyName_Sequence)
KeyName_Sequence() {
    seq := LegendKeyName.Sequence([LegendKeyName.FromHotkey("#Space"), LegendKeyName.FromText("Ctrl+S")])
    T.Eq(LegendKeyName.Format(seq, "text"), "Win+Space Ctrl+S")
    T.Eq(LegendKeyName.Format(seq, "ahk"), "#Space ^s")
    T.Eq(seq.Id, "=Win+Space Ctrl+S")
    T.Eq(seq.Mods.Length, 2)
    T.Eq(LegendKeyName.FromText("Alt+H").Display("symbols"), "⌥H")
}
