#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\..\Legend.ahk

; Press Alt+/ anywhere for the index, or in Notepad for its page.

notepad := Legend.Page("Notepad", "ahk_exe notepad.exe")
notepad.Category("Editing", [
    ["^!d", "insert today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))]
])

Legend.Page("Example").Category("General", [
    ["^!+m", "show a message", (*) => MsgBox("Hello from Legend")],
    ["^!+w", "move window left", (*) => Send("#{Left}"), {Row: "Ctrl+Alt+Shift+W/E", Text: "snap window ← / →"}],
    ["^!+e", "move window right", (*) => Send("#{Right}"), {Row: "Ctrl+Alt+Shift+W/E"}]
])

; Ctrl+Alt+Shift+Space: a chord menu (appears after 400 ms unless you type the keys first).
Legend.Chord("^!+Space", "Demo chords", [
    Legend.Run("n", "Notepad", (*) => Run("notepad.exe"), {Status: () => WinExist("ahk_exe notepad.exe")}),
    Legend.Menu("t", "Text", [
        Legend.Run("d", "Type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))),
        Legend.Run("s", "Type a sign-off", "Thanks,{Enter}Me")
    ]),
    Legend.Run("1-3", "Show a digit", key => MsgBox("You pressed " key))
])

Legend.Start({Pages: [A_ScriptDir "\pages"]})
