#Requires AutoHotkey v2.0

; Uses the Legend facade and real (off-screen, non-activating) windows.

T.Test("Sessions: a picker replaces and closes a chord", Sessions_PickerReplacesChord)
Sessions_PickerReplacesChord() {
    local chord, old, picker
    T.True(Legend.HasOwnProp("Session"), "one active Session exists")
    chord := LegendChord("^!+F9", "Session chord", [Legend.Run("a", "A", Noop)])
    picker := LegendPicker("^!+F8", "Session picker", (*) => [{Text: "one"}], {OnPick: Noop})
    try {
        Legend.OpenChord(chord)
        old := Legend.Session
        Legend.OpenPicker(picker)
        T.Eq(Type(Legend.Session), "LegendPickerSession")
        T.True(old.Closed)
        T.Eq(old.Renderer.Gui, "")
        T.Eq(old.Renderer.Measurer, "")
        T.Eq(old.Hook, "")
        T.Eq(old.Timers.Count, 0)
    } finally
        Legend.Close()
}

T.Test("Sessions: reference replaces picker before it opens", Sessions_ReferenceReplacesPicker)
Sessions_ReferenceReplacesPicker() {
    local cancelled, old, options, picker
    T.True(Legend.HasOwnProp("Session"), "one active Session exists")
    cancelled := 0, options := Legend.Options
    Legend.Options := Legend.DefaultOptions.Clone(), Legend.Options.LetterFile := ""
    picker := LegendPicker("^!+F8", "Session picker", (*) => [{Text: "one"}],
        {OnPick: Noop, OnCancel: () => cancelled += 1})
    try {
        Legend.OpenPicker(picker)
        old := Legend.Session
        Legend.Open()
        T.Eq(Type(Legend.Session), "LegendReferenceSession")
        T.True(old.Closed)
        T.Eq(old.Renderer.Gui, "")
        T.Eq(old.Hook, "")
        Legend.RunDeferred()
        T.Eq(cancelled, 1)
    } finally {
        Legend.Close()
        Legend.Options := options
    }
}

T.Test("Sessions: closing twice releases owned resources once", Sessions_IdempotentClose)
Sessions_IdempotentClose() {
    local calls, hook, picker, session
    T.True(Legend.HasOwnProp("Session"), "one active Session exists")
    calls := [], picker := LegendPicker("^!+F8", "Close twice", (*) => [{Text: "one"}], {OnPick: Noop})
    Legend.OpenPicker(picker)
    session := Legend.Session, hook := session.Hook
    ; Wrap the real OS resources to detect duplicate teardown, while still freeing them.
    session.Hook := {Stop: (self) => (calls.Push("hook"), hook.Stop())}
    session.Renderer := Sessions_TrackedRenderer(session.Renderer, calls)
    try {
        session.Close()
        session.Close()
        T.Eq(Legend.Session, "")
        T.Eq(calls.Length, 2)
        T.Eq(calls[1], "hook")
        T.Eq(calls[2], "renderer")
        T.True(!hook.InProgress)
    } finally
        Legend.Close()
}

Sessions_TrackedRenderer(renderer, calls) => {Close: (self) => (calls.Push("renderer"), renderer.Close())}

T.Test("Sessions: stale chord callbacks cannot act on a replacement", Sessions_StaleChord)
Sessions_StaleChord() {
    local chord, old, picker, replacement, runs, showTimer
    T.True(Legend.HasOwnProp("Session"), "one active Session exists")
    runs := 0, chord := LegendChord("^!+F9", "Stale chord", [Legend.Run("a", "A", () => runs += 1)])
    picker := LegendPicker("^!+F8", "Replacement", (*) => [{Text: "one"}], {OnPick: Noop})
    try {
        Legend.OpenChord(chord)
        old := Legend.Session, showTimer := old.Timers["Show"]
        Legend.OpenPicker(picker)
        replacement := Legend.Session
        showTimer()
        old.Key(LegendKeyName.FromText("a"), "a")
        old.CheckFocus()
        old.Close()
        T.True(Legend.Session == replacement)
        T.Eq(runs, 0)
        T.True(IsObject(replacement.Renderer.Gui))
    } finally
        Legend.Close()
}

