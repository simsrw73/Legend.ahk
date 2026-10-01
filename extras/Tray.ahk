#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\..\Legend.ahk

; Legend extra: a picker over the notification area (system tray).
; MAY BREAK WITH WINDOWS UPDATES: it reads Windows 11's taskbar through UI
; Automation (tested on build 26220). When the names below stop matching, the
; picker shows "Tray not available on this Windows version". See README › Extras.
; Include it after Legend.ahk:  #Include Lib\Legend\extras\Tray.ahk

; Minimal UI Automation (IUIAutomation) over ComCall: elements by handle, find by
; one property, read name/id/class/rectangle, Invoke, SetFocus.
class LegendUIA {
    static CLSID := "{ff48dba4-60ef-4201-aa87-54103eef594e}"
    static IID := "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}"
    static NameProperty := 30005, AutomationIdProperty := 30011, ClassNameProperty := 30012
    static Children := 2, Descendants := 4
    static _instance := ""

    static Instance {
        get {
            if !this._instance
                this._instance := ComObject(this.CLSID, this.IID)
            return this._instance
        }
    }

    static Root() {
        element := 0
        try
            ComCall(5, this.Instance, "Ptr*", &element)
        catch
            return ""
        return element ? LegendUIAElement(element) : ""
    }

    static FromHandle(hwnd) {
        element := 0
        try
            ComCall(6, this.Instance, "Ptr", hwnd, "Ptr*", &element)
        catch
            return ""
        return element ? LegendUIAElement(element) : ""
    }

    ; A property condition for a string value (the VARIANT goes by pointer on x64).
    static Condition(propertyId, value) {
        variant := Buffer(24, 0)
        text := DllCall("oleaut32\SysAllocString", "Str", value, "Ptr")
        NumPut("UShort", 8, variant, 0)        ; VT_BSTR
        NumPut("Ptr", text, variant, 8)
        condition := 0
        try
            ComCall(23, this.Instance, "Int", propertyId, "Ptr", variant, "Ptr*", &condition)
        finally
            DllCall("oleaut32\SysFreeString", "Ptr", text)
        return condition
    }
}

class LegendUIAElement {
    __New(ptr) => this.Ptr := ptr
    __Delete() => this.Ptr && ObjRelease(this.Ptr)

    Name => this.Text(23)

    Hwnd {
        get {
            handle := 0
            ComCall(36, this.Ptr, "Ptr*", &handle)
            return handle
        }
    }

    AutomationId => this.Text(29)
    ClassName => this.Text(30)

    Rect {
        get {
            rect := Buffer(16, 0)
            ComCall(43, this.Ptr, "Ptr", rect)
            left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
            return {X: left, Y: top, W: NumGet(rect, 8, "Int") - left, H: NumGet(rect, 12, "Int") - top}
        }
    }

    Text(slot) {
        text := 0
        ComCall(slot, this.Ptr, "Ptr*", &text)
        value := text ? StrGet(text, "UTF-16") : ""
        DllCall("oleaut32\SysFreeString", "Ptr", text)
        return value
    }

    FindAll(scope, propertyId, value) {
        condition := LegendUIA.Condition(propertyId, value), found := 0, result := []
        try {
            ComCall(6, this.Ptr, "Int", scope, "Ptr", condition, "Ptr*", &found)
            if !found
                return result
            count := 0
            ComCall(3, found, "Int*", &count)
            loop count {
                element := 0
                ComCall(4, found, "Int", A_Index - 1, "Ptr*", &element)
                result.Push(LegendUIAElement(element))
            }
        } finally {
            ObjRelease(condition)
            if found
                ObjRelease(found)
        }
        return result
    }

    FindFirst(scope, propertyId, value) {
        condition := LegendUIA.Condition(propertyId, value), element := 0
        try
            ComCall(5, this.Ptr, "Int", scope, "Ptr", condition, "Ptr*", &element)
        finally
            ObjRelease(condition)
        return element ? LegendUIAElement(element) : ""
    }

    Invoke() {
        static InvokePattern := 10000
        pattern := 0
        ComCall(16, this.Ptr, "Int", InvokePattern, "Ptr*", &pattern)
        if !pattern
            throw Error("element has no Invoke pattern", -1)
        try
            ComCall(3, pattern)
        finally
            ObjRelease(pattern)
    }

    SetFocus() => ComCall(3, this.Ptr)
}

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
