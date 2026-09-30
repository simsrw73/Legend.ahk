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

; Ctrl+Alt+Shift+P: a picker. j/k or Ctrl+N/P move, a letter or Enter picks, / filters,
; h/l switch between the two scopes, Esc cancels.
Legend.Picker("^!+p", "Colors", scope => DemoColors(scope), {
    OnPick: item => MsgBox("You picked " item.Text),
    Scopes: ["warm", "cool"]
})

DemoColors(scope) {
    names := scope = "warm" ? ["Red", "Orange", "Yellow", "Coral", "Amber", "Crimson"]
        : ["Blue", "Teal", "Green", "Cyan", "Indigo", "Violet"]
    items := []
    for name in names
        items.Push({Text: name, Detail: scope})
    return items
}

; Ctrl+Alt+Shift+A / S: window switchers (all windows / this monitor). h/l change scope.
Legend.WindowSwitcher("^!+a", {Scope: "all"})
Legend.WindowSwitcher("^!+s", {Scope: "monitor"})

Legend.Start({Pages: [A_ScriptDir "\pages"]})