T.Test("Sessions: stale picker callbacks cannot drain replacement keys", Sessions_StalePicker)
Sessions_StalePicker() {
    local old, picker, replacement
    T.True(Legend.HasOwnProp("Session"), "one active Session exists")
    picker := LegendPicker("^!+F8", "Stale picker", (*) => [{Text: "one"}, {Text: "two"}], {OnPick: Noop})
    try {
        Legend.OpenPicker(picker)
        old := Legend.Session
        Legend.Close()
        Legend.OpenPicker(picker)
        replacement := Legend.Session
        old.Key(LegendKeyName.FromText("j"))
        old.DrainKeys()
        old.CheckFocus()
        old.Close()
        T.True(Legend.Session == replacement)
        T.Eq(picker.Cursor, 1)
    } finally
        Legend.Close()
}

T.Test("Sessions: opening failure clears and closes the partial session", Sessions_OpenFailure)
Sessions_OpenFailure() {
    local closed, opened, partial
    closed := 0, opened := 0
    partial := {Open: (self) => Sessions_FailOpen(), Close: (self) => closed += 1}
    T.Throws(() => Legend.ReplaceSession(() => partial))
    T.Eq(closed, 1, "failed session was closed")
    T.Eq(Legend.Session, "")
}

Sessions_FailOpen() {
    throw Error("intentional open failure")
}

T.Test("Sessions: reference navigation and repeated close release resources", Sessions_ReferenceLifecycle)
Sessions_ReferenceLifecycle() {
    local options, session, watcher
    options := Legend.Options
    Legend.Options := Legend.DefaultOptions.Clone(), Legend.Options.LetterFile := ""
    try {
        Legend.Open()
        session := Legend.Session, watcher := session.Watcher
        T.True(Legend.ReferenceActive())
        T.True(IsObject(session.Renderer.Gui))
        Legend.Handle("Pin")
        T.True(session.Nav.Pinned)
        Legend.Handle("Close")
        session.Close()
        T.Eq(Legend.Session, "")
        T.Eq(session.Renderer.Gui, "")
        T.Eq(session.Renderer.Measurer, "")
        T.Eq(session.FocusTimer, "")
        T.Eq(session.ComboTimer, "")
        T.True(!watcher.InProgress)
    } finally {
        Legend.Close()
        Legend.Options := options
    }
}

T.Test("Controller: reference warning hover shows and closes its tooltip", () => Controller_WarningHover(() => Legend.Open()))
T.Test("Controller: chord warning hover shows and closes its tooltip", () => Controller_WarningHover(
    () => Legend.OpenChord(LegendChord("^!+F9", "Hover", [Legend.Run("a", "A", Noop)]))))
Controller_WarningHover(open) {
    local badge, options, registry, replacement, session, tooltipWindow
    options := Legend.Options, registry := Legend.Registry
    Legend.Options := Legend.DefaultOptions.Clone(), Legend.Options.LetterFile := ""
    Legend.Options.ChordOverlay := "always"
    Legend.Registry := LegendRegistry()
    Legend.Registry.Warnings.Push("warning hover regression")
    tooltipWindow := "ahk_class tooltips_class32 ahk_pid " DllCall("GetCurrentProcessId", "UInt")
    try {
        open()
        session := Legend.Session
        T.True(session.Renderer.Gui.HasOwnProp("WarningBadge"), "warning badge rendered")
        badge := session.Renderer.Gui.WarningBadge.Hwnd
        Legend.OnMouseMove(badge)
        T.True(session.TipShown, "active session owns the warning tooltip")
        T.True(WinExist(tooltipWindow), "warning tooltip is visible")
        Legend.OnMouseMove(session.Renderer.Gui.Hwnd)
        T.True(!session.TipShown && !WinExist(tooltipWindow), "leaving the badge dismisses the tooltip")
        Legend.OnMouseMove(badge)
        Legend.Open()
        replacement := Legend.Session
        T.True(session.Closed && !session.TipShown)
        T.True(!WinExist(tooltipWindow), "replacement dismisses the old warning tooltip")
        Legend.OnMouseMove(replacement.Renderer.Gui.WarningBadge.Hwnd)
        session.OnMouseMove(0)
        session.OnMouseMove(badge)
        session.Close()
        T.True(Legend.Session == replacement && replacement.TipShown)
        T.True(WinExist(tooltipWindow), "stale hover/close cannot dismiss the replacement's tooltip")
        Legend.OnMouseMove(0)
        T.True(!replacement.TipShown && !WinExist(tooltipWindow))
    } finally {
        Legend.Close()
        ToolTip()
        Legend.Options := options, Legend.Registry := registry
    }
}

