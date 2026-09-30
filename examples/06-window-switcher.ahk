#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk

; 06 · Window switcher and directional focus
;
; Shows: Legend.WindowSwitcher, a picker over your windows (most recent first, the
; previous one selected; the highlighted window comes forward with an outline and
; goes back on Esc), with two switchers on different scopes and a Detail hook; and
; LegendWindows.Focus, which moves focus to the nearest visible window in a
; direction, crossing to the next monitor at the edge.
;
; Keys: Ctrl+Alt+Shift+A  switcher over all windows (every virtual desktop)
;       Ctrl+Alt+Shift+S  switcher over this monitor
;         Ctrl+N/P or ↓/↑ move, a letter or Enter switches, / filters, Ctrl+T cycles
;         all windows / this desktop / this monitor, Esc cancels.
;       Ctrl+Alt+Shift+H/J/K/L  focus the window left / down / up / right.
;         (A window manager setup would use Alt+H/J/K/L, as komorebi's does.)
;       Ctrl+Alt+Shift+/ opens the overlay.
;
; Run it with AutoHotkey v2; exit from its tray icon.

; Detail: the row's right-hand text. win has Hwnd, Title, App, X, Y, W, H, Monitor,
; Minimized, Cloaked, OnCurrentDesktop. (Include and Activate are the other hooks,
; for window managers that hide windows or switch workspaces.)
Legend.WindowSwitcher("^!+a", {Scope: "all", Detail: win => win.App " · monitor " win.Monitor})
Legend.WindowSwitcher("^!+s", {Scope: "monitor"})

Legend.Page("Windows").Category("Focus", [
    ["^!+h", "focus left", (*) => LegendWindows.Focus("left"), {Row: "Ctrl+Alt+Shift+H/J/K/L", Text: "focus ← ↓ ↑ →"}],
    ["^!+j", "focus down", (*) => LegendWindows.Focus("down"), {Row: "Ctrl+Alt+Shift+H/J/K/L"}],
    ["^!+k", "focus up", (*) => LegendWindows.Focus("up"), {Row: "Ctrl+Alt+Shift+H/J/K/L"}],
    ["^!+l", "focus right", (*) => LegendWindows.Focus("right"), {Row: "Ctrl+Alt+Shift+H/J/K/L"}]
])

Legend.Start({HelpKey: "^!+/"})
