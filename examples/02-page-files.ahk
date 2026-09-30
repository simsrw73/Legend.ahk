#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk

; 02 · Page files
;
; Shows: Markdown pages of an app's own shortcuts (examples\pages\*.md), shown next
; to the keys you bind. A file's `match:` decides which page opens for the active
; window; a key you also bind in code is shown as bound, the rest as doc-only.
; pages\paging-demo.md is too big for one screen, so its categories become a menu.
;
; Keys: Ctrl+Alt+Shift+/ opens the overlay (in Notepad: Notepad's page).
;   Ctrl+Alt+D, bound below in Notepad only, shows as bound on Notepad's page.
;   In a menu: Ctrl+N/P or ↓/↑ move, Enter opens; Ctrl+F/B or Space page.
;
; Page file syntax: # page · ## category · ### group · - `Keys` description.
; Run it with AutoHotkey v2; exit from its tray icon.

Legend.Page("Notepad", "ahk_exe notepad.exe").Category("Editing", [
    ["^!d", "insert today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))]
], "Text")

Legend.Start({HelpKey: "^!+/", Pages: [A_LineFile "\..\pages"]})
