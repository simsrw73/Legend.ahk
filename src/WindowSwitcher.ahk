#Requires AutoHotkey v2.0

; A picker over switchable windows: scopes all / desktop / monitor, the active window
; first, icons, and the highlighted window peeked forward and outlined.
class LegendWindowSwitcher {
    static ScopeLabels := Map("all", "all windows", "desktop", "this desktop", "monitor", "this monitor")

    __New(hotkey, options := "") {
        local labels, name, opt
        opt := (name, fallback) => IsObject(options) && options.HasOwnProp(name) ? options.%name% : fallback
        this.Include := opt("Include", ""), this.ActivateFn := opt("Activate", ""), this.DetailFn := opt("Detail", "")
        this.RenderContext := opt("RenderContext", () => {Outline: "89B4FA", Below: 0})
        this.Icons := Map()     ; icons Legend extracted and must destroy
        this.Peek := LegendPeek()
        labels := []
        for name in opt("Scopes", ["all", "desktop", "monitor"])
            labels.Push(LegendWindowSwitcher.LabelOf(name))
        this.StartOption := opt("Start", 2)
        this.Picker := LegendPicker(hotkey, "Windows", label => this.Source(label), {
            OnPick: item => this.Pick(item),
            OnHighlight: item => this.Highlight(item),
            OnCancel: () => this.Cancel(),
            Start: this.StartOption, Scopes: labels, Scope: LegendWindowSwitcher.LabelOf(opt("Scope", "all")),
            Density: opt("Density", ""), Match: opt("Match", ""), Reference: opt("Reference", true),
            EmptyText: "No windows"})
    }

    static LabelOf(scope) {
        if !this.ScopeLabels.Has(scope)
            throw ValueError("window switcher scope must be all, desktop or monitor; got '" scope "'", -3)
        return this.ScopeLabels[scope]
    }

    ; The row to preselect: Start counts the active window as row 1, so when it isn't
    ; listed (the desktop, a tool window) the most recent window is one row earlier.
    static StartFor(start, activeListed) => activeListed ? start : Max(1, start - 1)

    static ScopeOf(label) {
        local scope, text
        for scope, text in this.ScopeLabels
            if text = label
                return scope
        return "all"
    }

    Source(label) {
        local activeHwnd, activeListed, activeMonitor, item, items, scope, window, windows
        this.FreeIcons()
        try {
            scope := LegendWindowSwitcher.ScopeOf(label)
            activeHwnd := WinExist("A")
            windows := LegendWindows.List({Include: this.Include})
            activeMonitor := 0
            for window in windows
                if window.Hwnd = activeHwnd
                    activeMonitor := window.Monitor
            if !activeMonitor && activeHwnd
                activeMonitor := LegendWindows.InPhysicalPixels(() => LegendWindows.MonitorAt(LegendWindows.Monitors(),
                    LegendWindows.Bounds(activeHwnd).X, LegendWindows.Bounds(activeHwnd).Y))
            items := [], activeListed := false
            for window in windows {
                if scope != "all" && !window.OnCurrentDesktop
                    continue
                if scope = "monitor" && window.Monitor != activeMonitor
                    continue
                item := {Text: window.Title, Detail: this.DetailOf(window), Icon: this.IconOf(window.Hwnd), Data: window}
                if window.Hwnd = activeHwnd
                    items.InsertAt(1, item), activeListed := true
                else
                    items.Push(item)
            }
            this.Picker.Start := LegendWindowSwitcher.StartFor(this.StartOption, activeListed)
            return items
        } catch {
            this.FreeIcons()
            throw
        }
    }

    DetailOf(win) {
        local detail, detailFn
        detail := win.App
        if IsObject(this.DetailFn) {
            detailFn := this.DetailFn
            detail := detailFn(win)
        }
        if win.Minimized
            detail .= " (minimized)"
        if !win.OnCurrentDesktop
            detail .= " · " LegendDesktops.Label(win.DesktopId)
        return detail
    }

    ; The window's own icon, its class icon, or the first icon of its exe (owned).
    IconOf(hwnd) {
        local classIndex, icon, iconType, imageType
        static WM_GETICON := 0x7F, SMTO_ABORTIFHUNG := 0x2
        static ICON_SMALL2 := 2, ICON_SMALL := 0, ICON_BIG := 1
        static GCLP_HICONSM := -34, GCLP_HICON := -14
        static IMAGE_ICON := 1, ICON_QUERY_TIMEOUT_MS := 50
        for iconType in [ICON_SMALL2, ICON_SMALL, ICON_BIG] {
            icon := 0
            if DllCall("SendMessageTimeoutW", "Ptr", hwnd, "UInt", WM_GETICON, "Ptr", iconType, "Ptr", 0,
                    "UInt", SMTO_ABORTIFHUNG, "UInt", ICON_QUERY_TIMEOUT_MS, "Ptr*", &icon) && icon
                return icon
        }
        for classIndex in [GCLP_HICONSM, GCLP_HICON] {
            if icon := DllCall("GetClassLongPtrW", "Ptr", hwnd, "Int", classIndex, "Ptr")
                return icon
        }
        try {
            icon := LoadPicture(WinGetProcessPath(hwnd), "Icon1 w32 h32", &imageType)
            if icon && imageType = IMAGE_ICON {
                this.Icons[hwnd] := icon
                return icon
            }
        }
        return 0
    }

