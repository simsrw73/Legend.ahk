#Requires AutoHotkey v2.0

; A registry whose binder records calls instead of creating hotkeys.
Registry_New() {
    r := LegendRegistry()
    r.BindLog := []
    calls := r.BindLog
    r.Binder := (hotkey, fn, match) => calls.Push({Hotkey: hotkey, Match: match})
    return r
}

Registry_AllEntries(page) {
    out := []
    for c in page.Categories
        for g in c.Groups
            for e in g.Entries
                out.Push(e)
    return out
}

T.Test("Registry: Page() returns one object per title", Registry_PageIdentity)
Registry_PageIdentity() {
    r := Registry_New()
    T.Eq(ObjPtr(r.Page("komorebi")), ObjPtr(r.Page("KOMOREBI")))
    T.Eq(r.Pages.Length, 1)
}

T.Test("Registry: table rows bind with the page's code match", Registry_TableBind)
Registry_TableBind() {
    r := Registry_New()
    r.Page("Zen", "ahk_exe zen.exe").Category("Tabs", [["#+o", "open in Chrome", Noop]])
    T.Eq(r.BindLog.Length, 1)
    T.Eq(r.BindLog[1].Hotkey, "#+o")
    T.Eq(r.BindLog[1].Match, "ahk_exe zen.exe")
    e := Registry_AllEntries(r.Page("Zen"))[1]
    T.True(e.Bound)
    T.Eq(e.Key.Id, "Win+Shift+O")
    T.Eq(e.Description, "open in Chrome")
}

T.Test("Registry: one-line Bind with a group path", Registry_PathBind)
Registry_PathBind() {
    r := Registry_New()
    r.Bind(["komorebi", "Workspaces", "Focus"], "!1", "focus dev", Noop)
    page := r.Page("komorebi")
    T.Eq(page.Categories[1].Name, "Workspaces")
    T.Eq(page.Categories[1].Groups[1].Name, "Focus")
    T.Eq(r.BindLog[1].Match, "")
    T.Throws(() => r.Bind(["komorebi"], "!2", "x", Noop), "short path")
}

T.Test("Registry: category Bind chains", Registry_Chain)
Registry_Chain() {
    r := Registry_New()
    r.Page("p").Category("c").Bind("^a", "a", Noop).Bind("^b", "b", Noop)
    T.Eq(Registry_AllEntries(r.Page("p")).Length, 2)
}

T.Test("Registry: row options are stored", Registry_Options)
Registry_Options() {
    r := Registry_New()
    r.Page("p").Category("c", [["!h", "left", Noop, {Row: "Alt+H/L", Text: "focus"}]])
    e := Registry_AllEntries(r.Page("p"))[1]
    T.Eq(e.Row, "Alt+H/L")
    T.Eq(e.Text, "focus")
}

T.Test("Registry: doc then bind merges into one bound entry", Registry_DocThenBind)
Registry_DocThenBind() {
    r := Registry_New()
    r.Doc(["Zen", "Tabs"], "Win+Shift+O", "open in Chrome")
    r.Page("Zen").Category("Other", [["#+o", "x", Noop]])
    entries := Registry_AllEntries(r.Page("Zen"))
    T.Eq(entries.Length, 1)
    T.True(entries[1].Bound)
    T.Eq(entries[1].Description, "open in Chrome")
    T.Eq(r.Page("Zen").Categories[1].Name, "Tabs")
}

T.Test("Registry: bind then file doc keeps the bound entry", Registry_BindThenFile)
Registry_BindThenFile() {
    r := Registry_New()
    r.Bind(["Zen", "Tabs"], "^t", "new tab", Noop)
    r.AddFile({Title: "Zen", Match: "", Letter: "", Entries: [
        {Category: "Tabs", Group: "", Key: LegendKeyName.FromText("Ctrl+T"), Description: "New tab (doc)"}]})
    entries := Registry_AllEntries(r.Page("Zen"))
    T.Eq(entries.Length, 1)
    T.True(entries[1].Bound)
    T.Eq(entries[1].Description, "new tab")
}

T.Test("Registry: verbatim keys never merge", Registry_Verbatim)
Registry_Verbatim() {
    r := Registry_New()
    r.Doc(["Zen", "Tabs"], "Ctrl+1–8", "go to tab")
    r.Doc(["Zen", "Tabs"], "Ctrl+1–8", "go to tab again")
    T.Eq(Registry_AllEntries(r.Page("Zen")).Length, 2)
}

