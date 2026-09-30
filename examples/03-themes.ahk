#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk

; 03 · Themes
;
; Shows: a theme file (examples\themes\sunset.ini) found through the Themes option,
; with its own colors, fonts, compact density and symbol key notation (which adds
; the modifier legend line). Leave Theme out to follow Windows light/dark with
; the built-in Catppuccin Latte/Mocha.
;
; Keys: Ctrl+Alt+Shift+/ opens the overlay. Tab cycles key notation (text, symbols,
;   AHK), = switches comfortable/compact; both last until the script reloads.
;
; Run it with AutoHotkey v2; exit from its tray icon.

Legend.Page("Themed").Category("Windows", [
    ["^!+w", "snap window left", (*) => Send("#{Left}")],
    ["^!+e", "snap window right", (*) => Send("#{Right}")],
    ["^!+m", "minimize", (*) => WinMinimize("A")]
])
Legend.Doc(["Themed", "Windows"], "Win+Shift+S", "screenshot a region")

Legend.Start({HelpKey: "^!+/", Themes: [A_LineFile "\..\themes"], Theme: "sunset"})
