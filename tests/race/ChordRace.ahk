#Requires AutoHotkey v2.0
; Regression check for the chord-key race (fast keys interrupting a submenu redraw).
; A second process sends the keys so they arrive asynchronously, like a real keyboard.
; Run by hand (it shows overlays and uses F13–F24); expects "stranded=0 missed=0 errors=0" in
; %TEMP%\legend-chord-race.txt.
#SingleInstance Force
#NoTrayIcon
#Include %A_ScriptDir%\..\..\Legend.ahk
logPath := A_Temp "\legend-chord-race.txt"
FileOpen(logPath, "w").Write("")
Log2(msg) => FileAppend(msg "`n", logPath)
errors := 0
OnError(CountError)
CountError(e, mode) {
    global errors
    Log2("ERROR " e.Message " @" e.Line)
    errors += 1
    return 1
}
sub := [Legend.Run("F14", "Go", () => 0)]
loop 30
    sub.Push(Legend.Run("F" (15 + Mod(A_Index, 9)), "Item number " A_Index " with a long label", () => 0))
race := Legend.Chord("^!+F12", "Race", [Legend.Menu("F13", "Sub", sub)])
Legend.Start({HelpKey: "^!+F11", ChordOverlay: "always"})
stranded := 0, missed := 0
loop 24 {
    gap := Mod(A_Index, 6) * 8          ; 0..40 ms between the two keys
    Legend.OpenChord(race)
    session := Legend.Session
    Run('"' A_AhkPath '" "' A_ScriptDir '\RaceSender.ahk" ' gap)
    Sleep(900)
    for hwnd in WinGetList("ahk_pid " DllCall("GetCurrentProcessId", "UInt"))
        if WinGetClass(hwnd) = "AutoHotkeyGUI" && DllCall("IsWindowVisible", "Ptr", hwnd)
            stranded += 1
    if !session.Closed || IsObject(Legend.Session) {
        missed += 1
        Legend.Close(), Log2("trial " A_Index ": chord still open (keys missed)")
    }
}
result := "trials=24 stranded=" stranded " missed=" missed " errors=" errors
Log2(result)
FileAppend(result "`n", "*")
ExitApp(stranded + missed + errors)
