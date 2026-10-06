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

class Letters_ReplacementFailureStore extends LegendLetterStore {
    static TempPath := ""
    static TempText := ""

    static Replace(temp, path) {
        this.TempPath := temp
        this.TempText := FileRead(temp, "UTF-8")
        throw Error("forced replacement failure")
    }
}

T.Test("Letters: failed replacement preserves the mapping and removes the temporary file", Letters_ReplacementFailure)
Letters_ReplacementFailure() {
    local dir, original, path, tempDir
    path := Letters_Path(), original := "a`tapple`n"
    Letters_ReplacementFailureStore.TempPath := ""
    try {
        FileAppend(original, path, "UTF-8-RAW")
        Letters_ReplacementFailureStore.Write(path, Letters_Pages("Banana"), Map("banana", "b"), Map("apple", "a"))
        T.Eq(FileRead(path, "UTF-8"), original, "original mapping")
        T.True(Letters_ReplacementFailureStore.TempPath != "", "replacement attempted")
        T.Eq(Letters_ReplacementFailureStore.TempText, "b`tbanana`n", "complete replacement")
        SplitPath(path, , &dir)
        SplitPath(Letters_ReplacementFailureStore.TempPath, , &tempDir)
        T.Eq(tempDir, dir, "same directory")
        T.True(!FileExist(Letters_ReplacementFailureStore.TempPath), "temporary file removed")
    } finally {
        try FileDelete(path)
        if Letters_ReplacementFailureStore.TempPath != ""
            try FileDelete(Letters_ReplacementFailureStore.TempPath)
    }
}

class Letters_LockedReplacementStore extends LegendLetterStore {
    static TempPath := ""
    static Locked := false
    static ReplaceFailed := false
    static ReplaceMessage := ""

    static Replace(temp, path) {
        local err, handle
        this.TempPath := temp
        ; Allow reads/writes, but deny deletion/renaming of the temporary source.
        handle := DllCall("CreateFileW", "Str", temp, "UInt", 0x80000000,
            "UInt", 3, "Ptr", 0, "UInt", 3, "UInt", 0x80, "Ptr", 0, "Ptr")
        if handle = -1
            throw OSError(A_LastError)
        this.Locked := true
        try {
            super.Replace(temp, path)
        } catch Error as err {
            this.ReplaceFailed := true
            this.ReplaceMessage := err.Message
            throw err
        } finally
            DllCall("CloseHandle", "Ptr", handle)
    }
}

T.Test("Letters: real replacement failure preserves the mapping and cleans up the locked source", Letters_LockedReplacement)
Letters_LockedReplacement() {
    local original, path
    path := Letters_Path(), original := "a`tapple`n"
    Letters_LockedReplacementStore.TempPath := ""
    Letters_LockedReplacementStore.Locked := false, Letters_LockedReplacementStore.ReplaceFailed := false
    try {
        FileAppend(original, path, "UTF-8-RAW")
        Letters_LockedReplacementStore.Write(path, Letters_Pages("Banana"), Map("banana", "b"), Map("apple", "a"))
        T.True(Letters_LockedReplacementStore.Locked, "temporary source locked")
        T.True(Letters_LockedReplacementStore.ReplaceFailed, "real replacement failed")
        T.True(FileExist(path), "original mapping still exists: " Letters_LockedReplacementStore.ReplaceMessage)
        T.Eq(FileRead(path, "UTF-8"), original, "original mapping")
        T.True(!FileExist(Letters_LockedReplacementStore.TempPath), "temporary file removed after unlocking")
    } finally {
        try FileDelete(path)
        if Letters_LockedReplacementStore.TempPath != ""
            try FileDelete(Letters_LockedReplacementStore.TempPath)
    }
}

class Letters_WriteFailureStore extends LegendLetterStore {
    static TempPath := ""
    static Closed := false

    static OpenTemp(path) {
        this.TempPath := path
        return Letters_FailingStream(path)
    }
}

class Letters_FailingStream {
    __New(path, throwOnWrite := true) {
        this.Stream := FileOpen(path, "w", "UTF-8-RAW")
        this.ThrowOnWrite := throwOnWrite
    }

    Write(text) {
        local written
        written := this.Stream.Write(SubStr(text, 1, 2))
        if this.ThrowOnWrite
            throw Error("forced partial write failure")
        return written
    }

    Close() {
        this.Stream.Close()
        Letters_WriteFailureStore.Closed := true
    }
}

T.Test("Letters: failed write preserves the mapping, closes the stream and removes the temporary file", Letters_WriteFailure)
T.Test("Letters: short write preserves the mapping and removes the temporary file", () => Letters_WriteFailure(Letters_ShortWriteStore))
class Letters_ShortWriteStore extends Letters_WriteFailureStore {
    static OpenTemp(path) {
        this.TempPath := path
        return Letters_FailingStream(path, false)
    }
}

Letters_WriteFailure(store := Letters_WriteFailureStore) {
    local original, path
    path := Letters_Path(), original := "a`tapple`n"
    store.TempPath := "", Letters_WriteFailureStore.Closed := false
    try {
        FileAppend(original, path, "UTF-8-RAW")
        store.Write(path, Letters_Pages("Banana"), Map("banana", "b"), Map("apple", "a"))
        T.Eq(FileRead(path, "UTF-8"), original, "original mapping")
        T.True(store.TempPath != "", "temporary write attempted")
        T.True(Letters_WriteFailureStore.Closed, "stream closed")
        T.True(!FileExist(store.TempPath), "temporary file removed")
    } finally {
        try FileDelete(path)
        if store.TempPath != ""
            try FileDelete(store.TempPath)
    }
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
