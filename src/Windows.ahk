#Requires AutoHotkey v2.0

; Switchable top-level windows, front to back, in physical pixels.
class LegendWindows {
    static MinVisibleShare := 0.1
    static PullFromOtherDesktops := false   ; Task 0: true if WinActivate doesn't switch desktops
    static Shell := Map("Progman", 1, "WorkerW", 1, "Shell_TrayWnd", 1, "Shell_SecondaryTrayWnd", 1)

    ; Runs fn with the thread per-monitor DPI aware (v2): DWM bounds are always physical
    ; pixels, and MonitorGet agrees with them only in that mode.
    static InPhysicalPixels(fn) {
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
        static DWMWA_EXTENDED_FRAME_BOUNDS := 9
        rect := Buffer(16, 0)
        if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", rect, "UInt", 16) = 0 {
            left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
            return {X: left, Y: top, W: NumGet(rect, 8, "Int") - left, H: NumGet(rect, 12, "Int") - top}
        }
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " hwnd)
        return {X: winX, Y: winY, W: winW, H: winH}
    }

    ; Where a minimized window will be restored (WINDOWPLACEMENT.rcNormalPosition).
    static NormalBounds(hwnd) {
        placement := Buffer(44, 0)
        NumPut("UInt", 44, placement)
        DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", placement)
        left := NumGet(placement, 28, "Int"), top := NumGet(placement, 32, "Int")
        return {X: left, Y: top, W: NumGet(placement, 36, "Int") - left, H: NumGet(placement, 40, "Int") - top}
    }

    static IsCloaked(hwnd) {
        static DWMWA_CLOAKED := 14
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_CLOAKED, "UInt*", &cloaked, "UInt", 4)
        return cloaked != 0
    }

    static Monitors() {
        monitors := []
        loop MonitorGetCount() {
            MonitorGet(A_Index, &left, &top, &right, &bottom)
            monitors.Push({Index: A_Index, Left: left, Top: top, Right: right, Bottom: bottom})
        }
        return monitors
    }

    ; Index of the monitor containing the point, or the nearest one when it's off-screen.
    static MonitorAt(monitors, x, y) {
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

    ; Restores and activates win, first bringing it here from another virtual desktop
    ; when activation alone doesn't switch desktops (PullFromOtherDesktops).
    static Activate(win) {
        wasDetecting := DetectHiddenWindows(true)
        try {
            target := "ahk_id " win.Hwnd
            if !win.OnCurrentDesktop && this.PullFromOtherDesktops
                LegendDesktops().MoveHere(win.Hwnd)
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
        onCurrent := 1
        if this.Manager
            try ComCall(3, this.Manager, "Ptr", hwnd, "Int*", &onCurrent)
        return onCurrent != 0
    }

    ; hwnd's desktop GUID as "{…}" text, or "" for none (background UWP ghosts).
    DesktopOf(hwnd) {
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
        if !this.Manager
            return
        here := Buffer(16, 0)
        try {
            ComCall(4, this.Manager, "Ptr", WinExist("A"), "Ptr", here)
            ComCall(5, this.Manager, "Ptr", hwnd, "Ptr", here)
        }
    }

    static GuidText(guid) {
        text := Buffer(80, 0)
        DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", text, "Int", 40)
        return StrGet(text, "UTF-16")
    }

    ; The desktop's name, else "desktop N" by its place in Explorer's list, else
    ; "another desktop".
    static Label(desktopId) {
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