T.Test("Registry: binding a key twice on a page warns", Registry_BoundTwice)
Registry_BoundTwice() {
    r := Registry_New()
    r.Bind(["p", "c"], "^a", "a", Noop)
    r.Bind(["p", "c"], "^a", "a again", Noop)
    T.Eq(r.Warnings.Length, 1)
    T.True(InStr(r.Warnings[1], "Ctrl+A"))
}

T.Test("Registry: code match overrides file match with one warning", Registry_Conflict)
Registry_Conflict() {
    r := Registry_New()
    r.Page("Zen", "ahk_exe zen.exe")
    r.AddFile({Title: "Zen", Match: "ahk_exe other.exe", Letter: "q", Entries: []})
    r.Page("Zen", "ahk_exe zen.exe")
    page := r.Page("Zen")
    T.Eq(page.Match, "ahk_exe zen.exe")
    T.Eq(page.Letter, "q")
    T.Eq(r.Warnings.Length, 1)
}

T.Test("Registry: a file-only match never conditions hotkeys", Registry_FileMatchNotHotIf)
Registry_FileMatchNotHotIf() {
    r := Registry_New()
    r.AddFile({Title: "Zen", Match: "ahk_exe zen.exe", Letter: "", Entries: []})
    r.Bind(["Zen", "Tabs"], "#+o", "x", Noop)
    T.Eq(r.BindLog[1].Match, "")
    T.Eq(r.Page("Zen").Match, "ahk_exe zen.exe")
}

T.Test("Registry: case-insensitive page and category merge", Registry_CaseInsensitiveMerge)
Registry_CaseInsensitiveMerge() {
    r := Registry_New()
    r.Bind(["Zen", "Tabs"], "^t", "new tab", Noop)
    r.AddFile({Title: "zen", Match: "", Letter: "", Entries: [
        {Category: "tabs", Group: "", Key: LegendKeyName.FromText("Ctrl+W"), Description: "close"}]})
    T.Eq(r.Pages.Length, 1)
    T.Eq(r.Page("Zen").Categories.Length, 1)
    T.Eq(Registry_AllEntries(r.Page("Zen")).Length, 2)
}

T.Test("Registry: the default binder registers real hotkeys", Registry_DefaultBinder)
Registry_DefaultBinder() {
    r := LegendRegistry()
    r.Bind(["p", "c"], "^!+F24", "global", Noop)
    r.Page("q", "ahk_exe legend-test-nothing.exe").Category("c", [["^!+F23", "conditional", Noop]])
    T.Eq(Registry_AllEntries(r.Page("p")).Length, 1)
    T.Eq(Registry_AllEntries(r.Page("q")).Length, 1)
}

T.Test("Registry: a global binding ignores the host's HotIf context", Registry_GlobalIgnoresHostHotIf)
Registry_GlobalIgnoresHostHotIf() {
    r := LegendRegistry()
    HotIfWinActive("ahk_exe legend-host-context.exe")
    r.Bind(["p", "c"], "^!+F22", "global", Noop)
    HotIfWinActive()
    T.Eq(Hotkey("^!+F22", "Off"), "", "exists with no condition")
}

Registry_LaunchChord(options := "") => LegendChord("#Space", "Launch", [
    LegendChordItem("z", "Zed", Noop),
    LegendChordItem("w", "Research", "", [LegendChordItem("b", "Brave", Noop)]),
    LegendChordItem("t", "Terminal", Noop, "", {If: () => false, Hint: "in Explorer"})
], options)

Registry_Keys(category) {
    out := ""
    for e in category.Groups[1].Entries
        out .= LegendKeyName.Format(e.Key, "text") "=" e.Description ";"
    return out
}

T.Test("Registry: chord reference pages follow the tree", Registry_ChordPage)
Registry_ChordPage() {
    r := Registry_New()
    r.AddChord(Registry_LaunchChord({Match: "ahk_exe x.exe"}), Noop)
    T.Eq(r.BindLog[1].Hotkey, "#Space")
    T.Eq(r.BindLog[1].Match, "ahk_exe x.exe")
    T.Eq(r.SortedPages().Length, 0, "no pages before enabling")
    r.EnableChordReference(true)
    page := r.Page("Launch")
    T.Eq(page.Match, "ahk_exe x.exe")
    T.Eq(page.Categories[1].Name, "Launch")
    T.Eq(page.Categories[2].Name, "Launch › Research")
    T.Eq(Registry_Keys(page.Categories[1]),
        "Win+Space z=Zed;Win+Space w=Research ›;Win+Space t=Terminal (in Explorer);")
    T.Eq(Registry_Keys(page.Categories[2]), "Win+Space w b=Brave;")
    T.True(page.Categories[1].Groups[1].Entries[1].Bound)
}

