#Requires AutoHotkey v2.0

; Switchable top-level windows, front to back, in physical pixels.
class LegendWindows {
    static MinVisibleShare := 0.1
    static PullFromOtherDesktops := false   ; Task 0: true if WinActivate doesn't switch desktops
    static Shell := Map("Progman", 1, "WorkerW", 1, "Shell_TrayWnd", 1, "Shell_SecondaryTrayWnd", 1)

    ; Runs fn with the thread per-monitor DPI aware (v2): DWM bounds are always physical
    ; pixels, and MonitorGet agrees with them only in that mode.
    static InPhysicalPixels(fn) {
        local previous
        static PER_MONITOR_AWARE_V2 := -4
        previous := DllCall("SetThreadDpiAwarenessContext", "Ptr", PER_MONITOR_AWARE_V2, "Ptr")
        try return fn()
        finally DllCall("SetThreadDpiAwarenessContext", "Ptr", previous, "Ptr")
    }

    static List(options := "") => this.InPhysicalPixels(() => this.ListNow(options))

    ; Visible, titled, not tool windows, not the desktop or taskbar; cloaked windows only
    ; when they belong to a virtual desktop or Include lets them in. AutoHotkey reports
    ; cloaked windows as hidden, so hidden windows are searched and WS_VISIBLE checked.
    static ListNow(options) {
        local appName, bounds, cloaked, coverage, desktopId, desktops, exclude, hwnd, include, minimized, monitors, opt, result, title, visibleOnly, wasDetecting, withMinimized
        static WS_VISIBLE := 0x10000000, WS_EX_TOOLWINDOW := 0x80
        opt := (name, fallback) => IsObject(options) && options.HasOwnProp(name) ? options.%name% : fallback
        withMinimized := opt("Minimized", true), visibleOnly := opt("VisibleOnly", false)
        include := opt("Include", ""), exclude := opt("Exclude", 0)
        monitors := this.Monitors()
        coverage := visibleOnly ? LegendCoverage(monitors) : ""
        desktops := LegendDesktops()
        wasDetecting := DetectHiddenWindows(true)
        result := []
        try {
            for hwnd in WinGetList() {
                try {
                    if !(WinGetStyle(hwnd) & WS_VISIBLE) || (WinGetExStyle(hwnd) & WS_EX_TOOLWINDOW)
                        continue
                    title := WinGetTitle(hwnd)
                    if title = "" || this.Shell.Has(WinGetClass(hwnd))
                        continue
                    cloaked := this.IsCloaked(hwnd)
                    desktopId := desktops.DesktopOf(hwnd)
                    if cloaked && desktopId = "" && !(IsObject(include) && include(hwnd))
                        continue
                    minimized := WinGetMinMax(hwnd) = -1
                    if minimized && !withMinimized
                        continue
                    bounds := minimized ? this.NormalBounds(hwnd) : this.Bounds(hwnd)
                    if bounds.W <= 0 || bounds.H <= 0
                        continue
                    if coverage {
                        if cloaked || minimized
                            continue
                        if coverage.Add(bounds) < this.MinVisibleShare
                            continue
                    }
                    if hwnd = exclude
                        continue
                    appName := RegExReplace(WinGetProcessName(hwnd), "i)\.exe$")
                    result.Push({Hwnd: hwnd, Title: title, App: appName, X: bounds.X, Y: bounds.Y, W: bounds.W, H: bounds.H,
                        Monitor: this.MonitorAt(monitors, bounds.X, bounds.Y), Minimized: minimized, Cloaked: cloaked,
                        OnCurrentDesktop: desktops.OnCurrent(hwnd), DesktopId: desktopId})
                } catch TargetError   ; closed while we looked
                    continue
            }
        } finally
            DetectHiddenWindows(wasDetecting)
        return result
    }

