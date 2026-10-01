# Legend Tray Picker (extra) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An opt-in extra, `extras/Tray.ahk`, whose `LegendTray.Picker(hotkey)` lists every tray icon (visible, hidden, system) in a Legend picker; Enter or a letter left-clicks, Shift+Enter opens the icon's context menu.

**Architecture:** Core `LegendPicker` gains a generic alternate pick (`OnAltPick`, Shift+Enter). `extras/Tray.ahk` holds a minimal UI Automation COM wrapper (`LegendUIA`, `LegendUIAElement`) and `LegendTray`, which reads `Shell_TrayWnd` and the overflow flyout, re-finds icons by name + hidden + ordinal, and acts by Invoke or SetFocus + Shift+F10; pure helpers (`Clean`, `Match`, `Ordinals`, known-folder expansion) are unit-tested; icons come from best-effort matches against `HKCU\Control Panel\NotifyIconSettings`.

**Tech Stack:** AutoHotkey v2.0, UI Automation via `ComCall` (no external libraries), PowerShell 7 test runner.

**Spec:** `docs/specs/2026-10-01-tray-picker-design.md`

## Global Constraints

- `#Requires AutoHotkey v2.0`; classes start with `Legend`; **no external libraries**.
- `extras/Tray.ahk` is never included by `Legend.ahk`; hosts include it after `Legend.ahk`.
- Every Windows-specific name lives in constants at the top of `extras/Tray.ahk`: `Shell_TrayWnd`, `TopLevelWindowForOverflowXamlIsland`, `NotifyItemIcon`, `SystemTrayIcon`.
- When the tray can't be read: `LegendTray.Available := false`, `List()` returns `[]`, the picker shows `Tray not available on this Windows version`; never an error dialog.
- UIA constants: CLSID_CUIAutomation `{ff48dba4-60ef-4201-aa87-54103eef594e}`, IID_IUIAutomation `{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}`; property ids Name 30005, AutomationId 30011, ClassName 30012; Invoke pattern 10000; TreeScope Children 2, Descendants 4. Vtable slots: IUIAutomation ElementFromHandle 6, CreatePropertyCondition 23; IUIAutomationElement SetFocus 3, FindFirst 5, FindAll 6, GetCurrentPattern 16, get_CurrentName 23, get_CurrentAutomationId 29, get_CurrentClassName 30, get_CurrentBoundingRectangle 43; IUIAutomationElementArray get_Length 3, GetElement 4; IUIAutomationInvokePattern Invoke 3.
- Locals must not shadow built-ins or WarnHost globals (`a`–`z`, `id`, `fn`, `app`, `pad`, `out`, `ch`, `vk`, `sc`, `cx`, `cy`, `wx`, `wy`, `ww`, `wh`, `lh`, `th`, `ty`, `bgr`, `rgb`, `ih`).
- **Never launch AutoHotkey from the Bash tool.** Tests: `pwsh -NoProfile -File tests/Run-Tests.ps1` from PowerShell.
- Commits GPG-signed (on timeout ask for `! 'unlock' | gpg --clearsign | Out-Null`); messages end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01EGM256u2YUxjGNbwDZaxaK`.
- Branch `tray` in `C:\Users\simsr\projects\Legend`. Pushes only at the end, as the user asked earlier to push all changes.

## Review Focus

1. The flyout must be closed again after listing and after a left-click on a hidden icon, and left as found when it was already open. Task 4 `Tray_FlyoutRestored` (live, skips without a tray).
2. A Windows build without the tray layout (or Windows 10) must give the "not available" row, not a COM error. Task 4 `Tray_Unavailable` forces it by pointing the constants at a missing class.
3. Two icons with the same tooltip (CrystalDiskInfo shows several) must each be reachable. Task 2 `Tray_Ordinals`.
4. A name that matches no NotifyIconSettings entry must get no icon, never a wrong one. Task 2 `Tray_MatchNone`.
5. Shift+Enter in a picker without `OnAltPick` must do nothing (not pick). Task 1 `Picker_AltPickOff`.

---

### Task 0: Spike — chevron identity and an invisible flyout

Throwaway (scratch scripts only). Answers two questions the code depends on; record the answers in the ledger and in Task 4's constants.

- [ ] **Step 1: Chevron identity.** PowerShell UIA script (as in the earlier spike): list every `SystemTrayIcon` element of `Shell_TrayWnd` with Name, ClassName and BoundingRectangle, in tree order. Expected: the "Show Hidden Icons" button is the first `SystemTrayIcon` (before the first `NotifyItemIcon`). Decide the locale-independent rule: **the `SystemTrayIcon` element that comes before the first `NotifyItemIcon` in tree order** (if confirmed), else match Name `Show Hidden Icons` and document the English-only limit.
- [ ] **Step 2: Invisible flyout.** AHK scratch script: Invoke the chevron, poll every 5 ms (max 1 s) for `ahk_class TopLevelWindowForOverflowXamlIsland` and `WinSetTransparent(0)` on it as soon as it exists; then FindAll `NotifyItemIcon` in it and count; Invoke the chevron again; `WinSetTransparent("Off")`. Ask the user to watch the taskbar corner while it runs three times. Record: count matches the visible-flyout count (37 on the author's machine) and whether the user saw a flash.
- [ ] **Step 3: Record** in the ledger: `Task 0: chevron rule = …; transparent flyout = works/doesn't (flash seen: yes/no)`.

