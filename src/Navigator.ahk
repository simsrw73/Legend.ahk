#Requires AutoHotkey v2.0

; Overlay navigation: a stack of levels (index → page → category), the current
; screen of each level, and pin state. Pure: rows come from LegendRows and
; paginate(rows) returns LegendLayout screens.
class LegendNavigator {
    static Builds := 0   ; levels built by any navigator; part of LayoutKey

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
    ; Changes with the shown level, its screen, the pin and the key style, but not
    ; when only the cursor moves (Legend.Render then moves the selection in place).
    LayoutKey => this.Level.BuildId "|" this.Stack.Length "|" this.Level.ScreenIndex "|" this.Pinned "|" this.Style

    ; The cursor's position among the current screen's rows (0 without a cursor).
    SelectedIndex => this.Level.Cursor ? this.Level.Cursor - this.FirstItemOf(this.Level, this.Level.ScreenIndex) + 1 : 0

    View {
        get {
            level := this.Level
            if level.Cursor {
                rowIndex := 0
                for screen in level.Screens
                    for col in screen
                        for row in col.Rows
                            rowIndex += 1, row.Selected := rowIndex = level.Cursor
            }
            return {Title: level.Title, Columns: level.Screens[level.ScreenIndex],
                ScreenIndex: level.ScreenIndex, ScreenCount: level.Screens.Length, SelectedIndex: this.SelectedIndex}
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
                back := this.Level
                if back.Cursor
                    back.Cursor := 1, back.ScreenIndex := 1
                return "redraw"
            case "Next":
                if level.ScreenIndex >= level.Screens.Length
                    return "none"
                level.ScreenIndex += 1
                if level.Cursor
                    level.Cursor := this.FirstItemOf(level, level.ScreenIndex)
                return "redraw"
            case "Prev":
                if level.ScreenIndex <= 1
                    return "none"
                level.ScreenIndex -= 1
                if level.Cursor
                    level.Cursor := this.FirstItemOf(level, level.ScreenIndex)
                return "redraw"
            case "Down", "Up":
                count := level.Items.Length
                if !level.Cursor || count < 2
                    return "none"
                level.Cursor := Mod(level.Cursor - 1 + (key = "Down" ? 1 : -1) + count, count) + 1
                level.ScreenIndex := this.ScreenOf(level, level.Cursor)
                return "redraw"
            case "Enter":
                if !level.Cursor
                    return "none"
                open := level.OpenItem
                this.Stack.Push(open(level.Items[level.Cursor]))
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
            if fresh.Cursor && level.Cursor {
                fresh.Cursor := Min(level.Cursor, fresh.Items.Length)
                fresh.ScreenIndex := this.ScreenOf(fresh, fresh.Cursor)
            }
            stack.Push(fresh)
        }
        this.Stack := stack
    }

    ; extras: display hints (tab / =).
    Footer(extras*) {
        level := this.Level
        parts := []
        pages := level.Screens.Length > 1 ? "^f/^b " level.ScreenIndex "/" level.Screens.Length : ""
        if this.Mode = "chord" {
            parts.Push("esc close", "⌫ back")
            if pages != ""
                parts.Push(pages)
            parts.Push(extras*)
        } else {
            if level.Cursor
                parts.Push("↵ open", "^n/^p move")
            if pages != ""
                parts.Push(pages)
            if this.Stack.Length > 1
                parts.Push("⌫ back")
            parts.Push(this.Pinned ? "`` unpin" : "`` pin")
            parts.Push(extras*)
            parts.Push("esc close")
        }
        text := ""
        for part in parts
            text .= (A_Index > 1 ? "   ·   " : "") part
        return text
    }

    IndexLevel(pages, title) {
        letters := LegendNavigator.AssignLetters(pages, page => page.Title, page => page.Letter)
        items := []
        for index, page in pages
            items.Push({Letter: letters[index], Label: page.Title, Target: page})
        return this.WithBuild(this.MenuLevel(title, items, item => this.PageLevel(item.Target)),
            () => this.IndexLevel(pages, title))
    }

    ; A page that fits one screen is shown whole; otherwise its categories are listed.
    PageLevel(page) {
        screens := this.Paginate(LegendRows.ForPage(page, this.Style))
        if screens.Length = 1
            return this.WithBuild({Title: page.Title, Screens: screens, ScreenIndex: 1, Items: [], Cursor: 0},
                () => this.PageLevel(page))
        cats := []
        for cat in page.Categories
            if LegendRows.ForCategory(cat, this.Style).Length
                cats.Push(cat)
        nameOf := cat => cat.Name != "" ? cat.Name : "Other"
        letters := LegendNavigator.AssignLetters(cats, nameOf, cat => "")
        items := []
        for index, cat in cats
            items.Push({Letter: letters[index], Label: nameOf(cat), Target: cat})
        return this.WithBuild(this.MenuLevel(page.Title, items, item => this.CategoryLevel(page, item.Target)),
            () => this.PageLevel(page))
    }

    ChordLevel(items, title) {
        return this.WithBuild({Title: title, Screens: this.Paginate(LegendRows.ForChord(LegendChords.Visible(items), this.Style)),
            ScreenIndex: 1, Items: [], ChordItems: items, Cursor: 0}, () => this.ChordLevel(items, title))
    }

    CategoryLevel(page, cat) {
        name := cat.Name != "" ? cat.Name : "Other"
        return this.WithBuild({Title: page.Title " › " name, Screens: this.Paginate(LegendRows.ForCategory(cat, this.Style)),
            ScreenIndex: 1, Items: [], Cursor: 0}, () => this.CategoryLevel(page, cat))
    }

    ; Records how to rebuild a level, for Relayout.
    WithBuild(level, build) {
        level.Build := build
        level.BuildId := ++LegendNavigator.Builds
        return level
    }

    MenuLevel(title, items, open) =>
        {Title: title, Screens: this.Paginate(LegendRows.ForMenu(items)), ScreenIndex: 1, Items: items, OpenItem: open,
            Cursor: items.Length ? 1 : 0}

    Paginate(rows) {
        paginateFn := this.PaginateFn
        return paginateFn(rows)
    }

    ; Screen holding menu row `index` (menu rows and items are 1:1).
    ScreenOf(level, index) {
        count := 0
        for screenIndex, screen in level.Screens
            for col in screen {
                count += col.Rows.Length
                if index <= count
                    return screenIndex
            }
        return level.Screens.Length
    }

    ; Index of the first menu row on screen screenIndex.
    FirstItemOf(level, screenIndex) {
        count := 0
        loop screenIndex - 1
            for col in level.Screens[A_Index]
                count += col.Rows.Length
        return count + 1
    }

    ; One letter per item: its fixed letter if free, else the first free letter or
    ; digit of its name, else the first free one in a–z, 0–9, else "".
    static AssignLetters(items, nameOf, fixedOf) {
        static pool := "abcdefghijklmnopqrstuvwxyz0123456789"
        used := Map(), letters := []
        letters.Length := items.Length
        for index, item in items {
            fixed := StrLower(fixedOf(item))
            if StrLen(fixed) = 1 && InStr(pool, fixed) && !used.Has(fixed)
                used[fixed] := true, letters[index] := fixed
        }
        for index, item in items {
            if letters.Has(index)
                continue
            letter := ""
            for char in StrSplit(StrLower(nameOf(item)) pool) {
                if InStr(pool, char) && !used.Has(char) {
                    letter := char
                    break
                }
            }
            if letter != ""
                used[letter] := true
            letters[index] := letter
        }
        return letters
    }
}
