#Requires AutoHotkey v2.0

Windows_OneMonitor() => [{Index: 1, Left: 0, Top: 0, Right: 1000, Bottom: 1000}]

T.Test("Windows: coverage counts what windows above leave uncovered", Windows_Coverage)
Windows_Coverage() {
    cov := LegendCoverage(Windows_OneMonitor())
    T.Eq(cov.Add({X: 0, Y: 0, W: 500, H: 500}), 1, "top window fully visible")
    T.Eq(cov.Add({X: 0, Y: 0, W: 500, H: 500}), 0, "same rect underneath: buried")
    T.Eq(cov.Add({X: 250, Y: 0, W: 500, H: 500}), 0.5, "half covered")
    T.Eq(cov.Add({X: 2000, Y: 0, W: 100, H: 100}), 0, "off-screen")
    T.Eq(cov.Add({X: 900, Y: 900, W: 200, H: 200}), 1, "only the on-screen part counts")
}

T.Test("Windows: MonitorAt picks the containing or nearest monitor", Windows_MonitorAt)
Windows_MonitorAt() {
    monitors := [{Index: 1, Left: 0, Top: 0, Right: 3840, Bottom: 2160},
                 {Index: 2, Left: 3840, Top: 0, Right: 6400, Bottom: 1440}]
    T.Eq(LegendWindows.MonitorAt(monitors, 3856, 60), 2)
    T.Eq(LegendWindows.MonitorAt(monitors, 3839, 60), 1)
    T.Eq(LegendWindows.MonitorAt(monitors, -8, -8), 1, "maximized-style negative corner")
    T.Eq(LegendWindows.MonitorAt(monitors, 5000, 2000), 2, "below monitor 2")
}

T.Test("Windows: desktop labels fall back without registry data", Windows_DesktopLabel)
Windows_DesktopLabel() {
    T.Eq(LegendDesktops.Label("{00000000-0000-0000-0000-000000000001}"), "another desktop")
}

T.Test("Switcher: the preselected row skips the active window only when it is listed", Switcher_StartFor)
Switcher_StartFor() {
    T.Eq(LegendWindowSwitcher.StartFor(2, true), 2, "active window is row 1")
    T.Eq(LegendWindowSwitcher.StartFor(2, false), 1, "desktop or an unlisted window is active")
    T.Eq(LegendWindowSwitcher.StartFor(1, false), 1)
}

T.Test("Windows: workspace coordinates shift by the primary work area's offset", Windows_WorkspaceToScreen)
Windows_WorkspaceToScreen() {
    primary := {Left: 0, Top: 0, Right: 3840, Bottom: 2160}
    topBar := {Left: 0, Top: 48, Right: 3840, Bottom: 2160}
    moved := LegendWindows.WorkspaceToScreen({X: 100, Y: 0, W: 800, H: 600}, primary, topBar)
    T.Eq(moved.X, 100)
    T.Eq(moved.Y, 48)
    T.Eq(moved.H, 600)
    same := LegendWindows.WorkspaceToScreen({X: 5, Y: 5, W: 1, H: 1}, primary, primary)
    T.Eq(same.Y, 5, "bottom taskbar: no offset")
}
