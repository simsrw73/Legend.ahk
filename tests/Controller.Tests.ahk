#Requires AutoHotkey v2.0

; Uses the Legend facade and real (off-screen, non-activating) windows.

T.Test("Switcher: highlights forward the current render context to peek", Switcher_RenderContext)
Switcher_RenderContext() {
    local clears, context, highlight, seen, switcher, win
    context := {Outline: "123ABC", Below: 0xBEEF}
    seen := [], clears := [], win := {Hwnd: 0xCAFE}
    switcher := LegendWindowSwitcher("^!+F9", {RenderContext: () => context})
    switcher.Peek := {Show: (self, candidate, outline := "", below := 0) => seen.Push({Win: candidate, Outline: outline, Below: below}),
        Clear: (self, restore) => clears.Push(restore)}
    highlight := switcher.Picker.OnHighlight
    highlight({Data: win})
    T.True(seen[1].Win == win, "candidate reaches the peek boundary")
    T.Eq(seen[1].Outline, "123ABC")
    T.Eq(seen[1].Below, 0xBEEF)
    context := {Outline: "DEF456", Below: 0xFACE}
    highlight({Data: win})
    T.Eq(seen[2].Outline, "DEF456", "context is read on each highlight")
    T.Eq(seen[2].Below, 0xFACE)
    highlight("")
    T.Eq(seen.Length, 2, "empty selection does not show a peek")
    T.Eq(clears.Length, 1)
    T.True(clears[1], "empty selection restores the previous peek")
}

T.Test("Switcher: standalone highlights use a default render context", Switcher_DefaultRenderContext)
Switcher_DefaultRenderContext() {
    local highlight, seen, switcher
    seen := []
    switcher := LegendWindowSwitcher("^!+F9")
    switcher.Peek := {Show: (self, candidate, outline := "", below := -1) => seen.Push({Outline: outline, Below: below})}
    highlight := switcher.Picker.OnHighlight
    highlight({Data: {Hwnd: 0xCAFE}})
    T.Eq(seen[1].Outline, "89B4FA")
    T.Eq(seen[1].Below, 0)
}

T.Test("Peek: Show renders passed color and placement without controller state", Peek_ExplicitRenderContext)
Peek_ExplicitRenderContext() {
    local overlay, peek, savedGui, savedTheme, target
    static GW_HWNDNEXT := 2
    overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    target := Gui("-Caption +ToolWindow +E0x08000000")
    peek := LegendPeek()
    savedTheme := Legend.Theme, savedGui := Legend.Gui
    try {
        overlay.Show("NA x-3000 y-3000 w50 h50")
        target.Show("NA x-2900 y-2900 w40 h40")
        Legend.Theme := Map(), Legend.Gui := {}   ; no outline key or HWND to read
        peek.Show({Hwnd: target.Hwnd, Minimized: false, Cloaked: false}, "123ABC", overlay.Hwnd)
        T.Eq(peek.Outline.BackColor, "123ABC")
        T.Eq(DllCall("GetWindow", "Ptr", overlay.Hwnd, "UInt", GW_HWNDNEXT, "Ptr"), peek.Outline.Hwnd)
        T.Eq(peek.Raised, target.Hwnd)
        peek.Clear(true)
        T.Eq(peek.Raised, 0)
        T.Eq(peek.Outline, "")
    } finally {
        peek.Clear(false)
        Legend.Theme := savedTheme, Legend.Gui := savedGui
        target.Destroy(), overlay.Destroy()
    }
}

T.Test("Controller: switchers obtain facade render state when highlighted", Controller_SwitcherRenderContext)
Controller_SwitcherRenderContext() {
    local highlight, options, savedGui, savedRegistry, savedTheme, seen, switcher
    savedTheme := Legend.Theme, savedGui := Legend.Gui, savedRegistry := Legend.Registry
    options := {Scope: "monitor"}, seen := []
    Legend.Registry := LegendRegistry()
    try {
        switcher := Legend.WindowSwitcher("^!+F9", options)
        switcher.Peek := {Show: (self, candidate, outline := "", below := -1) => seen.Push({Outline: outline, Below: below})}
        highlight := switcher.Picker.OnHighlight
        Legend.Theme := Map("outline", "456DEF"), Legend.Gui := {Hwnd: 0xABCD}
        highlight({Data: {Hwnd: 0xCAFE}})
        T.Eq(seen[1].Outline, "456DEF")
        T.Eq(seen[1].Below, 0xABCD)
        Legend.Theme := "", Legend.Gui := ""
        highlight({Data: {Hwnd: 0xCAFE}})
        T.Eq(seen[2].Outline, "89B4FA", "facade fallback before an overlay exists")
        T.Eq(seen[2].Below, 0)
        T.True(!options.HasOwnProp("RenderContext"), "facade does not modify caller options")
        T.Eq(switcher.Picker.StartScope, "this monitor", "caller options survive context wiring")
    } finally
        Legend.Theme := savedTheme, Legend.Gui := savedGui, Legend.Registry := savedRegistry
}

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

T.Test("Legend: Render builds once per layout key", Legend_Render)
Legend_Render() {
    builds := 0
    make := () => (builds += 1, Legend_RenderWindow())
    savedGui := Legend.Gui, savedKey := Legend.DrawnLayout
    Legend.Gui := ""
    try {
        Legend.Render("test|a", make, 0)
        Legend.Render("test|a", make, 0)
        T.Eq(builds, 1, "same key: moved in place")
        Legend.Render("test|b", make, 0)
        T.Eq(builds, 2, "new key: rebuilt")
        Legend.Gui.Destroy(), Legend.Gui := ""
        Legend.Render("test|b", make, 0)
        T.Eq(builds, 3, "no window: rebuilt even with the same key")
    } finally {
        if Legend.Gui
            Legend.Gui.Destroy()
        Legend.Gui := savedGui, Legend.DrawnLayout := savedKey
    }
}

Legend_RenderWindow() {
    g := Gui("-Caption +ToolWindow +E0x08000000")
    g.Selection := LegendSelection(g, "45475A")
    return g
}

T.Test("Legend: pinned and flat pages leave Ctrl and menu keys to the app", Legend_KeyConditions)
Legend_KeyConditions() {
    savedVisible := Legend.Visible, savedNav := Legend.Nav
    try {
        nav := Navigator_New()
        nav.Open([])   ; the index: a menu
        Legend.Nav := nav
        Legend.Visible := false
        T.True(!Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "hidden")
        Legend.Visible := true
        T.True(Legend.CtrlKeysActive() && Legend.MenuKeysActive(), "menu")
        nav.Press("Pin")
        T.True(!Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "pinned menu")
        nav.Press("Pin")
        nav.Press("z")   ; Zen fits one screen: a flat page
        T.True(Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "flat page")
        nav.Press("Pin")
        T.True(!Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "pinned flat page")
    } finally
        Legend.Visible := savedVisible, Legend.Nav := savedNav
}
