#Requires AutoHotkey v2.0

; One shortcut on a page. Bound entries were registered as hotkeys; the rest are
; documentation only.
class LegendEntry {
    __New(key, description, bound, options := "") {
        this.Key := key
        this.Description := description
        this.Bound := bound
        this.Row := IsObject(options) && options.HasOwnProp("Row") ? options.Row : ""
        this.Text := IsObject(options) && options.HasOwnProp("Text") ? options.Text : ""
    }
}

class LegendGroup {
    __New(name) {
        this.Name := name
        this.Entries := []
    }
}

class LegendCategory {
    __New(page, name) {
        this.Page := page
        this.Name := name
        this.Groups := []
    }

    Group(name) {
        for grp in this.Groups
            if LegendRegistry.SameName(grp.Name, name)
                return grp
        this.Groups.Push(grp := LegendGroup(name))
        return grp
    }

    ; Registers hotkey and lists it here. Returns this category for chaining.
    Bind(hotkey, description, fn, options := "", group := "") {
        this.Page.Registry.AddBinding(this.Page, this.Name, group, hotkey, description, fn, options)
        return this
    }
}

class LegendPage {
    __New(registry, title) {
        this.Registry := registry
        this.Title := title
        this.Categories := []
        this.CodeMatch := "", this.FileMatch := ""
        this.CodeLetter := "", this.FileLetter := ""
        this.HasBindings := false   ; hotkeys registered from code (under CodeMatch)
    }

    Match => this.CodeMatch != "" ? this.CodeMatch : this.FileMatch
    ; Code's Key, then PageKeys / a Pages entry's Key, then the file's key:.
    Letter {
        get {
            if this.CodeLetter != ""
                return this.CodeLetter
            configured := IsObject(this.Registry) ? this.Registry.ConfiguredLetter(this.Title) : ""
            return configured != "" ? configured : this.FileLetter
        }
    }

    IsEmpty {
        get {
            for cat in this.Categories
                for grp in cat.Groups
                    if grp.Entries.Length
                        return false
            return true
        }
    }

    ; Returns the named category (case-insensitive, any script), creating it. Each row is
    ; [hotkey, description, fn, options?] and is bound into group.
    Category(name, rows := "", group := "") {
        cat := ""
        for existing in this.Categories
            if LegendRegistry.SameName(existing.Name, name) {
                cat := existing
                break
            }
        if !cat
            this.Categories.Push(cat := LegendCategory(this, name))
        if IsObject(rows)
            for row in rows
                cat.Bind(row[1], row[2], row[3], row.Length >= 4 ? row[4] : "", group)
        return cat
    }

    FindEntry(id) {
        for cat in this.Categories
            for grp in cat.Groups
                for entry in grp.Entries
                    if entry.Key.Id == id
                        return entry
        return ""
    }
}

; All pages, from code and page files, plus warnings about them.
class LegendRegistry {
    __New() {
        this.Pages := []
        this.Warnings := []
        this.Binder := ObjBindMethod(LegendRegistry, "DefaultBinder")
        this.Chords := []
        this.ChordReference := ""   ; set by EnableChordReference (Legend.Start)
        this.Pickers := []
        this.PageKeys := []        ; [{Title, Letter}] from Start's PageKeys and Pages entries
    }

    ; Loads Start's Pages entries: a folder, a page file, or {Path, Key} (Key gives the
    ; file's page that letter).
    LoadPages(entries) {
        for entry in entries {
            if IsObject(entry) && !entry.HasOwnProp("Path") {
                this.Warn("pages: an entry object needs a Path; ignored")
                continue
            }
            path := IsObject(entry) ? entry.Path : entry
            key := IsObject(entry) && entry.HasOwnProp("Key") ? entry.Key : ""
            if DirExist(path) {
                if key != ""
                    this.Warn("pages: Key '" key "' applies to a file, not the folder " path "; ignored")
                results := LegendPageFile.LoadDir(path)
            } else if FileExist(path)
                results := [LegendPageFile.Load(path)]
            else {
                this.Warn("page file or folder not found: " path)
                continue
            }
            for result in results {
                for warning in result.Warnings
                    this.Warn(warning)
                if !result.Page
                    continue
                this.AddFile(result.Page)
                if key != ""
                    this.SetPageKey(result.Page.Title, key, "pages")
            }
        }
    }

