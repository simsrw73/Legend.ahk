#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk
#Include %A_LineFile%\..\..\extras\Tray.ahk

; 07 · Tray picker (extra, may break with Windows updates)
;
; Shows: LegendTray.Picker, every notification-area icon (visible, hidden in the
; "Show hidden icons" flyout, and system icons) in a picker. It reads Windows 11's
; taskbar through UI Automation; on other Windows versions it says the tray is
; not available.
;
; Keys: Ctrl+Alt+Shift+T opens it. Enter or a letter left-clicks the icon,
;   Shift+Enter opens its context menu, / filters, Ctrl+N/P move, Esc cancels.
;   Ctrl+Alt+Shift+/ opens the overlay.
;
; Run it with AutoHotkey v2; exit from its tray icon.

LegendTray.Picker("^!+t")

Legend.Start({HelpKey: "^!+/"})
