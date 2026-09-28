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