    ; titleKeys: a Map or object of page title → letter.
    SetPageKeys(titleKeys) {
        for title, key in titleKeys is Map ? titleKeys : titleKeys.OwnProps()
            this.SetPageKey(title, key)
    }

    ; source names the option in warnings: "PageKeys" or "pages".
    SetPageKey(title, key, source := "PageKeys") {
        letter := StrLower(key)
        if !RegExMatch(letter, "^[a-z0-9]$")
            return this.Warn(source ": key '" key "' for '" title "' must be one letter or digit; ignored")
        for known in this.PageKeys
            if LegendRegistry.SameName(known.Title, title)
                return known.Letter := letter
        this.PageKeys.Push({Title: title, Letter: letter})
    }

    ConfiguredLetter(title) {
        for known in this.PageKeys
            if LegendRegistry.SameName(known.Title, title)
                return known.Letter
        return ""
    }

    ; Warns about PageKeys titles no page has (a typo, or a page that was never loaded).
    CheckPageKeys() {
        for known in this.PageKeys
            if !this.Get(known.Title)
                this.Warn("PageKeys: no page titled '" known.Title "'")
    }

    ; Registers fn for keyName, active only in windows matching match ("" = everywhere).
    ; (The parameter must not be called "hotkey": that would shadow Hotkey().)
    static DefaultBinder(keyName, fn, match) {
        if match != ""
            HotIfWinActive(match)
        else
            HotIfWinActive()   ; also clears any condition the host left set
        try
            Hotkey(keyName, fn)
        finally
            HotIfWinActive()
    }

    ; Names match case-insensitively for every script, not just A-Z.
    static SameName(a, b) => StrCompare(a, b, "Locale") = 0

    Get(title) {
        for page in this.Pages
            if LegendRegistry.SameName(page.Title, title)
                return page
        return ""
    }

    ; Returns the page with this title (case-insensitive), creating it. match and
    ; options.Key given here win over a page file's.
    Page(title, match := "", options := "") {
        page := this.Get(title)
        if !page
            this.Pages.Push(page := LegendPage(this, title))
        if match != "" && match != page.CodeMatch {
            if page.HasBindings
                this.Warn("page '" page.Title "': match '" match "' was set after its bindings, which were registered without it")
            page.CodeMatch := match
        }
        if IsObject(options) && options.HasOwnProp("Key") {
            letter := StrLower(options.Key)
            if RegExMatch(letter, "^[a-z0-9]$")
                page.CodeLetter := letter
            else
                this.Warn("page '" page.Title "': key '" options.Key "' must be one letter or digit; ignored")
        }
        this.CheckConflict(page)
        return page
    }

    ; path: [page, category] or [page, category, group]
    Bind(path, hotkey, description, fn, options := "") {
        page := this.PathPage(path)
        return page.Category(path[2]).Bind(hotkey, description, fn, options, path.Length >= 3 ? path[3] : "")
    }

    Doc(path, keyText, description) {
        page := this.PathPage(path)
        return this.AddEntry(page, path[2], path.Length >= 3 ? path[3] : "", LegendKeyName.FromText(keyText), description, false)
    }

    ; Adds a parsed page file ({Title, Match, Letter, Entries}).
    AddFile(doc) {
        page := this.Page(doc.Title)
        page.FileMatch := doc.Match, page.FileLetter := doc.Letter
        this.CheckConflict(page)
        for entry in doc.Entries
            this.AddEntry(page, entry.Category, entry.Group, entry.Key, entry.Description, false)
    }

    ; Registers a chord: binds its trigger to open (under its Match) and, once the
    ; reference is enabled, adds its reference page.
    AddChord(chord, open) {
        binder := this.Binder
        binder(chord.Hotkey, open, chord.Match)
        this.Chords.Push(chord)
        this.CheckShadowed(chord.Items, chord.Title)
        if this.ChordReference = true
            this.AddChordPage(chord)
        return chord
    }

    ; Warns about chord items that can never run: an earlier item on the same key has
    ; no If, so it always wins. (Items after a conditional one are fallbacks, not shadowed.)
    CheckShadowed(items, menuTitle) {
        always := Map()
        for item in items {
            keyId := item.Pattern.Display("text")
            if always.Has(keyId)
                this.Warn("chord '" menuTitle "': '" item.Label "' on " keyId " can never run; '" always[keyId] "' has that key")
            else if !IsObject(item.If)
                always[keyId] := item.Label
            if item.IsMenu
                this.CheckShadowed(item.Items, menuTitle " › " item.Label)
        }
    }