T.Test("Sessions: replacement closes before constructing the next session", Sessions_FactoryOrder)
Sessions_FactoryOrder() {
    local order, old, replacement
    order := []
    old := {Open: (self) => "", Close: (self, cancelled := true) => (order.Push("close"), Legend.DetachSession(self))}
    replacement := {Open: (self) => order.Push("open"), Close: (self, cancelled := true) => Legend.DetachSession(self)}
    Legend.ReplaceSession(() => old)
    try {
        Legend.ReplaceSession(() => (order.Push("construct"), replacement))
        T.Eq(order.Length, 3)
        T.Eq(order[1], "close")
        T.Eq(order[2], "construct")
        T.Eq(order[3], "open")
    } finally
        Legend.Close()
}

T.Test("Sessions: construction failure leaves the previous session closed", Sessions_FactoryFailure)
Sessions_FactoryFailure() {
    local options, old
    options := Legend.Options
    Legend.Options := Legend.DefaultOptions.Clone(), Legend.Options.LetterFile := ""
    try {
        Legend.Open()
        old := Legend.Session
        T.Throws(() => Legend.ReplaceSession(() => Sessions_FailOpen()))
        T.Eq(Legend.Session, "")
        T.True(old.Closed)
        T.Eq(old.Renderer.Gui, "")
    } finally {
        Legend.Close()
        Legend.Options := options
    }
}

T.Test("Sessions: stale reference callbacks leave a replacement open", Sessions_StaleReference)
Sessions_StaleReference() {
    local old, options, picker, replacement, combo, watcher
    options := Legend.Options
    Legend.Options := Legend.DefaultOptions.Clone(), Legend.Options.LetterFile := ""
    picker := LegendPicker("^!+F8", "Replacement", (*) => [{Text: "one"}], {OnPick: Noop})
    try {
        Legend.Open()
        old := Legend.Session, combo := old.ComboTimer, watcher := old.Watcher
        Legend.Handle("Pin")
        T.True(old.Nav.Pinned)
        Legend.OpenPicker(picker)
        replacement := Legend.Session
        combo()
        old.Handle("Close")
        old.OnKeyDown(0x41)
        old.OnKeyUp(0x41)
        old.CheckFocus()
        old.Close()
        T.True(Legend.Session == replacement)
        T.True(!watcher.InProgress)
        T.Eq(old.Nav, "")
        T.Eq(old.Renderer.Measurer, "")
    } finally {
        Legend.Close()
        Legend.Options := options
    }
}

T.Test("Sessions: unmatched chord notification closes with its session", Sessions_ChordNotification)
Sessions_ChordNotification() {
    local chord, dismiss, hook, old, picker, replacement
    chord := LegendChord("^!+F9", "Miss", [Legend.Run("a", "A", Noop)])
    picker := LegendPicker("^!+F8", "Replacement", (*) => [{Text: "one"}], {OnPick: Noop})
    try {
        Legend.OpenChord(chord)
        old := Legend.Session, hook := old.Hook
        old.Key(LegendKeyName.FromText("z"), "z")
        T.True(!old.Capturing && old.TipShown)
        T.True(Legend.Session == old, "notification remains session-owned")
        T.True(!hook.InProgress)
        T.Eq(old.Renderer.Gui, "")
        T.Eq(old.Renderer.Measurer, "")
        dismiss := old.Timers["Dismiss"]
        Legend.OnMouseMove(0)
        T.True(old.TipShown, "mouse movement preserves the unmatched-key notification")
        Legend.OpenPicker(picker)
        replacement := Legend.Session
        T.True(old.Closed && !old.TipShown)
        T.Eq(old.Timers.Count, 0)
        dismiss()
        T.True(Legend.Session == replacement)
        old.Close()
    } finally
        Legend.Close()
}

T.Test("Sessions: picker source failure releases capture without cancellation", Sessions_PickerSourceFailure)
Sessions_PickerSourceFailure() {
    local cancelled, partial, picker
    cancelled := 0, partial := ""
    picker := LegendPicker("^!+F8", "Failure", (*) => (partial := Legend.Session, Sessions_FailOpen()),
        {OnPick: Noop, OnCancel: () => cancelled += 1})
    T.Throws(() => Legend.OpenPicker(picker))
    Legend.RunDeferred()
    T.Eq(cancelled, 0)
    T.Eq(Legend.Session, "")
    T.True(partial.Closed)
    T.Eq(partial.Hook, "")
    T.Eq(partial.FocusTimer, "")
    T.Eq(partial.Renderer.Gui, "")
}

