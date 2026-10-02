#Requires AutoHotkey v2.0

PageFile_Fixture(name) => LegendPageFile.Load(A_ScriptDir "\fixtures\" name)

T.Test("PageFile: front matter and title", PageFile_FrontMatter)
PageFile_FrontMatter() {
    r := PageFile_Fixture("pages\zen.md")
    T.Eq(r.Warnings.Length, 0, "warnings")
    T.Eq(r.Page.Title, "Zen")
    T.Eq(r.Page.Match, "ahk_exe zen.exe")
    T.Eq(r.Page.Letter, "z")
    T.Eq(r.Page.Entries.Length, 8, "entries (code fence ignored)")
}

T.Test("PageFile: entries before any heading", PageFile_NoHeading)
PageFile_NoHeading() {
    e := PageFile_Fixture("pages\zen.md").Page.Entries[1]
    T.Eq(e.Category, "")
    T.Eq(e.Group, "")
    T.Eq(e.Key.Id, "F1")
    T.Eq(e.Description, "Help before any heading")
}

T.Test("PageFile: categories, groups and separators", PageFile_Structure)
PageFile_Structure() {
    entries := PageFile_Fixture("pages\zen.md").Page.Entries
    T.Eq(entries[3].Description, "Reopen closed tab", "em dash stripped")
    T.Eq(entries[4].Description, "Close tab", "colon stripped, * bullet")
    T.Eq(entries[4].Category, "Tabs")
    T.Eq(entries[4].Group, "Open & close")
    T.Eq(entries[5].Group, "Navigate")
    T.Eq(entries[8].Category, "Workspaces")
    T.Eq(entries[8].Group, "", "## resets group")
    T.Eq(entries[8].Key.Id, "Ctrl+Alt+Right")
}

T.Test("PageFile: verbatim and double-backtick keys", PageFile_SpecialKeys)
PageFile_SpecialKeys() {
    entries := PageFile_Fixture("pages\zen.md").Page.Entries
    T.Eq(entries[6].Key.Id, "=Ctrl+1–8")
    T.Eq(entries[7].Key.Id, "Ctrl+``")
    T.Eq(entries[7].Description, "Toggle something")
}

T.Test("PageFile: malformed lines become warnings", PageFile_Warnings)
PageFile_Warnings() {
    r := PageFile_Fixture("pages\broken.md")
    T.Eq(r.Page.Entries.Length, 1)
    T.Eq(r.Page.Entries[1].Key.Id, "Ctrl+S")
    T.Eq(r.Warnings.Length, 2)
    T.Eq(r.Warnings[1], "broken.md:4: unclosed backtick")
    T.True(InStr(r.Warnings[2], "broken.md:5: unknown key 'Ctrl+Entr'") = 1, r.Warnings[2])
}

T.Test("PageFile: missing title skips the file", PageFile_NoTitle)
PageFile_NoTitle() {
    r := PageFile_Fixture("other\notitle.md")
    T.Eq(r.Page, "")
    T.True(InStr(r.Warnings[1], "no '# Title'"), r.Warnings[1])
}

T.Test("PageFile: unclosed front matter skips the file", PageFile_Unclosed)
PageFile_Unclosed() {
    r := PageFile_Fixture("other\unclosed.md")
    T.Eq(r.Page, "")
    T.Eq(r.Warnings.Length, 1)
}

T.Test("PageFile: BOM and CRLF parse like plain text", PageFile_BomAndCrlf)
PageFile_BomAndCrlf() {
    r := LegendPageFile.Parse(Chr(0xFEFF) "# Title`r`n## Cat`r`n- ``Ctrl+S`` Save`r`n", "bom.md")
    T.Eq(r.Warnings.Length, 0)
    T.Eq(r.Page.Title, "Title")
    T.Eq(r.Page.Entries[1].Category, "Cat")
    T.Eq(r.Page.Entries[1].Description, "Save")
}

T.Test("PageFile: backticks inside a description are kept", PageFile_BackticksInDescription)
PageFile_BackticksInDescription() {
    r := LegendPageFile.Parse("# T`n- ``Ctrl+T`` New ``tab`` here", "t.md")
    T.Eq(r.Page.Entries[1].Key.Id, "Ctrl+T")
    T.Eq(r.Page.Entries[1].Description, "New ``tab`` here")
}

T.Test("PageFile: heading closing hashes and C#", PageFile_Headings)
PageFile_Headings() {
    r := LegendPageFile.Parse("# C# ##`n## Build ##`n- ``F5`` Run", "c.md")
    T.Eq(r.Page.Title, "C#")
    T.Eq(r.Page.Entries[1].Category, "Build")
}

T.Test("PageFile: LoadDir reads every .md and reports a missing folder", PageFile_LoadDir)
PageFile_LoadDir() {
    T.Eq(LegendPageFile.LoadDir(A_ScriptDir "\fixtures\pages").Length, 2)
    missing := LegendPageFile.LoadDir(A_ScriptDir "\fixtures\nope")
    T.Eq(missing.Length, 1)
    T.Eq(missing[1].Page, "")
    T.True(InStr(missing[1].Warnings[1], "not found"))
}

T.Test("PageFile: every page in collections/apps parses without warnings", PageFile_Collections)
PageFile_Collections() {
    results := LegendPageFile.LoadDir(A_ScriptDir "\..\collections\apps")
    T.True(results.Length >= 40, "found " results.Length " pages")
    for result in results {
        warnings := ""
        for warning in result.Warnings
            warnings .= warning "; "
        T.Eq(warnings, "", "warnings")
        T.True(IsObject(result.Page) && result.Page.Entries.Length > 0, "a page with keys")
    }
}
