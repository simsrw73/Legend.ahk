#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\..\..\Legend.ahk

; Hammers a picker with fast keys, using this process's edit control as an input
; sink. Reports closed sessions, queued keys, overlays and stray input on stdout.
#NoTrayIcon
sink := Gui("+ToolWindow", "Legend picker race input")
input := sink.AddEdit("w400 r2")
sink.Show()
SendLevel(1)
SetKeyDelay(-1, -1)
picked := 0, cancelled := 0, errors := 0, missed := 0, stranded := 0, backlog := 0
OnError(CountError)
CountError(e, mode) {
    global errors
    FileAppend("ERROR " e.Message " @" e.Line "`n", "*")
    errors += 1
    return 1
}
Legend.Picker("^!+F12", "Race", (*) => RaceItems(),
    {OnPick: CountPick, OnCancel: CountCancel})
Legend.Start()

CountPick(item) {
    global picked
    picked += 1
}

CountCancel() {
    global cancelled
    cancelled += 1
}

RaceItems() {
    local items
    items := []
    loop 40
        items.Push({Text: "row " A_Index})
    return items
}

WaitClosed(session) {
    local deadline
    deadline := A_TickCount + 1000
    while IsObject(session) && !session.Closed && A_TickCount < deadline
        Sleep(5)
}

loop 30 {
    SendEvent("^!+{F12}")
    Sleep(30)   ; let the hotkey thread open the picker
    first := Legend.Session
    SendEvent("jjjjkkkk{Down}{Up}/row 1{Backspace}{Esc}{Esc}")
    WaitClosed(first)   ; the next trigger belongs to the next interaction
    SendEvent("^!+{F12}")
    Sleep(30)
    second := Legend.Session
    SendEvent("a")
    WaitClosed(second)
    for session in [first, second] {
        if !(session is LegendPickerSession) || !session.Closed
            missed += 1
        else
            backlog += session.Pending.Length
    }
}
Sleep(1500)
for hwnd in WinGetList("ahk_pid " DllCall("GetCurrentProcessId", "UInt"))
    if hwnd != sink.Hwnd && WinGetClass(hwnd) = "AutoHotkeyGUI" && DllCall("IsWindowVisible", "Ptr", hwnd)
        stranded += 1
result := "trials=30 picked=" picked " cancelled=" cancelled " missed=" missed " stranded=" stranded " backlog=" backlog
    . " stray=" StrLen(input.Text) " errors=" errors
FileAppend(result "`n", "*")
failed := picked != 30 || cancelled != 30 || IsObject(Legend.Session) || missed || stranded || backlog || input.Text != "" || errors
Legend.Close(false)
sink.Destroy()
ExitApp(failed)
