#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\..\..\Legend.ahk

; Hammers a picker with fast keys: it must end closed, with no overlay left behind.
; Focus an empty Notepad first (stray keys land there), run it, keep hands off the
; keyboard for ~10 s, read the result box.
SendLevel(1)
Legend.Picker("^!+F12", "Race", (*) => RaceItems(), {OnPick: (*) => ""})
Legend.Start()

RaceItems() {
    items := []
    loop 40
        items.Push({Text: "row " A_Index})
    return items
}

loop 30 {
    Send("^!+{F12}")
    Sleep(30)   ; let the hotkey thread open the picker
    Send("jjjjkkkk{Down}{Up}/row 1{Backspace}{Esc}{Esc}")
    Send("^!+{F12}")
    Sleep(30)
    Send("a")
    Sleep(50)
}
Sleep(1500)
MsgBox(Legend.PickerState = "" && !Legend.Gui ? "PASS: closed cleanly" : "FAIL: picker left open")
ExitApp()
