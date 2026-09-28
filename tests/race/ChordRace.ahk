#Requires AutoHotkey v2.0
; Regression check for the chord-key race (fast keys interrupting a submenu redraw).
; A second process sends the keys so they arrive asynchronously, like a real keyboard.
; Run by hand (it shows overlays and uses F13–F24); expects "stranded=0 errors=0" in
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
stranded := 0
loop 24 {
    gap := Mod(A_Index, 6) * 8          ; 0..40 ms between the two keys
    Legend.OpenChord(race)
    Run('"' A_AhkPath '" "' A_ScriptDir '\RaceSender.ahk" ' gap)
    Sleep(900)
    if Legend.Gui && !Legend.ChordState
        stranded += 1, Legend.Gui.Destroy(), Legend.Gui := ""
    if Legend.ChordState
        Legend.CloseChord(), Log2("trial " A_Index ": chord still open (keys missed)")
}
Log2("trials=24 stranded=" stranded " errors=" errors)
ExitApp(0)
