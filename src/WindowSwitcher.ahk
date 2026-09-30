#Requires AutoHotkey v2.0

; A picker over switchable windows: scopes all / desktop / monitor, the active window
; first, icons, and the highlighted window peeked forward and outlined.
class LegendWindowSwitcher {
    static ScopeLabels := Map("all", "all windows", "desktop", "this desktop", "monitor", "this monitor")

    __New(hotkey, options := "") {
        opt := (name, fallback) => IsObject(options) && options.HasOwnProp(name) ? options.%name% : fallback
        this.Include := opt("Include", ""), this.ActivateFn := opt("Activate", ""), this.DetailFn := opt("Detail", "")
        this.Icons := Map()     ; icons Legend extracted and must destroy
        this.Peek := LegendPeek()
        labels := []
        for name in opt("Scopes", ["all", "desktop", "monitor"])
            labels.Push(LegendWindowSwitcher.LabelOf(name))
        this.Picker := LegendPicker(hotkey, "Windows", label => this.Source(label), {
            OnPick: item => this.Pick(item),
            OnHighlight: item => this.Peek.Show(item.Data),
            OnCancel: () => this.Cancel(),
            Start: opt("Start", 2), Scopes: labels, Scope: LegendWindowSwitcher.LabelOf(opt("Scope", "all")),
            Density: opt("Density", ""), Match: opt("Match", ""), Reference: opt("Reference", true),
            EmptyText: "No windows"})
    }

    static LabelOf(scope) {
        if !this.ScopeLabels.Has(scope)
            throw ValueError("window switcher scope must be all, desktop or monitor; got '" scope "'", -3)
        return this.ScopeLabels[scope]
    }

    static ScopeOf(label) {
        for scope, text in this.ScopeLabels
            if text = label
                return scope
        return "all"
    }

    Source(label) {
        this.FreeIcons()
        scope := LegendWindowSwitcher.ScopeOf(label)
        active := WinExist("A")
        windows := LegendWindows.List({Include: this.Include})
        activeMonitor := 0
        for win in windows
            if win.Hwnd = active
                activeMonitor := win.Monitor
        if !activeMonitor && active
            activeMonitor := LegendWindows.InPhysicalPixels(() => LegendWindows.MonitorAt(LegendWindows.Monitors(),
                LegendWindows.Bounds(active).X, LegendWindows.Bounds(active).Y))
        items := []
        for win in windows {
            if scope != "all" && !win.OnCurrentDesktop
                continue
            if scope = "monitor" && win.Monitor != activeMonitor
                continue
            item := {Text: win.Title, Detail: this.DetailOf(win), Icon: this.IconOf(win.Hwnd), Data: win}
            if win.Hwnd = active
                items.InsertAt(1, item)
            else
                items.Push(item)
        }
        return items
    }

    DetailOf(win) {
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
        static WM_GETICON := 0x7F, SMTO_ABORTIFHUNG := 0x2
        for iconType in [2, 0, 1] {   ; ICON_SMALL2, ICON_SMALL, ICON_BIG
            icon := 0
            if DllCall("SendMessageTimeoutW", "Ptr", hwnd, "UInt", WM_GETICON, "Ptr", iconType, "Ptr", 0,
                    "UInt", SMTO_ABORTIFHUNG, "UInt", 50, "Ptr*", &icon) && icon
                return icon
        }
        for classIndex in [-34, -14] {   ; GCLP_HICONSM, GCLP_HICON
            if icon := DllCall("GetClassLongPtrW", "Ptr", hwnd, "Int", classIndex, "Ptr")
                return icon
        }
        try {
            icon := LoadPicture(WinGetProcessPath(hwnd), "Icon1 w32 h32", &imageType)
            if icon && imageType = 1 {
                this.Icons[hwnd] := icon
                return icon
            }
        }
        return 0
    }

    FreeIcons() {
        for , icon in this.Icons
            DllCall("DestroyIcon", "Ptr", icon)
        this.Icons := Map()
    }

    Pick(item) {
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
}

; Shows the highlighted window: raised without activation and outlined. Clear(true)
; puts it back behind the window that was above it.
class LegendPeek {
    __New() {
        this.Raised := 0, this.Above := 0, this.Outline := ""
    }

    Show(win) {
        static GW_HWNDPREV := 3, GWL_EXSTYLE := -20, WS_EX_TOPMOST := 0x8
        static SWP_QUIET := 0x13   ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE
        this.Clear(true)
        if !IsObject(win) || win.Minimized || win.Cloaked || !DllCall("IsWindow", "Ptr", win.Hwnd)
            return
        ; the nearest non-topmost window above it: restoring behind a topmost window
        ; would make it topmost
        above := win.Hwnd
        loop {
            above := DllCall("GetWindow", "Ptr", above, "UInt", GW_HWNDPREV, "Ptr")
            if !above || !(DllCall("GetWindowLongPtrW", "Ptr", above, "Int", GWL_EXSTYLE, "Ptr") & WS_EX_TOPMOST)
                break
        }
        this.Raised := win.Hwnd, this.Above := above
        DllCall("SetWindowPos", "Ptr", win.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_QUIET)
        color := IsObject(Legend.Theme) ? Legend.Theme["outline"] : "89B4FA"
        this.Outline := LegendWindows.InPhysicalPixels(() => LegendPeek.Frame(LegendWindows.Bounds(win.Hwnd), color))
    }

    Clear(restore := true) {
        static SWP_QUIET := 0x13
        if this.Outline
            this.Outline.Destroy(), this.Outline := ""
        if restore && this.Raised && this.Above && DllCall("IsWindow", "Ptr", this.Raised)
            DllCall("SetWindowPos", "Ptr", this.Raised, "Ptr", this.Above, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_QUIET)
        this.Raised := 0, this.Above := 0
    }

    ; A click-through, always-on-top frame `thickness` px outside bounds.
    static Frame(bounds, color, thickness := 4) {
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
        return frame
    }
}
