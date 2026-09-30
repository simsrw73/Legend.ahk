#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk

; 04 · Chords
;
; Shows: a chord menu (press a trigger, then keys) with a submenu, a running-app
; dot (Status), an item that only exists in one app (If + Hint), a string that is
; sent as keys, and a wildcard key range that passes the key to its action.
; Chords also appear as pages in the overlay.
;
; Keys: Ctrl+Alt+Shift+Space, then:
;   n  Notepad (a dot shows when it's running)
;   t  Text › d (date) or s (sign-off, sent as keys)
;   x  close tab, only in Notepad (the If condition)
;   1–3  show the digit you pressed
;   Backspace goes up a level, Ctrl+F/B page, Esc or Ctrl+G cancels.
;   The menu appears after 400 ms unless you finish the chord first.
;   Ctrl+Alt+Shift+/ opens the overlay, where the chord has its own page.
;
; Run it with AutoHotkey v2; exit from its tray icon.

inNotepad := () => WinActive("ahk_exe notepad.exe")

Legend.Chord("^!+Space", "Demo chords", [
    Legend.Run("n", "Notepad", (*) => Run("notepad.exe"), {Status: () => WinExist("ahk_exe notepad.exe")}),
    Legend.Menu("t", "Text", [
        Legend.Run("d", "Type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))),
        Legend.Run("s", "Type a sign-off", "Thanks,{Enter}Me")
    ]),
    Legend.Run("x", "Close tab", "^w", {If: inNotepad, Hint: "in Notepad"}),
    Legend.Run("1-3", "Show a digit", key => MsgBox("You pressed " key))
])

Legend.Start({HelpKey: "^!+/"})
