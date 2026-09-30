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

T.Test("Controller: pickers never reserve room for a key legend line", Controller_NoLegendLine)
Controller_NoLegendLine() {
    picker := LegendPicker("^!+F9", "Legend line", (*) => [{Text: "a"}], {OnPick: Noop})
    Legend.OpenPicker(picker)
    try {
        Legend.BaseTheme["keyStyle"] := "symbols"   ; reloaded on the next open
        T.Eq(Legend.PickerTheme()["legend"], "off")
    } finally
        Legend.ClosePicker(false)
}

T.Test("Controller: OnHighlight gets an empty item when a filter leaves nothing selected", Controller_HighlightNothing)
Controller_HighlightNothing() {
    seen := []
    picker := LegendPicker("^!+F9", "Highlight", (*) => [{Text: "one"}, {Text: "two"}],
        {OnPick: Noop, OnHighlight: item => seen.Push(IsObject(item) ? item.Text : "(none)")})
    Legend.OpenPicker(picker)
    try {
        for keyText in ["/", "z", "z"]
            Legend.PickerKey(LegendKeyName.FromText(keyText))
        T.Eq(seen.Length, 2, "one call at open, one when the list emptied")
        T.Eq(seen[2], "(none)")
        Legend.PickerKey(LegendKeyName.FromText("Esc"))
        T.Eq(seen[3], "one", "a selection again after Esc")
    } finally
        Legend.ClosePicker(false)
}

T.Test("Peek: only visible, non-topmost windows anchor a restore", Peek_Anchor)
Peek_Anchor() {
    hidden := Gui("-Caption +ToolWindow")
    topmost := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    plain := Gui("-Caption +ToolWindow +E0x08000000")
    topmost.Show("NA x-3000 y-3000 w20 h20")
    plain.Show("NA x-3000 y-2900 w20 h20")
    try {
        T.True(!LegendPeek.IsAnchor(hidden.Hwnd), "hidden")
        T.True(!LegendPeek.IsAnchor(topmost.Hwnd), "topmost")
        T.True(LegendPeek.IsAnchor(plain.Hwnd), "visible, not topmost")
    } finally
        hidden.Destroy(), topmost.Destroy(), plain.Destroy()
}

T.Test("Controller: a pending OnCancel runs before the next picker opens", Controller_CancelBeforeReopen)
Controller_CancelBeforeReopen() {
    order := []
    first := LegendPicker("^!+F9", "First", (*) => [{Text: "a"}], {OnPick: Noop, OnCancel: () => order.Push("cancel")})
    second := LegendPicker("^!+F8", "Second", (*) => (order.Push("load"), [{Text: "b"}]), {OnPick: Noop})
    Legend.OpenPicker(first)
    Legend.ClosePicker(true)
    Legend.OpenPicker(second)   ; before the cancel's timer has had a chance to run
    try {
        Sleep(50)
        T.Eq(order.Length, 2)
        T.Eq(order[1], "cancel")
        T.Eq(order[2], "load")
    } finally
        Legend.ClosePicker(false)
}

T.Test("Controller: pickerWidthPercent caps a picker with very long rows", Controller_PickerWidth)
Controller_PickerWidth() {
    T.Eq(LegendTheme.Read("")["pickerWidthPercent"], 60)
    long := ""
    loop 60
        long .= "a very long window title "
    picker := LegendPicker("^!+F9", "Wide", (*) => [{Text: long, Detail: "app"}], {OnPick: Noop})
    Legend.OpenPicker(picker)
    try {
        WinGetPos(, , &overlayW, , Legend.Gui)
        area := LegendOverlay.WorkArea()
        T.True(overlayW <= (area.Right - area.Left) * 60 // 100, "overlay " overlayW " wider than 60%")
    } finally
        Legend.ClosePicker(false)
}

T.Test("Legend: key maps follow the shared scheme", Legend_KeyMaps)
Legend_KeyMaps() {
    T.Eq(Legend.CtrlKeys["^n"], "Down")
    T.Eq(Legend.CtrlKeys["^p"], "Up")
    T.Eq(Legend.CtrlKeys["^f"], "Next")
    T.Eq(Legend.CtrlKeys["^b"], "Prev")
    T.Eq(Legend.MenuKeys["Enter"], "Enter")
    T.Eq(Legend.MenuKeys["Down"], "Down")
    T.Eq(Legend.OverlayKeys["Space"], "Next")
    T.True(!Legend.OverlayKeys.Has("Enter") && !Legend.OverlayKeys.Has("Down"), "never claimed on flat pages or while pinned")
    T.Eq(Legend.ChordOverlayKeys["Ctrl+F"], "Next")
    T.Eq(Legend.ChordOverlayKeys["Ctrl+B"], "Prev")
    T.True(!Legend.ChordOverlayKeys.Has("Ctrl+N") && !Legend.ChordOverlayKeys.Has("Ctrl+P"), "Ctrl+N/P reach chord items")
    w := LegendKeyWatch(LegendKeyName.FromHotkey("!/").Id, Legend.WatchClaims)
    w.Down(0xA2, "LControl")
    T.Eq(w.Down(0x46, "f"), "", "Ctrl+F doesn't close the overlay")
    T.Eq(w.Down(0x42, "b"), "")
}
