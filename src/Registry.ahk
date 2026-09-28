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
        for g in this.Groups
            if g.Name = name
                return g
        this.Groups.Push(g := LegendGroup(name))
        return g
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
    }

    Match => this.CodeMatch != "" ? this.CodeMatch : this.FileMatch
    Letter => this.CodeLetter != "" ? this.CodeLetter : this.FileLetter

    IsEmpty {
        get {
            for c in this.Categories
                for g in c.Groups
                    if g.Entries.Length
                        return false
            return true
        }
    }

    ; Returns the named category (case-insensitive), creating it. Each row is
    ; [hotkey, description, fn, options?] and is bound into group.
    Category(name, rows := "", group := "") {
        cat := ""
        for c in this.Categories
            if c.Name = name {
                cat := c
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
        for c in this.Categories
            for g in c.Groups
                for e in g.Entries
                    if e.Key.Id == id
                        return e
        return ""
    }
}

; All pages, from code and page files, plus warnings about them.
class LegendRegistry {
    __New() {
        this.Pages := []
        this.Warnings := []
        this.Binder := ObjBindMethod(LegendRegistry, "DefaultBinder")
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

    Get(title) {
        for p in this.Pages
            if p.Title = title
                return p
        return ""
    }

    ; Returns the page with this title (case-insensitive), creating it. match and
    ; options.Key given here win over a page file's.
    Page(title, match := "", options := "") {
        page := this.Get(title)
        if !page
            this.Pages.Push(page := LegendPage(this, title))
        if match != ""
            page.CodeMatch := match
        if IsObject(options) && options.HasOwnProp("Key")
            page.CodeLetter := StrLower(options.Key)
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
        for e in doc.Entries
            this.AddEntry(page, e.Category, e.Group, e.Key, e.Description, false)
    }

    AddBinding(page, category, group, hotkey, description, fn, options) {
        binder := this.Binder
        binder(hotkey, fn, page.CodeMatch)
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

    SortedPages() {
        out := []
        for p in this.Pages {
            if p.IsEmpty
                continue
            i := out.Length + 1
            while i > 1 && StrCompare(out[i - 1].Title, p.Title) > 0
                i -= 1
            out.InsertAt(i, p)
        }
        return out
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
        for w in this.Warnings
            if w == message
                return
        this.Warnings.Push(message)
    }
}