    FreeIcons() {
        local icon
        for , icon in this.Icons
            DllCall("DestroyIcon", "Ptr", icon)
        this.Icons := Map()
    }

    Pick(item) {
        local activate, win
        this.Peek.Clear(false)
        this.FreeIcons()
        win := item.Data
        if !DllCall("IsWindow", "Ptr", win.Hwnd) {
            ToolTip("Window closed")
            SetTimer(() => ToolTip(), -1000)
            return
        }
        if IsObject(this.ActivateFn) {
            activate := this.ActivateFn
            return activate(win.Hwnd)
        }
        LegendWindows.Activate(win.Hwnd)
    }

    Cancel() {
        this.Peek.Clear(true)
        this.FreeIcons()
    }

    Highlight(item) {
        local context, renderContext
        if !IsObject(item)
            return this.Peek.Clear(true)
        renderContext := this.RenderContext
        context := renderContext()
        this.Peek.Show(item.Data, context.Outline, context.Below)
    }
}

; Shows the highlighted window: raised without activation and outlined. Clear(true)
; puts it back behind the window that was above it.
class LegendPeek {
    __New() {
        this.Raised := 0, this.Above := 0, this.Outline := ""
    }

    Show(win, outline, below) {
        local above
        static GW_HWNDPREV := 3
        static SWP_QUIET := 0x13   ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE
        this.Clear(true)
        if !IsObject(win) || win.Minimized || win.Cloaked || !DllCall("IsWindow", "Ptr", win.Hwnd)
            return
        ; the nearest visible, non-topmost window above it: restoring behind a topmost
        ; window would make it topmost, and an invisible one may be gone by then
        above := win.Hwnd
        loop {
            above := DllCall("GetWindow", "Ptr", above, "UInt", GW_HWNDPREV, "Ptr")
            if !above || LegendPeek.IsAnchor(above)
                break
        }
        this.Raised := win.Hwnd, this.Above := above
        DllCall("SetWindowPos", "Ptr", win.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_QUIET)
        this.Outline := LegendWindows.InPhysicalPixels(() => LegendPeek.Frame(LegendWindows.Bounds(win.Hwnd), outline, 4, below))
    }

    Clear(restore := true) {
        static SWP_QUIET := 0x13
        if this.Outline
            this.Outline.Destroy(), this.Outline := ""
        if LegendPeek.ShouldRestore(restore, this.Raised, this.Above, WinExist("A")) && DllCall("IsWindow", "Ptr", this.Raised)
            DllCall("SetWindowPos", "Ptr", this.Raised, "Ptr", this.Above, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_QUIET)
        this.Raised := 0, this.Above := 0
    }

    ; A window the peeked one can be put back behind.
    static IsAnchor(hwnd) {
        static GWL_EXSTYLE := -20, WS_EX_TOPMOST := 0x8
        return DllCall("IsWindowVisible", "Ptr", hwnd)
            && !(DllCall("GetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr") & WS_EX_TOPMOST)
    }

    ; Put the raised window back only when asked, when there is an anchor, and when the
    ; user hasn't activated it (clicking the peeked window keeps it in front).
    static ShouldRestore(restore, raised, above, active) => restore && raised && above && active != raised

    ; A click-through, always-on-top frame `thickness` px outside bounds, placed just
    ; below the window `below` when given (a new topmost window would cover it).
    static Frame(bounds, color, thickness := 4, below := 0) {
        local frame, frameH, frameW, inner, outer
        frame := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000020")   ; NOACTIVATE | TRANSPARENT
        frame.BackColor := color
        frameW := bounds.W + thickness * 2, frameH := bounds.H + thickness * 2
        outer := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", frameW, "Int", frameH, "Ptr")
        inner := DllCall("CreateRectRgn", "Int", thickness, "Int", thickness, "Int", frameW - thickness, "Int", frameH - thickness, "Ptr")
        DllCall("CombineRgn", "Ptr", outer, "Ptr", outer, "Ptr", inner, "Int", 4)   ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", inner)
        frame.Show("NA x" (bounds.X - thickness) " y" (bounds.Y - thickness) " w" frameW " h" frameH)
        DllCall("SetWindowRgn", "Ptr", frame.Hwnd, "Ptr", outer, "Int", true)   ; the window owns outer now
        WinSetTransparent(255, frame)   ; layered, so clicks pass through
        if below
            DllCall("SetWindowPos", "Ptr", frame.Hwnd, "Ptr", below, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x13)
        return frame
    }
}
