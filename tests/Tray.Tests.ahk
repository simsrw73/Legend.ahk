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
        T.Eq(root.Hwnd, g.Hwnd, "native window handle")
        top := LegendUIA.Root().FindFirst(LegendUIA.Children, LegendUIA.NameProperty, "LegendUIATest")
        T.True(IsObject(top) && top.Hwnd = g.Hwnd, "found from the desktop root")
    } finally
        g.Destroy()
}

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
        T.True(item.HasOwnProp("Ordinal") && item.HasOwnProp("Index") && (item.Kind = "app" || item.Kind = "system"), item.Text)
    T.True(!LegendTray.FlyoutOpen(), "flyout closed again")
    chevron := LegendTray.Chevron(LegendTray.Root())
    if chevron
        for item in items
            T.True(item.Kind = "app" || item.Name != chevron.Name, "the Show Hidden Icons button is not an icon")
}

; Stand-ins for UI Automation elements and scopes.
class Tray_FakeElement {
    __New(name, x := 0) {
        this.Name := name
        this.Rect := {X: x, Y: 0, W: 10, H: 10}
    }
    Invoke() => ""
}
class Tray_FakeScope {
    __New(elements) => this.Elements := elements
    FindAll(scope, property, value) => this.Elements
}
class Tray_ThrowingRoot {
    FindAll(scope, property, value) {
        throw OSError("element not available")
    }
}

T.Test("Tray: a COM error while reading gives not available, not an error", Tray_ComError)
Tray_ComError() {
    saved := LegendTray.GetOwnPropDesc("Root")
    LegendTray.DefineProp("Root", {Call: (*) => Tray_ThrowingRoot()})
    try {
        T.Eq(LegendTray.List().Length, 0)
        T.True(!LegendTray.Available)
        icon := {Name: "x", Kind: "app", Hidden: false, Ordinal: 1, Index: 1}
        LegendTray.Click(icon)   ; must not throw
        LegendTray.Menu(icon)
    } finally {
        LegendTray.DefineProp("Root", saved)
        LegendTray.Available := true
        ToolTip()
    }
}

T.Test("Tray: an icon whose tooltip changed is still found by its place", Tray_NthChangedName)
Tray_NthChangedName() {
    scope := Tray_FakeScope([Tray_FakeElement("Privacy"), Tray_FakeElement("Clock 10:42"), Tray_FakeElement("Volume 10%")])
    clock := {Name: "Clock 10:41", Kind: "system", Hidden: false, Ordinal: 1, Index: 2}
    T.Eq(LegendTray.Nth(scope, clock).Name, "Clock 10:42")
    other := {Name: "Battery 50%", Kind: "system", Hidden: false, Ordinal: 1, Index: 2}
    T.Eq(LegendTray.Nth(scope, other), "", "a different icon in that place is not a match")
    exact := {Name: "Volume 10%", Kind: "system", Hidden: false, Ordinal: 1, Index: 1}
    T.Eq(LegendTray.Nth(scope, exact).Name, "Volume 10%", "an exact name wins over the place")
}

T.Test("Tray: the flyout closes before it is made visible again", Tray_CloseBeforeUnhide)
Tray_CloseBeforeUnhide() {
    calls := [], isOpen := false
    chevron := {Invoke: (*) => (calls.Push(isOpen ? "close" : "open"), isOpen := !isOpen)}
    flyout := {Hwnd: 123}
    names := ["Flyout", "Chevron", "Hide", "Unhide"]
    saved := Map()
    for name in names
        saved[name] := LegendTray.GetOwnPropDesc(name)
    LegendTray.DefineProp("Flyout", {Call: (*) => isOpen ? flyout : ""})
    LegendTray.DefineProp("Chevron", {Call: (*) => chevron})
    LegendTray.DefineProp("Hide", {Call: (*) => (calls.Push("hide"), {})})
    LegendTray.DefineProp("Unhide", {Call: (*) => calls.Push(isOpen ? "unhide while open" : "unhide")})
    try {
        LegendTray.WithFlyout({}, found => calls.Push("read"))
        text := ""
        for call in calls
            text .= (A_Index > 1 ? ", " : "") call
        T.Eq(text, "open, hide, read, close, unhide")
    } finally {
        for name in names
            LegendTray.DefineProp(name, saved[name])
    }
}

T.Test("Tray: hiding a window that was already layered restores its transparency", Tray_HideRestoresAlpha)
Tray_HideRestoresAlpha() {
    g := Gui("-Caption +ToolWindow +E0x08000000")
    g.Show("NA x-3000 y-3000 w20 h20")
    WinSetTransparent(200, g)
    try {
        LegendTray.Unhide(g.Hwnd, LegendTray.Hide(g.Hwnd))
        key := 0, alpha := 0, flags := 0
        DllCall("GetLayeredWindowAttributes", "Ptr", g.Hwnd, "UInt*", &key, "UChar*", &alpha, "UInt*", &flags)
        T.Eq(alpha, 200)
    } finally
        g.Destroy()
}

T.Test("Tray: a tooltip prefix must end where a word ends", Tray_MatchTipWord)
Tray_MatchTipWord() {
    entries := [{Exe: "C:\x\Ever.exe", Tip: "Ever"}]
    T.Eq(LegendTray.Match("Everything", entries), "")
    T.Eq(LegendTray.Match("Ever 2.0", entries).Tip, "Ever")
}
