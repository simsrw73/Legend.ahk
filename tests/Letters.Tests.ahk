#Requires AutoHotkey v2.0

Letters_Pages(titles*) {
    pages := []
    for title in titles
        pages.Push({Title: title, Letter: ""})
    return pages
}

Letters_Path() => A_Temp "\legend-letters-" A_TickCount "-" Random(1000, 9999) ".txt"

Letters_Of(letters, titles*) {
    out := ""
    for title in titles
        out .= (A_Index > 1 ? "," : "") letters[StrLower(title)]
    return out
}

T.Test("Letters: new pages get the first free letter of their title, saved to the file", Letters_Fresh)
Letters_Fresh() {
    path := Letters_Path()
    try {
        letters := LegendLetterStore.Assign(Letters_Pages("Apple", "Avocado", "Banana"), path)
        T.Eq(Letters_Of(letters, "Apple", "Avocado", "Banana"), "a,v,b")
        T.True(FileExist(path), "saved")
    } finally
        try FileDelete(path)
}

T.Test("Letters: a page keeps its letter when an earlier page goes away", Letters_Sticky)
Letters_Sticky() {
    path := Letters_Path()
    try {
        LegendLetterStore.Assign(Letters_Pages("Apple", "Avocado"), path)
        ; without the file, Avocado alone would take a
        T.Eq(Letters_Of(LegendLetterStore.Assign(Letters_Pages("Avocado"), path), "Avocado"), "v")
        ; Apple's a was freed, so a new page can take it; Avocado still keeps v
        letters := LegendLetterStore.Assign(Letters_Pages("Apricot", "Avocado"), path)
        T.Eq(Letters_Of(letters, "Apricot", "Avocado"), "a,v")
    } finally
        try FileDelete(path)
}

T.Test("Letters: a new page never takes a remembered letter", Letters_NewPage)
Letters_NewPage() {
    path := Letters_Path()
    try {
        LegendLetterStore.Assign(Letters_Pages("Gmail"), path)
        letters := LegendLetterStore.Assign(Letters_Pages("Gemini", "Gmail"), path)
        T.Eq(Letters_Of(letters, "Gemini", "Gmail"), "e,g")
    } finally
        try FileDelete(path)
}

T.Test("Letters: an explicit letter wins over a remembered one", Letters_Explicit)
Letters_Explicit() {
    path := Letters_Path()
    try {
        LegendLetterStore.Assign(Letters_Pages("Zed"), path)
        pages := Letters_Pages("Zed", "Zen")
        pages[2].Letter := "z"
        T.Eq(Letters_Of(LegendLetterStore.Assign(pages, path), "Zed", "Zen"), "e,z")
    } finally
        try FileDelete(path)
}

T.Test("Letters: titles match case-insensitively", Letters_Case)
Letters_Case() {
    path := Letters_Path()
    try {
        LegendLetterStore.Assign(Letters_Pages("Apple", "Avocado"), path)
        T.Eq(Letters_Of(LegendLetterStore.Assign(Letters_Pages("AVOCADO"), path), "Avocado"), "v")
    } finally
        try FileDelete(path)
}

T.Test("Letters: no file means plain automatic letters; a bad path doesn't throw", Letters_NoFile)
Letters_NoFile() {
    T.Eq(Letters_Of(LegendLetterStore.Assign(Letters_Pages("Avocado"), ""), "Avocado"), "a")
    letters := LegendLetterStore.Assign(Letters_Pages("Avocado"), "Q:\nowhere\" Chr(0) "\letters.txt")
    T.Eq(Letters_Of(letters, "Avocado"), "a")
}

T.Test("Letters: the warnings page lists each message under a number", Letters_WarningsPage)
Letters_WarningsPage() {
    page := LegendRegistry.WarningsPage(["page file or folder not found: x", "theme bad"])
    T.Eq(page.Title, "Warnings")
    entries := Registry_AllEntries(page)
    T.Eq(entries.Length, 2)
    T.Eq(entries[1].Key.Id, "1")
    T.Eq(entries[2].Description, "theme bad")
}

T.Test("Letters: the badge says where the warnings are; the tip lists them", Letters_WarningText)
Letters_WarningText() {
    T.Eq(LegendOverlay.WarningBadgeText(1), "⚠ 1 warning · see Warnings")
    T.Eq(LegendOverlay.WarningBadgeText(3), "⚠ 3 warnings · see Warnings")
    T.Eq(Legend.WarningTip(["one", "two"]), "1. one`n2. two")
}

T.Test("Letters: the navigator's index uses LetterOf", Letters_NavigatorLetterOf)
Letters_NavigatorLetterOf() {
    r := Registry_New()
    r.Doc(["Apple", "Fruit"], "A", "apple")
    nav := LegendNavigator(r.SortedPages(), (rows, *) => LegendLayout.Paginate(rows, FakeMeasure, 1000, 1))
    nav.LetterOf := page => "q"
    nav.Open([])
    T.Eq(nav.Level.Items[1].Letter, "q")
}