---

### Task 1: Alternate pick in the picker (core)

**Files:** Modify `src/Picker.ahk`, `Legend.ahk` (`DrainPickerKeys`); Test `tests/Picker.Tests.ahk`

**Interfaces:**
- Produces: options `OnAltPick` (function or `""`), `AltPickLabel` (default `"alt"`); `Key` returns `"altpick"`; `KeyBatch` ends on it; footer part `⇧↵ <label>` right after `↵ pick`.

- [ ] **Step 1: Branch** — `cd /c/Users/simsr/projects/Legend && git checkout -b tray`
- [ ] **Step 2: Failing tests** (append to `tests/Picker.Tests.ahk`):

```ahk
T.Test("Picker: Shift+Enter alt-picks only with OnAltPick", Picker_AltPick)
Picker_AltPick() {
    p := Picker_New(3, {OnAltPick: Noop, AltPickLabel: "menu"})
    T.Eq(p.Key(Picker_Key("Shift+Enter")), "altpick")
    p.Key(Picker_Key("/"))
    T.Eq(p.Key(Picker_Key("Shift+Enter")), "altpick", "also while filtering")
    T.Eq(p.KeyBatch([Picker_Key("Shift+Enter"), Picker_Key("j")]).Action, "altpick")
    T.True(InStr(Picker_New(3, {OnAltPick: Noop, AltPickLabel: "menu"}).Footer("compact"), "↵ pick   ·   ⇧↵ menu   ·   ^n/^p move"))
}

T.Test("Picker: Shift+Enter does nothing without OnAltPick", Picker_AltPickOff)
Picker_AltPickOff() {
    p := Picker_New(3)
    T.Eq(p.Key(Picker_Key("Shift+Enter")), "none")
    T.True(!InStr(p.Footer("compact"), "⇧↵"))
    empty := Picker_New(0, {OnAltPick: Noop})
    T.Eq(empty.Key(Picker_Key("Shift+Enter")), "none", "nothing selected")
}
```

- [ ] **Step 3: Run; expect FAIL** (`"none"` instead of `"altpick"`).
- [ ] **Step 4: Implement**
  - Constructor, after `this.OnCancel := opt("OnCancel", "")`:
    ```ahk
            this.OnAltPick := opt("OnAltPick", "")
            this.AltPickLabel := opt("AltPickLabel", "alt")
    ```
  - In both `Key`'s normal-mode switch and `FilterKey`'s switch, right after the `case "Enter"` line:
    ```ahk
                case "Shift+Enter": return IsObject(this.OnAltPick) && this.Cursor ? "altpick" : "none"
    ```
  - `KeyBatch`: `case "pick", "cancel":` → `case "pick", "altpick", "cancel":`.
  - `Footer`: `parts := ["↵ pick", "^n/^p move"]` →
    ```ahk
            parts := ["↵ pick"]
            if IsObject(this.OnAltPick)
                parts.Push("⇧↵ " this.AltPickLabel)
            parts.Push("^n/^p move")
    ```
  - `Legend.ahk` `DrainPickerKeys`, after the `case "pick":` block:
    ```ahk
                case "altpick":
                    item := picker.Selected
                    this.ClosePickerNow(false)
                    onAltPick := picker.OnAltPick
                    this.Defer(() => onAltPick(item))
    ```
