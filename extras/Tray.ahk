#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\Legend.ahk

; Legend extra: a picker over the notification area (system tray).
; MAY BREAK WITH WINDOWS UPDATES: it reads Windows 11's taskbar through UI
; Automation (tested on build 26220). When the names below stop matching, the
; picker shows "Tray not available on this Windows version". See README › Extras.
; Include it after Legend.ahk:  #Include Lib\Legend\extras\Tray.ahk

class LegendTray {
    static TrayClass := "Shell_TrayWnd"
    static OverflowClass := "TopLevelWindowForOverflowXamlIsland"
    static AppIconId := "NotifyItemIcon"
    static SystemIconId := "SystemTrayIcon"
    static Available := true

    ; First non-empty line, trimmed, inner runs of spaces collapsed.
    static Clean(name) {
        for line in StrSplit(name, "`n", "`r") {
            line := Trim(RegExReplace(line, "\s+", " "))
            if line != ""
                return line
        }
        return ""
    }

    ; Numbers items that share Name and Hidden: 1, 2, … (sets item.Ordinal).
    static Ordinals(items) {
        seen := Map()
        for item in items {
            itemKey := item.Hidden "|" item.Name
            seen[itemKey] := seen.Has(itemKey) ? seen[itemKey] + 1 : 1
            item.Ordinal := seen[itemKey]
        }
        return items
    }

    static ExeName(path) => RegExReplace(RegExReplace(path, ".*\\"), "i)\.exe$")

    ; The entry ({Exe, Tip}) confidently behind tray name, or "": the entry's
    ; tooltip equals or starts the name's first line, or the exe's name is the
    ; name's first word(s) followed by a non-word character or the end.
    static Match(name, entries) {
        first := this.Clean(name)
        if first = ""
            return ""
        for entry in entries
            if entry.Tip != "" && (first = entry.Tip || SubStr(first, 1, StrLen(entry.Tip)) = entry.Tip)
                return entry
        for entry in entries {
            exe := this.ExeName(entry.Exe)
            if exe != "" && RegExMatch(first, "i)^\Q" exe "\E(?![\w])")
                return entry
        }
        return ""
    }
}
