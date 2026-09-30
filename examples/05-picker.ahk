#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk

; 05 · Pickers
;
; Shows: Legend.Picker, a list you choose from: a source function that builds the
; items, two scopes, a detail column, a fixed letter, and OnPick / OnHighlight /
; OnCancel callbacks.
;
; Keys: Ctrl+Alt+Shift+O opens the picker.
;   Ctrl+N/P or ↓/↑ move, a letter or Enter picks, / filters (every word must
;   match; Esc clears the filter), Ctrl+T switches Folders / Tools, Ctrl+F/B page,
;   = density, Esc cancels.
;   Ctrl+Alt+Shift+/ opens the overlay; the picker is listed on its "Pickers" page.
;
; Run it with AutoHotkey v2; exit from its tray icon.

Legend.Picker("^!+o", "Open", scope => OpenItems(scope), {
    Scopes: ["Folders", "Tools"],
    OnPick: item => Run(item.Data),
    OnHighlight: item => ToolTip(IsObject(item) ? item.Data : ""),
    OnCancel: () => ToolTip()
})

; Items: {Text, Detail?, Icon?, Letter?, Data?}. Data is yours, passed back on pick.
OpenItems(scope) {
    items := []
    if scope = "Folders" {
        for name, path in Map("Documents", A_MyDocuments, "Desktop", A_Desktop,
                "Downloads", EnvGet("USERPROFILE") "\Downloads", "Temp", A_Temp)
            items.Push({Text: name, Detail: path, Data: path, Letter: name = "Documents" ? "d" : ""})
        ; Documents always gets d; the others get the next free home-row letters
    } else {
        for name, command in Map("Notepad", "notepad.exe", "Calculator", "calc.exe",
                "Character Map", "charmap.exe", "Task Manager", "taskmgr.exe")
            items.Push({Text: name, Detail: command, Data: command})
    }
    return items
}

Legend.Start({HelpKey: "^!+/"})