    ; Visible bounds from DWM (WinGetPos includes invisible resize borders).
    static Bounds(hwnd) {
        local left, rect, top, winH, winW, winX, winY
        static DWMWA_EXTENDED_FRAME_BOUNDS := 9
        rect := Buffer(16, 0)
        if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rect, "UInt", 16) = 0 {
            left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
            return {X: left, Y: top, W: NumGet(rect, 8, "Int") - left, H: NumGet(rect, 12, "Int") - top}
        }
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
        return {X: winX, Y: winY, W: winW, H: winH}
    }

    ; Where a minimized window will be restored, in screen coordinates.
    ; WINDOWPLACEMENT.rcNormalPosition is in workspace coordinates.
    static NormalBounds(hwnd) {
        local bounds, left, monBottom, monLeft, monRight, monTop, placement, primaryIndex, top, workBottom, workLeft, workRight, workTop
        placement := Buffer(44, 0)
        NumPut("UInt", 44, placement)
        DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", placement)
        left := NumGet(placement, 28, "Int"), top := NumGet(placement, 32, "Int")
        bounds := {X: left, Y: top, W: NumGet(placement, 36, "Int") - left, H: NumGet(placement, 40, "Int") - top}
        primaryIndex := MonitorGetPrimary()
        MonitorGet(primaryIndex, &monLeft, &monTop, &monRight, &monBottom)
        MonitorGetWorkArea(primaryIndex, &workLeft, &workTop, &workRight, &workBottom)
        return this.WorkspaceToScreen(bounds, {Left: monLeft, Top: monTop, Right: monRight, Bottom: monBottom},
            {Left: workLeft, Top: workTop, Right: workRight, Bottom: workBottom})
    }

    ; Workspace coordinates are relative to the primary monitor's work area, so a
    ; taskbar on the top or left shifts them.
    static WorkspaceToScreen(bounds, primary, primaryWork) =>
        {X: bounds.X + primaryWork.Left - primary.Left, Y: bounds.Y + primaryWork.Top - primary.Top, W: bounds.W, H: bounds.H}

    static IsCloaked(hwnd) {
        local cloaked
        static DWMWA_CLOAKED := 14
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_CLOAKED, "UInt*", &cloaked, "UInt", 4)
        return cloaked != 0
    }

    static Monitors() {
        local bottom, left, monitors, right, top
        monitors := []
        loop MonitorGetCount() {
            MonitorGet(A_Index, &left, &top, &right, &bottom)
            monitors.Push({Index: A_Index, Left: left, Top: top, Right: right, Bottom: bottom})
        }
        return monitors
    }

    ; Index of the monitor containing the point, or the nearest one when it's off-screen.
    static MonitorAt(monitors, x, y) {
        local best, bestDistance, dx, dy, mon
        best := 1, bestDistance := ""
        for mon in monitors {
            dx := x < mon.Left ? mon.Left - x : x >= mon.Right ? x - mon.Right + 1 : 0
            dy := y < mon.Top ? mon.Top - y : y >= mon.Bottom ? y - mon.Bottom + 1 : 0
            if !dx && !dy
                return mon.Index
            if bestDistance = "" || dx + dy < bestDistance
                best := mon.Index, bestDistance := dx + dy
        }
        return best
    }

    ; Directional focus: activates the nearest visible window in direction ("left",
    ; "right", "up", "down") by the windows' visible top-left corners, on the current
    ; monitor; at the edge, the nearest window on the next monitor that way, entering
    ; level with the active window. Does nothing when there is none.
    static Focus(direction) => this.InPhysicalPixels(() => this.FocusNow(direction))

    static FocusNow(direction) {
        local active, current, entry, from, monitors, next, target, windows
        if !(active := WinExist("A"))
            return
        from := this.Bounds(active)
        monitors := this.Monitors()
        current := monitors[this.MonitorAt(monitors, from.X, from.Y)]
        windows := this.List({Exclude: active, VisibleOnly: true, Minimized: false})
        target := this.Nearest(this.OnMonitor(windows, current.Index), direction, from.X, from.Y, true)
        if !target {
            if !(next := this.NextMonitor(monitors, current, direction))
                return
            entry := this.EntryPoint(next, direction, from)
            target := this.Nearest(this.OnMonitor(windows, next.Index), direction, entry.X, entry.Y, false)
        }
        if target
            WinActivate("ahk_id " target.Hwnd)
    }

    static OnMonitor(windows, index) {
        local result, win
        result := []
        for win in windows
            if win.Monitor = index
                result.Push(win)
        return result
    }

    ; The monitor wholly beyond current in that direction, nearest first, or "".
    static NextMonitor(monitors, current, direction) {
        local best, beyond, mon, ok
        beyond := []
        for mon in monitors {
            switch direction {
                case "right": ok := mon.Left >= current.Right
                case "left": ok := mon.Right <= current.Left
                case "down": ok := mon.Top >= current.Bottom
                case "up": ok := mon.Bottom <= current.Top
                default: ok := false
            }
            if ok
                beyond.Push({Monitor: mon, X: mon.Left, Y: mon.Top})
        }
        best := this.Nearest(beyond, direction, current.Left, current.Top, false)
        return best ? best.Monitor : ""
    }

    ; Where focus enters monitor mon: its near edge, level with the active window.
    static EntryPoint(mon, direction, from) {
        switch direction {
            case "right": return {X: mon.Left, Y: from.Y}
            case "left": return {X: mon.Right, Y: from.Y}
            case "down": return {X: from.X, Y: mon.Top}
            default: return {X: from.X, Y: mon.Bottom}
        }
    }

    ; The item ({X, Y, …}) nearest (x, y) in the direction, preferring ones in line:
    ; distance along the direction plus twice the sideways offset. With strict, only
    ; items strictly beyond (x, y) count. "" when none does.
    static Nearest(items, direction, x, y, strict) {
        local across, along, best, bestScore, dx, dy, item, score
        best := "", bestScore := ""
        for item in items {
            dx := item.X - x, dy := item.Y - y
            switch direction {
                case "right": along := dx, across := dy
                case "left": along := -dx, across := dy
                case "down": along := dy, across := dx
                default: along := -dy, across := dx
            }
            if strict && along <= 0
                continue
            score := Abs(along) + 2 * Abs(across)
            if bestScore = "" || score < bestScore
                best := item, bestScore := score
        }
        return best
    }

    ; Restores and activates hwnd, first bringing it here from another virtual desktop
    ; when activation alone doesn't switch desktops (PullFromOtherDesktops). Windows on
    ; other desktops are cloaked, which AutoHotkey treats as hidden.
    static Activate(hwnd) {
        local target, wasDetecting
        wasDetecting := DetectHiddenWindows(true)
        try {
            target := "ahk_id " hwnd
            if this.PullFromOtherDesktops && !LegendDesktops().OnCurrent(hwnd)
                LegendDesktops().MoveHere(hwnd)
            if WinGetMinMax(target) = -1
                WinRestore(target)
            WinActivate(target)
        } finally
            DetectHiddenWindows(wasDetecting)
    }
}