- [ ] **Step 5: Run; expect PASS.** Add one sentence to README's Pickers paragraph: "`OnAltPick` (with `AltPickLabel`) adds a second action on Shift+Enter."
- [ ] **Step 6: Commit** "Picker: an alternate pick on Shift+Enter".

---

### Task 2: Tray helpers (pure)

**Files:** Create `extras/Tray.ahk` (constants + `LegendTray` static helpers only), `tests/Tray.Tests.ahk`; Modify `tests/Legend.Tests.ahk`, `tests/Run-Tests.ps1` (validate `extras\*.ahk`)

**Interfaces:**
- Produces: `LegendTray.Clean(name) → string`; `LegendTray.Ordinals(items)` sets `.Ordinal` on `{Name, Hidden}` items (1-based per Name+Hidden); `LegendTray.Match(name, entries) → entry | ""` with entries `[{Exe, Tip}]`; `LegendTray.ExeName(path) → base name without .exe`.

- [ ] **Step 1: Failing tests** — create `tests/Tray.Tests.ahk`:

```ahk
#Requires AutoHotkey v2.0

T.Test("Tray: Clean keeps the first non-empty line, trimmed", Tray_Clean)
Tray_Clean() {
    T.Eq(LegendTray.Clean("Network 1736Strtfrd`r`nInternet access"), "Network 1736Strtfrd")
    T.Eq(LegendTray.Clean("  `n  KeyCombiner  "), "KeyCombiner")
    T.Eq(LegendTray.Clean(""), "")
    T.Eq(LegendTray.Clean(" Spark   Desktop "), "Spark Desktop", "inner runs of spaces collapse")
}

T.Test("Tray: icons with the same name are numbered", Tray_Ordinals)
Tray_Ordinals() {
    items := [{Name: "CrystalDiskInfo", Hidden: true}, {Name: "Everything", Hidden: true},
              {Name: "CrystalDiskInfo", Hidden: true}, {Name: "CrystalDiskInfo", Hidden: false}]
    LegendTray.Ordinals(items)
    T.Eq(items[1].Ordinal " " items[2].Ordinal " " items[3].Ordinal " " items[4].Ordinal, "1 1 2 1")
}

Tray_Entries() => [{Exe: "C:\Tools\Everything\Everything.exe", Tip: ""},
                   {Exe: "C:\Tools\DiskInfo64.exe", Tip: "CrystalDiskInfo"},
                   {Exe: "C:\Tools\PowerToys.exe", Tip: ""},
                   {Exe: "C:\Old\Ever.exe", Tip: ""}]

T.Test("Tray: Match by tooltip or by the app's name at the start", Tray_Match)
Tray_Match() {
    entries := Tray_Entries()
    T.Eq(LegendTray.Match("Everything", entries).Exe, "C:\Tools\Everything\Everything.exe")
    T.Eq(LegendTray.Match("CrystalDiskInfo_ 1 (1) Samsung SSD", entries).Exe, "C:\Tools\DiskInfo64.exe", "tooltip prefix")
    T.Eq(LegendTray.Match("PowerToys v0.101.2362", entries).Exe, "C:\Tools\PowerToys.exe", "exe name as first word")
    T.Eq(LegendTray.ExeName("C:\Tools\PowerToys.exe"), "PowerToys")
}

