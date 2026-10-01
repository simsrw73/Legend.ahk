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

    static Icons := Map()        ; icons Legend extracted for the open picker
    static PickerObject := ""    ; the picker Picker() created, for its EmptyText

    ; The overflow flyout's element while it is open, else "". The flyout lives in a
    ; band FindWindow / WinExist can't see, so it is found through UI Automation.
    static Flyout() {
        root := LegendUIA.Root()
        return root ? root.FindFirst(LegendUIA.Children, LegendUIA.ClassNameProperty, this.OverflowClass) : ""
    }

    static FlyoutOpen() => this.Flyout() != ""

    static Root() {
        hwnd := WinExist("ahk_class " this.TrayClass)
        return hwnd ? LegendUIA.FromHandle(hwnd) : ""
    }

    ; "Show Hidden Icons": the first system icon when IsChevron says so, else "".
    static Chevron(root) {
        systems := root.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, this.SystemIconId)
        return systems.Length && this.IsChevron(systems[1], this.FirstAppX(root)) ? systems[1] : ""
    }

    ; The chevron is the system icon left of the first visible app icon. Its exact
    ; position shifts while the flyout opens and closes, so this asks again each
    ; time. With no visible app icon, only an English "Hidden" name identifies it.
    static IsChevron(element, firstAppX) => firstAppX != "" ? element.Rect.X < firstAppX : InStr(element.Name, "Hidden") > 0

    static FirstAppX(root) {
        apps := root.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, this.AppIconId)
        return apps.Length ? apps[1].Rect.X : ""
    }

    ; Opens the flyout with chevron and waits for it (up to 1 s); "" if it doesn't come.
    static OpenFlyout(chevron) {
        chevron.Invoke()
        deadline := A_TickCount + 1000
        while A_TickCount < deadline {
            if flyout := this.Flyout()
                return flyout
            Sleep(5)
        }
        return ""
    }

    ; Sets the flyout fully transparent (layered, alpha 0); returns its old ex-style.
    static Hide(hwnd) {
        static GWL_EXSTYLE := -20, WS_EX_LAYERED := 0x80000, LWA_ALPHA := 0x2
        exStyle := DllCall("GetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
        DllCall("SetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", exStyle | WS_EX_LAYERED)
        DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", 0, "UInt", LWA_ALPHA)
        return exStyle
    }

    static Unhide(hwnd, exStyle) {
        static GWL_EXSTYLE := -20
        DllCall("SetWindowLongPtrW", "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", exStyle)
    }

    ; Runs fn(flyout) with the flyout open (and invisible when Legend opened it),
    ; then closes it again unless it was already open. fn gets "" when it can't open.
    static WithFlyout(root, fn) {
        if flyout := this.Flyout()
            return fn(flyout)
        if !(chevron := this.Chevron(root)) || !(flyout := this.OpenFlyout(chevron))
            return fn("")
        hwnd := flyout.Hwnd, exStyle := this.Hide(hwnd)
        try
            return fn(flyout)
        finally {
            this.Unhide(hwnd, exStyle)
            if this.FlyoutOpen()
                chevron.Invoke()
        }
    }

    static List() {
        this.Available := false
        if !(root := this.Root())
            return []
        items := []
        for element in root.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, this.AppIconId)
            items.Push({Name: element.Name, Kind: "app", Hidden: false})
        this.WithFlyout(root, flyout => this.AddHidden(items, flyout))
        firstAppX := this.FirstAppX(root)
        for element in root.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, this.SystemIconId)
            if !this.IsChevron(element, firstAppX)
                items.Push({Name: element.Name, Kind: "system", Hidden: false})
        if !items.Length
            return []
        for item in items
            item.Text := this.Clean(item.Name)
        this.Available := true
        return this.Ordinals(items)
    }

    static AddHidden(items, flyout) {
        if !flyout
            return
        for element in flyout.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, this.AppIconId)
            items.Push({Name: element.Name, Kind: "app", Hidden: true})
    }

    ; The live element for item inside scopeRoot: same Name, the Ordinal-th one.
    static Nth(scopeRoot, item) {
        kindId := item.Kind = "system" ? this.SystemIconId : this.AppIconId
        seen := 0
        for element in scopeRoot.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, kindId)
            if element.Name == item.Name && ++seen = item.Ordinal
                return element
        return ""
    }

    static Missing() {
        ToolTip("Tray icon not found")
        SetTimer(() => ToolTip(), -1000)
    }

    ; Left-click: Invoke. A hidden icon is clicked inside the invisible flyout, which
    ; closes again afterwards.
    static Click(item) {
        if !(root := this.Root())
            return this.Missing()
        if !item.Hidden
            return (element := this.Nth(root, item)) ? element.Invoke() : this.Missing()
        this.WithFlyout(root, flyout => this.InvokeIn(flyout, item))
    }

    static InvokeIn(flyout, item) {
        if flyout && (element := this.Nth(flyout, item))
            return element.Invoke()
        this.Missing()
    }

    ; Context menu: focus the icon and press Shift+F10. A hidden icon's flyout opens
    ; visibly and stays open under the menu (it closes when the menu does).
    static Menu(item) {
        if !(root := this.Root())
            return this.Missing()
        scopeRoot := root
        if item.Hidden {
            if !(scopeRoot := this.Flyout()) {
                chevron := this.Chevron(root)
                scopeRoot := chevron ? this.OpenFlyout(chevron) : ""
            }
        }
        if !scopeRoot || !(element := this.Nth(scopeRoot, item))
            return this.Missing()
        element.SetFocus()
        Sleep(50)
        SendInput("+{F10}")
    }

    ; NotifyIconSettings entries: {Exe, Tip}; known-folder GUIDs in paths expanded.
    static Entries() {
        entries := []
        loop reg, "HKCU\Control Panel\NotifyIconSettings", "K" {
            subKey := A_LoopRegKey "\" A_LoopRegName
            exe := "", tip := ""
            try exe := RegRead(subKey, "ExecutablePath")
            try tip := RegRead(subKey, "InitialTooltip")
            if exe != ""
                entries.Push({Exe: this.ExpandKnownFolder(exe), Tip: tip})
        }
        return entries
    }

    static ExpandKnownFolder(path) {
        if !RegExMatch(path, "^(\{[0-9A-Fa-f-]{36}\})(.*)$", &found)
            return path
        guid := Buffer(16)
        if DllCall("ole32\CLSIDFromString", "Str", found[1], "Ptr", guid) != 0
            return path
        folder := 0
        if DllCall("shell32\SHGetKnownFolderPath", "Ptr", guid, "UInt", 0, "Ptr", 0, "Ptr*", &folder) != 0
            return path
        expanded := StrGet(folder, "UTF-16") found[2]
        DllCall("ole32\CoTaskMemFree", "Ptr", folder)
        return expanded
    }

    static FreeIcons() {
        for , icon in this.Icons
            DllCall("DestroyIcon", "Ptr", icon)
        this.Icons := Map()
    }

    ; Picker rows: visible apps, hidden apps, then system icons.
    static Rows() {
        this.FreeIcons()
        entries := this.Entries()
        groups := [[], [], []]
        for item in this.List() {
            entry := item.Kind = "app" ? this.Match(item.Name, entries) : ""
            text := item.Text != "" ? item.Text : entry ? this.ExeName(entry.Exe) : "(no name)"
            detail := item.Kind = "system" ? "system" : entry ? this.ExeName(entry.Exe) : ""
            if item.Hidden
                detail .= (detail != "" ? " · " : "") "hidden"
            icon := 0
            if entry && FileExist(entry.Exe) {
                try icon := LoadPicture(entry.Exe, "Icon1 w32 h32", &imageType)
                if icon
                    this.Icons[this.Icons.Count + 1] := icon
            }
            groups[item.Kind = "system" ? 3 : item.Hidden ? 2 : 1].Push({Text: text, Detail: detail, Icon: icon, Data: item})
        }
        rows := []
        for group in groups
            rows.Push(group*)
        if IsObject(this.PickerObject)
            this.PickerObject.EmptyText := this.Available ? "No tray icons" : "Tray not available on this Windows version"
        return rows
    }

    ; A picker over the tray: Enter or a letter left-clicks, Shift+Enter opens the
    ; context menu. options: Match, Reference, Density (passed to Legend.Picker).
    static Picker(hotkey, options := "") {
        opt := (name, fallback) => IsObject(options) && options.HasOwnProp(name) ? options.%name% : fallback
        return this.PickerObject := Legend.Picker(hotkey, "Tray", (*) => LegendTray.Rows(), {
            OnPick: row => (LegendTray.FreeIcons(), LegendTray.Click(row.Data)),
            OnAltPick: row => (LegendTray.FreeIcons(), LegendTray.Menu(row.Data)),
            OnCancel: () => LegendTray.FreeIcons(),
            AltPickLabel: "menu",
            EmptyText: "No tray icons",   ; Rows() switches it when the tray can't be read
            Match: opt("Match", ""), Reference: opt("Reference", true), Density: opt("Density", "")})
    }
}
