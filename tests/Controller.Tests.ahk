#Requires AutoHotkey v2.0

; Uses the Legend facade and real (off-screen, non-activating) windows.

T.Test("Controller: keys that arrive while the source runs are applied after open", Controller_EarlyKeys)
Controller_EarlyKeys() {
    items := [{Text: "one"}, {Text: "two"}, {Text: "three"}]
    source := (*) => (Legend.PickerKeyDown(0x4A, 0x24), items)   ; j pressed while loading
    picker := LegendPicker("^!+F9", "Early", source, {OnPick: Noop})
    Legend.OpenPicker(picker)
    try
        T.Eq(picker.Cursor, 2, "the j typed during the source moved the cursor")
    finally
        Legend.ClosePicker(false)
}

T.Test("Peek: the outline sits just below the overlay", Peek_OutlineBelowOverlay)
Peek_OutlineBelowOverlay() {
    static GW_HWNDNEXT := 2
    overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    overlay.Show("NA x-3000 y-3000 w50 h50")
    frame := LegendPeek.Frame({X: -2900, Y: -2900, W: 40, H: 40}, "89B4FA", 4, overlay.Hwnd)
    try
        T.Eq(DllCall("GetWindow", "Ptr", overlay.Hwnd, "UInt", GW_HWNDNEXT, "Ptr"), frame.Hwnd)
    finally
        frame.Destroy(), overlay.Destroy()
}

T.Test("Peek: a peeked window the user activated is not pushed back", Peek_KeepsActivated)
Peek_KeepsActivated() {
    T.True(!LegendPeek.ShouldRestore(true, 0x10, 0x20, 0x10), "user activated the peeked window")
    T.True(LegendPeek.ShouldRestore(true, 0x10, 0x20, 0x30))
    T.True(!LegendPeek.ShouldRestore(false, 0x10, 0x20, 0x30), "restore not asked")
    T.True(!LegendPeek.ShouldRestore(true, 0x10, 0, 0x30), "no anchor")
}