T.Test("Tray: no confident match, no icon", Tray_MatchNone)
Tray_MatchNone() {
    entries := Tray_Entries()
    T.Eq(LegendTray.Match("Everythingness", entries), "", "a word must end where the exe name ends")
    T.Eq(LegendTray.Match("Sign in to Blip", entries), "")
    T.Eq(LegendTray.Match("", entries), "")
}
```

In `tests/Legend.Tests.ahk`, before the `#Include …\Legend.ahk` line near the end:

```ahk
#Include %A_ScriptDir%\..\extras\Tray.ahk
#Include %A_ScriptDir%\Tray.Tests.ahk
```

In `tests/Run-Tests.ps1`, extend the validate list with the extras:

```powershell
foreach ($file in @('Legend.ahk') + (Get-ChildItem (Join-Path $root 'examples') -Filter *.ahk | ForEach-Object { "examples\$($_.Name)" }) + (Get-ChildItem (Join-Path $root 'extras') -Filter *.ahk | ForEach-Object { "extras\$($_.Name)" })) {
```

(`extras\Tray.ahk` validates on its own because it starts with `#Include %A_LineFile%\..\..\Legend.ahk` — AHK skips a file included twice.)

- [ ] **Step 2: Run; expect FAIL** (`extras\Tray.ahk` cannot be opened).
- [ ] **Step 3: Implement** — create `extras/Tray.ahk`:

```ahk
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
```

- [ ] **Step 4: Run; expect PASS** (and `validate extras\Tray.ahk ok`).
- [ ] **Step 5: Commit** "Tray extra: name cleaning, ordinals, app matching".

---

### Task 3: LegendUIA — minimal UI Automation over COM

**Files:** Modify `extras/Tray.ahk`; Test `tests/Tray.Tests.ahk`

**Interfaces:**
- Produces: `LegendUIA.Instance` (lazy `IUIAutomation` ComValue); `LegendUIA.FromHandle(hwnd) → LegendUIAElement | ""`; `LegendUIAElement` with `.Name`, `.AutomationId`, `.ClassName`, `.Rect` (`{X, Y, W, H}`), `.FindAll(scope, propertyId, value) → [LegendUIAElement]`, `.FindFirst(scope, propertyId, value) → LegendUIAElement | ""`, `.Invoke()`, `.SetFocus()`; elements release their COM pointer on `__Delete`.

- [ ] **Step 1: Failing test** (append to `tests/Tray.Tests.ahk`):

```ahk
T.Test("Tray: UI Automation reads a window's elements", Tray_UIA)
Tray_UIA() {
    g := Gui("-Caption +ToolWindow +E0x08000000", "LegendUIATest")
    g.AddButton("vProbe w80", "Probe button")
    g.Show("NA x-3000 y-3000")
    try {
        root := LegendUIA.FromHandle(g.Hwnd)
        T.True(IsObject(root), "element from handle")
        buttons := root.FindAll(LegendUIA.Descendants, LegendUIA.NameProperty, "Probe button")
        T.Eq(buttons.Length, 1)
        T.Eq(buttons[1].Name, "Probe button")
        T.True(buttons[1].Rect.W > 0)
        T.Eq(root.FindFirst(LegendUIA.Descendants, LegendUIA.NameProperty, "missing"), "")
    } finally
        g.Destroy()
}
```

- [ ] **Step 2: Run; expect FAIL** (`LegendUIA` undefined).
- [ ] **Step 3: Implement** — add to `extras/Tray.ahk` before `class LegendTray`:

```ahk
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
```

- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** "Tray extra: minimal UI Automation over COM".

---

### Task 4: LegendTray — list, click, menu, picker

**Files:** Modify `extras/Tray.ahk`; Test `tests/Tray.Tests.ahk`

**Interfaces:**
- Consumes: Task 0 chevron rule and transparency result; Task 1 `OnAltPick`; Task 2 helpers; Task 3 `LegendUIA`.
- Produces: `LegendTray.List() → [{Name, Text, Kind, Hidden, Ordinal}]`; `LegendTray.Click(item)`; `LegendTray.Menu(item)`; `LegendTray.Entries() → [{Exe, Tip}]`; `LegendTray.Picker(hotkey, options?) → LegendPicker`.

- [ ] **Step 1: Failing tests** (append to `tests/Tray.Tests.ahk`):

