#Requires AutoHotkey v2.0

Chord_Key(text) => LegendKeyName.FromText(text)

T.Test("Chord: first item whose If holds wins", Chord_Find)
Chord_Find() {
    active := false
    items := [LegendChordItem("t", "Terminal", Noop, "", {If: () => active}),
              LegendChordItem("t", "TickTick", Noop)]
    T.Eq(LegendChords.Find(items, Chord_Key("t")).Label, "TickTick")
    active := true
    T.Eq(LegendChords.Find(items, Chord_Key("t")).Label, "Terminal")
    T.Eq(LegendChords.Find(items, Chord_Key("x")), "")
}

T.Test("Chord: visible items skip false If and duplicate keys", Chord_Visible)
Chord_Visible() {
    items := [LegendChordItem("t", "A", Noop, "", {If: () => false}),
              LegendChordItem("t", "B", Noop),
              LegendChordItem("t", "C", Noop),
              LegendChordItem("w", "R", "", [])]
    labels := ""
    for item in LegendChords.Visible(items)
        labels .= item.Label
    T.Eq(labels, "BR")
}

T.Test("Chord: actions get the key only when they take a parameter", Chord_RunArguments)
Chord_RunArguments() {
    got := []
    LegendChordItem("1-9", "digit", k => got.Push(k)).Run("5")
    LegendChordItem("a", "plain", () => got.Push("none")).Run("a")
    T.Eq(got[1], "5")
    T.Eq(got[2], "none")
}

T.Test("Chord: menus, status and unknown keys", Chord_ItemBasics)
Chord_ItemBasics() {
    T.True(LegendChordItem("w", "R", "", []).IsMenu)
    T.True(!LegendChordItem("z", "Z", Noop).IsMenu)
    T.Eq(LegendChordItem("z", "Z", Noop, "", {Status: () => 1}).StatusNow(), true)
    T.Eq(LegendChordItem("z", "Z", Noop, "", {Status: () => 0}).StatusNow(), false)
    T.Eq(LegendChordItem("z", "Z", Noop).StatusNow(), "")
    T.Throws(() => LegendChordItem("Entr", "x", Noop))
}

T.Test("Chord: modifiers held from the trigger are ignored until released", Chord_HeldModifiers)
Chord_HeldModifiers() {
    keys := LegendChordKeys([0x5B])          ; LWin still down from Win+Space
    T.Eq(keys.Key("z").Id, "Z")
    T.True(keys.Down(0x5B), "auto-repeat of the held Win is a modifier")
    T.Eq(keys.Key("z").Id, "Z", "still ignored while held")
    keys.Up(0x5B)
    keys.Down(0xA2)                          ; LCtrl pressed after opening
    T.Eq(keys.Key("s").Id, "Ctrl+S")
    T.True(!keys.Down(0x41), "A is not a modifier")
}

T.Test("Chord: the held trigger key's auto-repeat is ignored until released", Chord_TriggerRepeat)
Chord_TriggerRepeat() {
    keys := LegendChordKeys([0x5B], "Space", true)
    T.True(keys.IsTriggerRepeat("Space"), "held trigger key repeats")
    T.True(!keys.IsTriggerRepeat("z"))
    keys.Up(0x20, "Space")
    T.True(!keys.IsTriggerRepeat("Space"), "after release Space is a normal key")
    T.True(!LegendChordKeys([], "Space", false).IsTriggerRepeat("Space"), "trigger not held at open")
}

T.Test("Chord: Alt and Win steps need a menu mask", Chord_NeedsMask)
Chord_NeedsMask() {
    T.True(LegendChordKeys.NeedsMask(LegendKeyName.FromText("Win+X")))
    T.True(LegendChordKeys.NeedsMask(LegendKeyName.FromText("Alt+S")))
    T.True(!LegendChordKeys.NeedsMask(LegendKeyName.FromText("Ctrl+S")))
    T.True(!LegendChordKeys.NeedsMask(LegendKeyName.FromText("z")))
}

T.Test("Chord keys: withStale includes modifiers held since open", Chord_KeyWithStale)
Chord_KeyWithStale() {
    keys := LegendChordKeys([0xA4], "s", true)   ; LAlt held when the picker opened
    T.Eq(keys.Key("s").Id, "S")
    T.Eq(keys.Key("s", true).Id, "Alt+S")
    keys.Down(0xA0)                               ; LShift pressed after open
    T.Eq(keys.Key("s", true).Id, "Alt+Shift+S")
    keys.Up(0xA4)
    T.Eq(keys.Key("s", true).Id, "Shift+S")
}
