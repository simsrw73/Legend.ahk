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