```ahk
T.Test("Tray: an unknown tray layout reads as not available", Tray_Unavailable)
Tray_Unavailable() {
    saved := LegendTray.TrayClass
    LegendTray.TrayClass := "NoSuchTrayClass"
    try {
        T.Eq(LegendTray.List().Length, 0)
        T.True(!LegendTray.Available)
    } finally
        LegendTray.TrayClass := saved, LegendTray.Available := true
}

T.Test("Tray: listing leaves the flyout as it found it", Tray_FlyoutRestored)
Tray_FlyoutRestored() {
    if !WinExist("ahk_class " LegendTray.TrayClass)
        return T.Out("skip Tray_FlyoutRestored: no Windows 11 tray")
    items := LegendTray.List()
    if !LegendTray.Available
        return T.Out("skip Tray_FlyoutRestored: tray layout not recognized")
    T.True(items.Length > 0, "at least one tray icon")
    for item in items
        T.True(item.HasOwnProp("Ordinal") && (item.Kind = "app" || item.Kind = "system"), item.Text)
    T.True(!LegendTray.FlyoutOpen(), "flyout closed again")
}
```

- [ ] **Step 2: Run; expect FAIL** (`List` undefined).
- [ ] **Step 3: Implement** — add to `class LegendTray` (apply Task 0's chevron rule in `Chevron`; if Task 0 found transparency doesn't work, drop the two `WinSetTransparent` lines and record the ruling):

```ahk
    static Icons := Map()   ; icons Legend extracted for the open picker
    static PickerObject := ""   ; the picker Picker() created, for its EmptyText

    static FlyoutOpen() {
        wasDetecting := DetectHiddenWindows(false)
        try
            return WinExist("ahk_class " this.OverflowClass) != 0
        finally
            DetectHiddenWindows(wasDetecting)
    }

    static Root() {
        hwnd := WinExist("ahk_class " this.TrayClass)
        return hwnd ? LegendUIA.FromHandle(hwnd) : ""
    }

    ; The "Show Hidden Icons" button: the system icon before the first app icon
    ; in tree order (Task 0), else "".
    static Chevron(root) {
        for element in root.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, this.SystemIconId)
            return element
        return ""
    }

    ; Opens the flyout (transparent while Legend uses it), runs fn(flyoutRoot),
    ; and closes it again unless it was already open.
    static WithFlyout(root, fn) {
        wasOpen := this.FlyoutOpen()
        chevron := this.Chevron(root)
        if !wasOpen {
            if !chevron
                return fn("")
            chevron.Invoke()
            deadline := A_TickCount + 1000
            while !this.FlyoutOpen() && A_TickCount < deadline
                Sleep(5)
            if hwnd := WinExist("ahk_class " this.OverflowClass)
                WinSetTransparent(0, "ahk_id " hwnd)
        }
        try {
            flyout := WinExist("ahk_class " this.OverflowClass)
            return fn(flyout ? LegendUIA.FromHandle(flyout) : "")
        } finally {
            if !wasOpen && this.FlyoutOpen() {
                if hwnd := WinExist("ahk_class " this.OverflowClass)
                    WinSetTransparent("Off", "ahk_id " hwnd)
                if chevron
                    chevron.Invoke()
            }
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
        system := root.FindAll(LegendUIA.Descendants, LegendUIA.AutomationIdProperty, this.SystemIconId)
        for element in system
            if A_Index > 1   ; the first is the chevron (Task 0)
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

    ; The live element for item (opening the flyout for hidden ones), passed to fn.
    static WithElement(item, fn) {
        if !(root := this.Root())
            return this.Missing()
        find := scopeRoot => this.Nth(scopeRoot, item)
        if !item.Hidden {
            element := find(root)
            return element ? fn(element) : this.Missing()
        }
        return this.WithFlyout(root, flyout => (element := flyout ? find(flyout) : "") ? fn(element) : this.Missing())
    }

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

    static Click(item) => this.WithElement(item, element => element.Invoke())

    ; Context menu: focus the icon and press Shift+F10. For a hidden icon the flyout
    ; must stay open under the menu, so this one does not go through WithFlyout's close.
    static Menu(item) {
        if !(root := this.Root())
            return this.Missing()
        if item.Hidden && !this.FlyoutOpen() {
            if !(chevron := this.Chevron(root))
                return this.Missing()
            chevron.Invoke()
            deadline := A_TickCount + 1000
            while !this.FlyoutOpen() && A_TickCount < deadline
                Sleep(5)
        }
        scopeRoot := item.Hidden ? LegendUIA.FromHandle(WinExist("ahk_class " this.OverflowClass)) : root
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

    static Rows() {
        this.FreeIcons()
        entries := this.Entries()
        groups := [[], [], []]   ; visible apps, hidden apps, system
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
            row := {Text: text, Detail: detail, Icon: icon, Data: item}
            groups[item.Kind = "system" ? 3 : item.Hidden ? 2 : 1].Push(row)
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
```