    ; Legend.Start calls this once with its ChordReference option.
    EnableChordReference(enabled) {
        this.ChordReference := enabled ? true : false
        if enabled
            for chord in this.Chords
                this.AddChordPage(chord)
    }

    AddChordPage(chord) {
        if !chord.Reference
            return
        page := this.Page(chord.Title)
        if chord.Match != "" && page.FileMatch = ""
            page.FileMatch := chord.Match   ; decides which page opens; never conditions hotkeys
        this.AddChordLevel(page, chord.Items, [LegendKeyName.FromHotkey(chord.Hotkey)], chord.Title)
    }

    ; Registers a picker: binds its trigger to open (under its Match) and lists it on
    ; the "Pickers" reference page unless its Reference is false.
    AddPicker(picker, open) {
        binder := this.Binder
        binder(picker.Hotkey, open, picker.Match)
        this.Pickers.Push(picker)
        if picker.Reference
            this.AddEntry(this.Page("Pickers"), "Pickers", "", LegendKeyName.FromHotkey(picker.Hotkey), picker.ReferenceTitle, true)
        return picker
    }

    ; One category per menu level: the level's items first, then each submenu.
    AddChordLevel(page, items, steps, category) {
        for item in items {
            path := steps.Clone()
            path.Push(item.Pattern)
            label := item.Label (item.IsMenu ? " ›" : "") (item.Hint != "" ? " (" item.Hint ")" : "")
            this.AddEntry(page, category, "", LegendKeyName.Sequence(path), label, true)
        }
        for item in items {
            if !item.IsMenu
                continue
            path := steps.Clone()
            path.Push(item.Pattern)
            this.AddChordLevel(page, item.Items, path, category " › " item.Label)
        }
    }

    AddBinding(page, category, group, hotkey, description, fn, options) {
        binder := this.Binder
        binder(hotkey, fn, page.CodeMatch)
        page.HasBindings := true
        this.AddEntry(page, category, group, LegendKeyName.FromHotkey(hotkey), description, true, options)
    }

    ; Adds an entry, merging with an existing entry for the same key on this page:
    ; a binding upgrades a doc entry in place; a doc entry for a bound key is dropped.
    AddEntry(page, category, group, key, description, bound, options := "") {
        existing := key.Verbatim = "" ? page.FindEntry(key.Id) : ""
        if !existing {
            entry := LegendEntry(key, description, bound, options)
            page.Category(category).Group(group).Entries.Push(entry)
            return entry
        }
        if bound && existing.Bound {
            this.Warn("page '" page.Title "': " key.Id " is bound twice")
        } else if bound {
            incoming := LegendEntry(key, description, true, options)
            existing.Bound := true
            if existing.Description = ""
                existing.Description := incoming.Description
            if incoming.Row != ""
                existing.Row := incoming.Row
            if incoming.Text != ""
                existing.Text := incoming.Text
        }
        return existing
    }

    ; A page listing messages under 1, 2, …; not registered (Legend adds it to the
    ; index only while there are warnings).
    static WarningsPage(messages) {
        page := LegendPage("", "Warnings")
        group := page.Category("Warnings").Group("")
        for message in messages
            group.Entries.Push(LegendEntry(LegendKeyName.FromText(A_Index ""), message, false))
        return page
    }

    SortedPages() {
        sorted := []
        for page in this.Pages {
            if page.IsEmpty
                continue
            pos := sorted.Length + 1
            while pos > 1 && StrCompare(sorted[pos - 1].Title, page.Title) > 0
                pos -= 1
            sorted.InsertAt(pos, page)
        }
        return sorted
    }

    PathPage(path) {
        if !(path is Array) || path.Length < 2 || path.Length > 3
            throw ValueError("path must be [page, category] or [page, category, group]", -2)
        return this.Page(path[1])
    }

    CheckConflict(page) {
        if page.CodeMatch != "" && page.FileMatch != "" && page.CodeMatch != page.FileMatch
            this.Warn("page '" page.Title "': code match '" page.CodeMatch "' overrides file match '" page.FileMatch "'")
        if page.CodeLetter != "" && page.FileLetter != "" && page.CodeLetter != page.FileLetter
            this.Warn("page '" page.Title "': code key '" page.CodeLetter "' overrides file key '" page.FileLetter "'")
    }

    Warn(message) {
        for known in this.Warnings
            if known == message
                return
        this.Warnings.Push(message)
    }
}