T.Test("Registry: hidden chords make no pages", Registry_ChordHidden)
Registry_ChordHidden() {
    r := Registry_New()
    r.AddChord(Registry_LaunchChord({Reference: false}), Noop)
    r.EnableChordReference(true)
    T.Eq(r.SortedPages().Length, 0)
    r2 := Registry_New()
    r2.AddChord(Registry_LaunchChord(), Noop)
    r2.EnableChordReference(false)
    T.Eq(r2.SortedPages().Length, 0)
}

T.Test("Registry: chord entries join an existing page", Registry_ChordMerge)
Registry_ChordMerge() {
    r := Registry_New()
    r.Bind(["Launch", "Other"], "^q", "quit", Noop)
    r.EnableChordReference(true)
    r.AddChord(Registry_LaunchChord(), Noop)
    T.Eq(r.Pages.Length, 1)
    T.Eq(r.Page("Launch").Categories.Length, 3)
}

T.Test("Registry: chords added after enabling are paged once", Registry_ChordAfterEnable)
Registry_ChordAfterEnable() {
    r := Registry_New()
    r.AddChord(Registry_LaunchChord(), Noop)
    r.EnableChordReference(true)
    r.AddChord(LegendChord("#j", "Other", [LegendChordItem("a", "A", Noop)]), Noop)
    T.Eq(r.Page("Launch").Categories[1].Groups[1].Entries.Length, 3)
    T.Eq(r.Page("Other").Categories[1].Groups[1].Entries.Length, 1)
}

T.Test("Registry: SortedPages skips empty pages", Registry_Sorted)
Registry_Sorted() {
    r := Registry_New()
    r.Bind(["zeta", "c"], "^z", "z", Noop)
    r.Page("empty")
    r.Bind(["Alpha", "c"], "^a", "a", Noop)
    pages := r.SortedPages()
    T.Eq(pages.Length, 2)
    T.Eq(pages[1].Title, "Alpha")
    T.Eq(pages[2].Title, "zeta")
}

T.Test("Registry: a code match set after bindings warns", Registry_LateMatch)
Registry_LateMatch() {
    r := Registry_New()
    r.Page("Zen").Category("Tabs", [["#+o", "open in Chrome", Noop]])
    r.Page("Zen", "ahk_exe zen.exe")
    T.Eq(r.Warnings.Length, 1)
    T.True(InStr(r.Warnings[1], "Zen") && InStr(r.Warnings[1], "ahk_exe zen.exe"), r.Warnings[1])
    r.Page("Zen", "ahk_exe zen.exe")               ; same match again: nothing new
    T.Eq(r.Warnings.Length, 1)
    r2 := Registry_New()
    r2.Page("Zen", "ahk_exe zen.exe").Category("Tabs", [["#+o", "open in Chrome", Noop]])
    T.Eq(r2.Warnings.Length, 0, "match before bindings")
}

T.Test("Registry: an invalid code Key warns and is ignored", Registry_BadCodeKey)
Registry_BadCodeKey() {
    r := Registry_New()
    p := r.Page("Zen", "", {Key: "zz"})
    T.Eq(p.Letter, "")
    T.Eq(r.Warnings.Length, 1)
    T.True(InStr(r.Warnings[1], "zz"), r.Warnings[1])
    T.Eq(r.Page("Zen", "", {Key: "Z"}).Letter, "z")
}

T.Test("Registry: pages, categories and groups merge case-insensitively beyond ASCII", Registry_UnicodeMerge)
Registry_UnicodeMerge() {
    r := Registry_New()
    T.Eq(ObjPtr(r.Page("Ärger")), ObjPtr(r.Page("ärger")))
    p := r.Page("Ärger")
    T.Eq(ObjPtr(p.Category("Überblick")), ObjPtr(p.Category("überblick")))
    c := p.Category("Überblick")
    T.Eq(ObjPtr(c.Group("Éditer")), ObjPtr(c.Group("éditer")))
    T.Eq(r.Pages.Length, 1)
}

Registry_Fixture(name) => A_ScriptDir "\fixtures\pages\" name

