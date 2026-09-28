#Requires AutoHotkey v2.0

; Overlay navigation: a stack of levels (index → page → category), the current
; screen of each level, and pin state. Pure: rows come from LegendRows and
; paginate(rows) returns LegendLayout screens.
class LegendNavigator {
    __New(pages, paginate, style := "text") {
        this.Pages := pages
        this.PaginateFn := paginate
        this.Style := style
        this.Stack := []
        this.Pinned := false
        this.Mode := "reference"
        this.RunItem := ""
    }

    Level => this.Stack[this.Stack.Length]
    ClaimsLetters => this.Level.Items.Length > 0

    View {
        get {
            level := this.Level
            return {Title: level.Title, Columns: level.Screens[level.ScreenIndex],
                ScreenIndex: level.ScreenIndex, ScreenCount: level.Screens.Length}
        }
    }

    ; matches: pages whose window is active. None → the index; one → that page;
    ; several → an index of just those. Backspace always leads back to the full index.
    Open(matches) {
        this.Stack := [this.IndexLevel(this.Pages, "Legend")]
        if matches.Length = 1
            this.Stack.Push(this.PageLevel(matches[1]))
        else if matches.Length > 1
            this.Stack.Push(this.IndexLevel(matches, "Legend › this window"))
    }

    ; Chord mode: the chord's top level; keys go through PressChord.
    OpenChord(chord) {
        this.Mode := "chord"
        this.Stack := [this.ChordLevel(chord.Items, chord.Title)]
    }

    ; "redraw" (entered a submenu), "run" (RunItem is set) or "miss".
    PressChord(key) {
        item := LegendChords.Find(this.Level.ChordItems, key)
        if !item
            return "miss"
        if item.IsMenu {
            this.Stack.Push(this.ChordLevel(item.Items, this.Level.Title " › " item.Label))
            return "redraw"
        }
        this.RunItem := item
        return "run"
    }

    ; Returns "redraw", "close", "pass" (key is not the overlay's) or "none".
    Press(key) {
        level := this.Level
        switch key {
            case "Backspace":
                if this.Stack.Length = 1
                    return "none"
                this.Stack.Pop()
                return "redraw"
            case "Next":
                if level.ScreenIndex >= level.Screens.Length
                    return "none"
                level.ScreenIndex += 1
                return "redraw"
            case "Prev":
                if level.ScreenIndex <= 1
                    return "none"
                level.ScreenIndex -= 1
                return "redraw"
            case "Pin":
                this.Pinned := !this.Pinned
                return "redraw"
            case "Close":
                return "close"
            case "Combo", "FocusLost":
                return this.Pinned ? "none" : "close"
        }
        if !this.ClaimsLetters
            return "pass"
        for item in level.Items {
            if item.Letter != "" && item.Letter = key {
                open := level.OpenItem
                this.Stack.Push(open(item))
                return "redraw"
            }
        }
        return "none"
    }

    ; Rebuilds every level on the stack with a new paginate function and key style
    ; (both change sizes), keeping the path, the pin, and each level's screen number
    ; where it still exists.
    Relayout(paginate, style) {
        this.PaginateFn := paginate
        this.Style := style
        stack := []
        for level in this.Stack {
            build := level.Build
            fresh := build()
            fresh.ScreenIndex := Min(level.ScreenIndex, fresh.Screens.Length)
            stack.Push(fresh)
        }
        this.Stack := stack
    }

    ; extras: display hints (tab / =).
    Footer(extras*) {
        level := this.Level
        parts := []
        if this.Mode = "chord" {
            parts.Push("esc close", "⌫ back")
            if level.Screens.Length > 1
                parts.Push("pgdn/^n  pgup/^p  " level.ScreenIndex "/" level.Screens.Length)
            parts.Push(extras*)
        } else {
            if this.ClaimsLetters
                parts.Push("a–z open")
            if this.Stack.Length > 1
                parts.Push("⌫ back")
            if level.Screens.Length > 1
                parts.Push("spc/^n  pgup/^p  " level.ScreenIndex "/" level.Screens.Length)
            parts.Push(this.Pinned ? "`` unpin" : "`` pin")
            parts.Push(extras*)
            parts.Push("esc close")
        }
        out := ""
        for p in parts
            out .= (A_Index > 1 ? "   ·   " : "") p
        return out
    }

    IndexLevel(pages, title) {
        letters := LegendNavigator.AssignLetters(pages, p => p.Title, p => p.Letter)
        items := []
        for i, p in pages
            items.Push({Letter: letters[i], Label: p.Title, Target: p})
        return this.WithBuild(this.MenuLevel(title, items, item => this.PageLevel(item.Target)),
            () => this.IndexLevel(pages, title))
    }

    ; A page that fits one screen is shown whole; otherwise its categories are listed.
    PageLevel(page) {
        screens := this.Paginate(LegendRows.ForPage(page, this.Style))
        if screens.Length = 1
            return this.WithBuild({Title: page.Title, Screens: screens, ScreenIndex: 1, Items: []},
                () => this.PageLevel(page))
        cats := []
        for c in page.Categories
            if LegendRows.ForCategory(c, this.Style).Length
                cats.Push(c)
        nameOf := c => c.Name != "" ? c.Name : "Other"
        letters := LegendNavigator.AssignLetters(cats, nameOf, c => "")
        items := []
        for i, c in cats
            items.Push({Letter: letters[i], Label: nameOf(c), Target: c})
        return this.WithBuild(this.MenuLevel(page.Title, items, item => this.CategoryLevel(page, item.Target)),
            () => this.PageLevel(page))
    }

    ChordLevel(items, title) {
        return this.WithBuild({Title: title, Screens: this.Paginate(LegendRows.ForChord(LegendChords.Visible(items), this.Style)),
            ScreenIndex: 1, Items: [], ChordItems: items}, () => this.ChordLevel(items, title))
    }

    CategoryLevel(page, cat) {
        name := cat.Name != "" ? cat.Name : "Other"
        return this.WithBuild({Title: page.Title " › " name, Screens: this.Paginate(LegendRows.ForCategory(cat, this.Style)),
            ScreenIndex: 1, Items: []}, () => this.CategoryLevel(page, cat))
    }

    ; Records how to rebuild a level, for Relayout.
    WithBuild(level, build) {
        level.Build := build
        return level
    }

    MenuLevel(title, items, open) =>
        {Title: title, Screens: this.Paginate(LegendRows.ForMenu(items)), ScreenIndex: 1, Items: items, OpenItem: open}

    Paginate(rows) {
        fn := this.PaginateFn
        return fn(rows)
    }

    ; One letter per item: its fixed letter if free, else the first free letter or
    ; digit of its name, else the first free one in a–z, 0–9, else "".
    static AssignLetters(items, nameOf, fixedOf) {
        static pool := "abcdefghijklmnopqrstuvwxyz0123456789"
        used := Map(), letters := []
        letters.Length := items.Length
        for i, item in items {
            f := StrLower(fixedOf(item))
            if StrLen(f) = 1 && InStr(pool, f) && !used.Has(f)
                used[f] := true, letters[i] := f
        }
        for i, item in items {
            if letters.Has(i)
                continue
            letter := ""
            for ch in StrSplit(StrLower(nameOf(item)) pool) {
                if InStr(pool, ch) && !used.Has(ch) {
                    letter := ch
                    break
                }
            }
            if letter != ""
                used[letter] := true
            letters[i] := letter
        }
        return letters
    }
}