T.Test("Sessions: picker callbacks run after teardown outside Critical", Sessions_DeferredPick)
Sessions_DeferredPick() {
    local picker, seen, session, was
    seen := [], was := A_IsCritical
    picker := LegendPicker("^!+F8", "Deferred", (*) => [{Text: "one"}],
        {OnPick: item => seen.Push({Text: item.Text, Session: Legend.Session, Critical: A_IsCritical})})
    try {
        Critical(37)
        Legend.OpenPicker(picker)
        session := Legend.Session
        session.Key(LegendKeyName.FromText("Enter"))
        T.Eq(seen.Length, 0, "callback is deferred")
        T.True(session.Closed)
        T.Eq(session.Renderer.Gui, "")
        T.Eq(A_IsCritical, 37, "caller critical state restored")
        Legend.RunDeferred()
        T.Eq(seen.Length, 1)
        T.Eq(seen[1].Text, "one")
        T.Eq(seen[1].Session, "")
        T.Eq(seen[1].Critical, 0)
        T.Eq(A_IsCritical, 37)
        Legend.RunDeferred()
        T.Eq(seen.Length, 1, "callback runs once")
    } finally {
        Legend.Close(false)
        Critical(was ? was : "Off")
    }
}

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
    local overlay, peek, savedSession, target
    static GW_HWNDNEXT := 2
    overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    target := Gui("-Caption +ToolWindow +E0x08000000")
    peek := LegendPeek()
    savedSession := Legend.Session
    try {
        overlay.Show("NA x-3000 y-3000 w50 h50")
        target.Show("NA x-2900 y-2900 w40 h40")
        Legend.Session := {Renderer: {Theme: Map(), Gui: {}}}   ; no outline key or HWND to read
        peek.Show({Hwnd: target.Hwnd, Minimized: false, Cloaked: false}, "123ABC", overlay.Hwnd)
        T.Eq(peek.Outline.BackColor, "123ABC")
        T.Eq(DllCall("GetWindow", "Ptr", overlay.Hwnd, "UInt", GW_HWNDNEXT, "Ptr"), peek.Outline.Hwnd)
        T.Eq(peek.Raised, target.Hwnd)
        peek.Clear(true)
        T.Eq(peek.Raised, 0)
        T.Eq(peek.Outline, "")
    } finally {
        peek.Clear(false)
        Legend.Session := savedSession
        target.Destroy(), overlay.Destroy()
    }
}

T.Test("Controller: switchers obtain facade render state when highlighted", Controller_SwitcherRenderContext)
Controller_SwitcherRenderContext() {
    local highlight, options, savedRegistry, savedSession, seen, switcher
    savedSession := Legend.Session, savedRegistry := Legend.Registry
    options := {Scope: "monitor"}, seen := []
    Legend.Registry := LegendRegistry()
    try {
        switcher := Legend.WindowSwitcher("^!+F9", options)
        switcher.Peek := {Show: (self, candidate, outline := "", below := -1) => seen.Push({Outline: outline, Below: below})}
        highlight := switcher.Picker.OnHighlight
        Legend.Session := {Renderer: {Theme: Map("outline", "456DEF"), Gui: {Hwnd: 0xABCD}}}
        highlight({Data: {Hwnd: 0xCAFE}})
        T.Eq(seen[1].Outline, "456DEF")
        T.Eq(seen[1].Below, 0xABCD)
        Legend.Session := ""
        highlight({Data: {Hwnd: 0xCAFE}})
        T.Eq(seen[2].Outline, "89B4FA", "facade fallback before an overlay exists")
        T.Eq(seen[2].Below, 0)
        T.True(!options.HasOwnProp("RenderContext"), "facade does not modify caller options")
        T.Eq(switcher.Picker.StartScope, "this monitor", "caller options survive context wiring")
    } finally
        Legend.Session := savedSession, Legend.Registry := savedRegistry
}

T.Test("Controller: keys that arrive while the source runs are applied after open", Controller_EarlyKeys)
Controller_EarlyKeys() {
    local items, source, picker
    items := [{Text: "one"}, {Text: "two"}, {Text: "three"}]
    source := (*) => (Legend.Session.OnKeyDown(0x4A, 0x24), items)   ; j pressed while loading
    picker := LegendPicker("^!+F9", "Early", source, {OnPick: Noop})
    Legend.OpenPicker(picker)
    try
        T.Eq(picker.Cursor, 2, "the j typed during the source moved the cursor")
    finally
        Legend.Close(false)
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
    local picker
    picker := LegendPicker("^!+F9", "Legend line", (*) => [{Text: "a"}], {OnPick: Noop})
    Legend.OpenPicker(picker)
    try {
        Legend.Session.Renderer.BaseTheme["keyStyle"] := "symbols"   ; reloaded on the next open
        T.Eq(Legend.Session.PickerTheme()["legend"], "off")
    } finally
        Legend.Close(false)
}

