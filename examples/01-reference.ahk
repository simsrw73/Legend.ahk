#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk

; 01 · Reference pages from code
;
; Shows: pages and categories built from the hotkeys you bind, a one-line
; Legend.Bind, groups inside a category, merged rows ({Row, Text}), a doc-only key,
; and an app-only page that works (and opens) only in Notepad.
;
; Keys: Ctrl+Alt+Shift+/ opens the overlay: the index, or Notepad's page in Notepad.
;   In the index: Ctrl+N/P or ↓/↑ move, Enter or a letter opens, Backspace goes back,
;   Ctrl+F/B or Space page, ` pins, Tab changes key notation, = density, Esc closes.
;   Ctrl+Alt+Shift+M / W / E / C / U are the example's own keys (see the page).
;
; The examples use Ctrl+Alt+Shift keys so they run alongside your own script.
; Run it with AutoHotkey v2; exit from its tray icon.

; A page from a table of rows: [hotkey, description, action, options?]
Legend.Page("Example").Category("General", [
    ["^!+m", "show a message", (*) => MsgBox("Hello from Legend")],
    ; two hotkeys shown as one row
    ["^!+w", "snap window left", (*) => Send("#{Left}"), {Row: "Ctrl+Alt+Shift+W/E", Text: "snap window ← / →"}],
    ["^!+e", "snap window right", (*) => Send("#{Right}"), {Row: "Ctrl+Alt+Shift+W/E"}]
])

; A group ("Text") inside a category, then a one-line binding into the same group
Legend.Page("Example").Category("Clipboard", [
    ["^!+c", "copy today's date", (*) => A_Clipboard := FormatTime(, "yyyy-MM-dd")]
], "Text")
Legend.Bind(["Example", "Clipboard", "Text"], "^!+u", "uppercase the clipboard", (*) => A_Clipboard := StrUpper(A_Clipboard))

; A key you don't bind but want to remember: shown in a muted color
Legend.Doc(["Example", "Windows"], "Win+Up", "maximize (Windows' own key)")

; An app-only page: give the page its match before binding keys on it
notepad := Legend.Page("Notepad", "ahk_exe notepad.exe")
notepad.Category("Editing", [
    ["^!+d", "insert today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))]
])

Legend.Start({HelpKey: "^!+/"})