T.Test("Registry: LoadPages takes a folder, a single file, or {Path, Key}", Registry_LoadPagesEntries)
Registry_LoadPagesEntries() {
    r := Registry_New()
    r.LoadPages([Registry_Fixture("zen.md")])
    T.True(IsObject(r.Get("Zen")), "a single file loads its page")
    T.True(!IsObject(r.Get("Broken")), "only the named file")
    T.Eq(r.Get("Zen").Letter, "z", "the file's key: stands")

    r2 := Registry_New()
    r2.LoadPages([{Path: Registry_Fixture("zen.md"), Key: "Q"}])
    T.Eq(r2.Get("Zen").Letter, "q", "Key overrides the file's key:")
    T.Eq(r2.Warnings.Length, 0, "a configured key is not a conflict")

    r3 := Registry_New()
    r3.LoadPages([A_ScriptDir "\fixtures\pages"])
    T.True(IsObject(r3.Get("Zen")) && IsObject(r3.Get("Broken")), "a folder loads every file")
}

T.Test("Registry: LoadPages warns on a missing path and on Key for a folder", Registry_LoadPagesWarnings)
Registry_LoadPagesWarnings() {
    r := Registry_New()
    r.LoadPages([A_ScriptDir "\fixtures\nope.md"])
    T.Eq(r.Warnings.Length, 1)
    T.True(InStr(r.Warnings[1], "not found"), r.Warnings[1])

    r2 := Registry_New()
    r2.LoadPages([{Path: A_ScriptDir "\fixtures\other", Key: "x"}])
    found := false
    for warning in r2.Warnings
        found := found || InStr(warning, "Key") && InStr(warning, "folder")
    T.True(found, "Key on a folder warns")

    r3 := Registry_New()
    r3.LoadPages([{Key: "x"}])
    T.Eq(r3.Warnings.Length, 1, "an entry without Path warns")
    T.True(InStr(r3.Warnings[1], "Path"), r3.Warnings[1])
}

T.Test("Registry: PageKeys override a file's key: by title, case-insensitively", Registry_PageKeys)
Registry_PageKeys() {
    r := Registry_New()
    r.SetPageKeys(Map("ZEN", "x"))
    r.LoadPages([Registry_Fixture("zen.md")])
    T.Eq(r.Get("Zen").Letter, "x")
    T.Eq(r.Warnings.Length, 0)

    r2 := Registry_New()
    r2.SetPageKeys({Zen: "y"})
    r2.LoadPages([Registry_Fixture("zen.md")])
    T.Eq(r2.Get("Zen").Letter, "y", "an object works too")
}

T.Test("Registry: a code Key beats PageKeys", Registry_CodeBeatsPageKeys)
Registry_CodeBeatsPageKeys() {
    r := Registry_New()
    r.SetPageKeys(Map("Zen", "x"))
    r.Page("Zen", "", {Key: "c"})
    T.Eq(r.Get("Zen").Letter, "c")
}

T.Test("Registry: PageKeys warn on a bad key and on a title with no page", Registry_PageKeysWarnings)
Registry_PageKeysWarnings() {
    r := Registry_New()
    r.SetPageKeys(Map("Zen", "zz"))
    T.Eq(r.Warnings.Length, 1)
    T.True(InStr(r.Warnings[1], "zz"), r.Warnings[1])

    r2 := Registry_New()
    r2.SetPageKeys(Map("Gmial", "g"))
    r2.Doc(["Gmail", "Mail"], "C", "Compose")
    T.Eq(r2.Warnings.Length, 0, "no warning until pages are checked")
    r2.CheckPageKeys()
    T.Eq(r2.Warnings.Length, 1)
    T.True(InStr(r2.Warnings[1], "Gmial"), r2.Warnings[1])
}

T.Test("Registry: a chord item shadowed by an earlier one on the same key warns", Registry_ChordShadowed)
Registry_ChordShadowed() {
    r := Registry_New()
    r.AddChord(LegendChord("#F12", "Launch", [Legend.Run("z", "Zed", Noop), Legend.Run("Z", "Zen", Noop),
        Legend.Menu("w", "Web", [Legend.Run("c", "Chrome", Noop), Legend.Run("c", "Chromium", Noop)])]), Noop)
    T.Eq(r.Warnings.Length, 1, "z and Z differ; the second c can never run")
    T.True(InStr(r.Warnings[1], "Chromium"), r.Warnings[1])

    r2 := Registry_New()
    r2.AddChord(LegendChord("#F12", "Launch", [Legend.Run("z", "Zed", Noop, {If: () => false}),
        Legend.Run("z", "Zen", Noop)]), Noop)
    T.Eq(r2.Warnings.Length, 0, "a conditional first item leaves the key to the next")
}