T.Test("Controller: OnHighlight gets an empty item when a filter leaves nothing selected", Controller_HighlightNothing)
Controller_HighlightNothing() {
    local keyText, picker, seen
    seen := []
    picker := LegendPicker("^!+F9", "Highlight", (*) => [{Text: "one"}, {Text: "two"}],
        {OnPick: Noop, OnHighlight: item => seen.Push(IsObject(item) ? item.Text : "(none)")})
    Legend.OpenPicker(picker)
    try {
        for keyText in ["/", "z", "z"]
            Legend.Session.Key(LegendKeyName.FromText(keyText))
        T.Eq(seen.Length, 2, "one call at open, one when the list emptied")
        T.Eq(seen[2], "(none)")
        Legend.Session.Key(LegendKeyName.FromText("Esc"))
        T.Eq(seen[3], "one", "a selection again after Esc")
    } finally
        Legend.Close(false)
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
    local first, order, second
    order := []
    first := LegendPicker("^!+F9", "First", (*) => [{Text: "a"}], {OnPick: Noop, OnCancel: () => order.Push("cancel")})
    second := LegendPicker("^!+F8", "Second", (*) => (order.Push("load"), [{Text: "b"}]), {OnPick: Noop})
    Legend.OpenPicker(first)
    Legend.Close(true)
    Legend.OpenPicker(second)   ; before the cancel's timer has had a chance to run
    try {
        Sleep(50)
        T.Eq(order.Length, 2)
        T.Eq(order[1], "cancel")
        T.Eq(order[2], "load")
    } finally
        Legend.Close(false)
}

T.Test("Controller: pickerWidthPercent caps a picker with very long rows", Controller_PickerWidth)
Controller_PickerWidth() {
    local area, long, overlayW, picker
    T.Eq(LegendTheme.Read("")["pickerWidthPercent"], 60)
    long := ""
    loop 60
        long .= "a very long window title "
    picker := LegendPicker("^!+F9", "Wide", (*) => [{Text: long, Detail: "app"}], {OnPick: Noop})
    Legend.OpenPicker(picker)
    try {
        WinGetPos(, , &overlayW, , Legend.Session.Renderer.Gui)
        area := LegendOverlay.WorkArea()
        T.True(overlayW <= (area.Right - area.Left) * 60 // 100, "overlay " overlayW " wider than 60%")
    } finally
        Legend.Close(false)
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
    local builds, make, renderer
    builds := 0
    make := () => (builds += 1, Legend_RenderWindow())
    renderer := LegendSessionRenderer()
    try {
        renderer.Render("test|a", make, 0)
        renderer.Render("test|a", make, 0)
        T.Eq(builds, 1, "same key: moved in place")
        renderer.Render("test|b", make, 0)
        T.Eq(builds, 2, "new key: rebuilt")
        renderer.Gui.Destroy(), renderer.Gui := ""
        renderer.Render("test|b", make, 0)
        T.Eq(builds, 3, "no window: rebuilt even with the same key")
    } finally
        renderer.Close()
}

Legend_RenderWindow() {
    local g
    g := Gui("-Caption +ToolWindow +E0x08000000")
    g.Selection := LegendSelection(g, "45475A")
    return g
}

T.Test("Legend: pinned and flat pages leave Ctrl and menu keys to the app", Legend_KeyConditions)
Legend_KeyConditions() {
    local nav, savedSession, session
    savedSession := Legend.Session
    session := LegendReferenceSession(LegendSessionRenderer())
    try {
        nav := Navigator_New()
        nav.Open([])   ; the index: a menu
        Legend.Session := session, session.Nav := nav
        T.True(!Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "hidden")
        session.Ready := true
        T.True(Legend.CtrlKeysActive() && Legend.MenuKeysActive(), "menu")
        nav.Press("Pin")
        T.True(!Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "pinned menu")
        nav.Press("Pin")
        nav.Press("z")   ; Zen fits one screen: a flat page
        T.True(Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "flat page")
        nav.Press("Pin")
        T.True(!Legend.CtrlKeysActive() && !Legend.MenuKeysActive(), "pinned flat page")
    } finally {
        session.Close()
        Legend.Session := savedSession
    }
}