; What the windows fed so far cover. Feed windows top first: Add returns the share of
; a window's on-screen area that the earlier ones leave uncovered.
class LegendCoverage {
    static RGN_AND := 1, RGN_OR := 2, RGN_DIFF := 4

    __New(monitors) {
        local mon, rgn
        this.Screen := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
        this.Covered := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
        for mon in monitors {
            rgn := DllCall("CreateRectRgn", "Int", mon.Left, "Int", mon.Top, "Int", mon.Right, "Int", mon.Bottom, "Ptr")
            DllCall("CombineRgn", "Ptr", this.Screen, "Ptr", this.Screen, "Ptr", rgn, "Int", LegendCoverage.RGN_OR)
            DllCall("DeleteObject", "Ptr", rgn)
        }
    }

    __Delete() {
        DllCall("DeleteObject", "Ptr", this.Screen)
        DllCall("DeleteObject", "Ptr", this.Covered)
    }

    Add(bounds) {
        local total, uncovered, window
        window := DllCall("CreateRectRgn", "Int", bounds.X, "Int", bounds.Y, "Int", bounds.X + bounds.W, "Int", bounds.Y + bounds.H, "Ptr")
        uncovered := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
        try {
            DllCall("CombineRgn", "Ptr", window, "Ptr", window, "Ptr", this.Screen, "Int", LegendCoverage.RGN_AND)
            if !(total := LegendCoverage.Area(window))
                return 0
            DllCall("CombineRgn", "Ptr", uncovered, "Ptr", window, "Ptr", this.Covered, "Int", LegendCoverage.RGN_DIFF)
            DllCall("CombineRgn", "Ptr", this.Covered, "Ptr", this.Covered, "Ptr", window, "Int", LegendCoverage.RGN_OR)
            return LegendCoverage.Area(uncovered) / total
        } finally {
            DllCall("DeleteObject", "Ptr", window)
            DllCall("DeleteObject", "Ptr", uncovered)
        }
    }