- [ ] **Step 4: Run; expect PASS** (the live test passes on the author's machine, skips elsewhere).
- [ ] **Step 5: Live check (PowerShell, scratch):** a script including `extras\Tray.ahk` that prints `List()` (Text · Kind · Hidden · Ordinal) and `Rows()` (Text · Detail · has icon) — expected: the visible, hidden and system icons from the spike; Everything, TickTick, PowerToys, CrystalDiskInfo with icons; Docker/Blip-style names without.
- [ ] **Step 6: Commit** "Tray extra: list, click, context menu and the picker".

---

### Task 5: Example, docs, finish

**Files:** Create `examples/07-tray-picker.ahk`; Modify `README.md`, `TODO.md`

- [ ] **Step 1: Example** — `examples/07-tray-picker.ahk`:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\..\Legend.ahk
#Include %A_LineFile%\..\..\extras\Tray.ahk

; 07 · Tray picker (extra, may break with Windows updates)
;
; Shows: LegendTray.Picker, every notification-area icon (visible, hidden in the
; "Show hidden icons" flyout, and system icons) in a picker. It reads Windows 11's
; taskbar through UI Automation; on other Windows versions it says the tray is
; not available.
;
; Keys: Ctrl+Alt+Shift+T opens it. Enter or a letter left-clicks the icon,
;   Shift+Enter opens its context menu, / filters, Ctrl+N/P move, Esc cancels.
;   Ctrl+Alt+Shift+/ opens the overlay.
;
; Run it with AutoHotkey v2; exit from its tray icon.

LegendTray.Picker("^!+t")

Legend.Start({HelpKey: "^!+/"})
```

- [ ] **Step 2: README** — add the example to the Examples table, and a section before "## Development":

```markdown
## Extras (may break with Windows updates)

Opt-in features that depend on how Windows builds its own UI. They are not
loaded by `Legend.ahk`; include them yourself after it.

**Tray picker** (`extras/Tray.ahk`): `LegendTray.Picker("!t")` lists every
notification-area icon — visible, hidden in the "Show hidden icons" flyout, and
system icons — in a picker. Enter or a letter left-clicks the icon, Shift+Enter
opens its context menu. It reads Windows 11's taskbar through UI Automation
(tested on build 26220); hidden icons are read by opening the flyout invisibly
for a moment. Icons are matched to apps through Windows' NotifyIconSettings list
when the match is certain. If Windows changes the taskbar, the picker shows
"Tray not available on this Windows version" instead of failing.
```

- [ ] **Step 3: TODO.md** — remove the systray item. Run the tests, commit "Tray extra: example and docs".
- [ ] **Step 4: Hand check (user):** run `examples\07-tray-picker.ahk`; Ctrl+Alt+Shift+T: list, a visible icon (Enter), a hidden icon (Enter), a context menu (Shift+Enter on Everything and on TickTick), filter, the flyout flash.
- [ ] **Step 5: Final review** (fresh reviewer, whole branch); fix Critical/Important RED→GREEN.
- [ ] **Step 6: Merge** `tray` into `main`, run the tests, push Legend; bump the dotfiles' and the mirror's Legend submodule (no binding there unless the user asks), validate, commit, push.