    ; Sum of the region's rectangles (RGNDATA: 32-byte header, then RECTs).
    static Area(rgn) {
        local area, data, offset, size
        if !(size := DllCall("GetRegionData", "Ptr", rgn, "UInt", 0, "Ptr", 0, "UInt"))
            return 0
        data := Buffer(size)
        DllCall("GetRegionData", "Ptr", rgn, "UInt", size, "Ptr", data, "UInt")
        area := 0
        loop NumGet(data, 8, "UInt") {
            offset := 32 + (A_Index - 1) * 16
            area += (NumGet(data, offset + 8, "Int") - NumGet(data, offset, "Int"))
                  * (NumGet(data, offset + 12, "Int") - NumGet(data, offset + 4, "Int"))
        }
        return area
    }
}

; Windows virtual desktops through the documented IVirtualDesktopManager; desktop
; order and names come from Explorer's registry key (for labels only).
class LegendDesktops {
    static CLSID := "{aa509086-5ca9-4c25-8f95-589d3c07b48a}"
    static IID := "{a5cd92ff-29be-454c-8d04-d82879fb3f1b}"
    static RegKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops"

    __New() {
        try
            this.Manager := ComObject(LegendDesktops.CLSID, LegendDesktops.IID)
        catch
            this.Manager := ""
    }

    ; True when hwnd is on the current desktop (or when that can't be told).
    OnCurrent(hwnd) {
        local onCurrent
        onCurrent := 1
        if this.Manager
            try ComCall(3, this.Manager, "Ptr", hwnd, "Int*", &onCurrent)
        return onCurrent != 0
    }

    ; hwnd's desktop GUID as "{…}" text, or "" for none (background UWP ghosts).
    DesktopOf(hwnd) {
        local guid, text
        if !this.Manager
            return ""
        guid := Buffer(16, 0)
        try
            ComCall(4, this.Manager, "Ptr", hwnd, "Ptr", guid)
        catch
            return ""
        text := LegendDesktops.GuidText(guid)
        return text = "{00000000-0000-0000-0000-000000000000}" ? "" : text
    }

    ; Moves hwnd to the current desktop (the desktop of the active window).
    MoveHere(hwnd) {
        local here
        if !this.Manager
            return
        here := Buffer(16, 0)
        try {
            ComCall(4, this.Manager, "Ptr", WinExist("A"), "Ptr", here)
            ComCall(5, this.Manager, "Ptr", hwnd, "Ptr", here)
        }
    }

    static GuidText(guid) {
        local text
        text := Buffer(80, 0)
        DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", text, "Int", 40)
        return StrGet(text, "UTF-16")
    }

    ; The desktop's name, else "desktop N" by its place in Explorer's list, else
    ; "another desktop".
    static Label(desktopId) {
        local guid, hex, ids, name, position
        try {
            name := RegRead(this.RegKey "\Desktops\" desktopId, "Name")
            if name != ""
                return name
        }
        try {
            ids := RegRead(this.RegKey, "VirtualDesktopIDs")   ; REG_BINARY as hex text
            loop StrLen(ids) // 32 {
                position := A_Index
                hex := SubStr(ids, (position - 1) * 32 + 1, 32)
                guid := Buffer(16)
                loop 16
                    NumPut("UChar", Integer("0x" SubStr(hex, A_Index * 2 - 1, 2)), guid, A_Index - 1)
                if this.GuidText(guid) = desktopId
                    return "desktop " position
            }
        }
        return "another desktop"
    }
}
