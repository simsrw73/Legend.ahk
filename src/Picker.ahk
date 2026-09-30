#Requires AutoHotkey v2.0

; A picker: a list with a cursor, optional scopes and a filter. Pure: the controller
; in Legend.ahk feeds it keys (LegendKey objects) and draws what it describes.
; source(scope) returns items {Text, Detail?, Icon?, Letter?, Data?}.
class LegendPicker {
    static Pool := "asdfg;qwertyuiopzxcvbnm1234567890"

    __New(hotkey, title, source, options := "") {
        opt := (name, fallback) => IsObject(options) && options.HasOwnProp(name) ? options.%name% : fallback
        this.Hotkey := hotkey
        this.Title := title
        this.Source := source
        this.OnPick := opt("OnPick", "")
        if !IsObject(this.OnPick)
            throw ValueError("picker '" title "': OnPick is required", -2)
        this.OnHighlight := opt("OnHighlight", "")
        this.OnCancel := opt("OnCancel", "")
        this.Start := opt("Start", 1)
        this.Scopes := opt("Scopes", [])
        this.StartScope := opt("Scope", this.Scopes.Length ? this.Scopes[1] : "")
        this.StartScopeIndex := 0
        for index, name in this.Scopes
            if name = this.StartScope
                this.StartScopeIndex := index
        if this.Scopes.Length && !this.StartScopeIndex
            throw ValueError("picker '" title "': scope '" this.StartScope "' is not in Scopes", -2)
        this.Density := opt("Density", "")
        this.Match := opt("Match", "")
        this.Reference := opt("Reference", true)
        this.EmptyText := opt("EmptyText", "Nothing to pick")
        this.ReferenceTitle := title (this.StartScope != "" ? " · " this.StartScope : "")
        trigger := LegendKeyName.FromHotkey(hotkey)
        this.TriggerName := trigger.Name
        this.TriggerId := trigger.Id
        shifted := trigger.Mods.Clone()
        shifted.Push("Shift")
        this.ShiftTriggerId := LegendKeyName.FromParts(shifted, trigger.Name).Id
        this.PageSize := 0
        this.Loads := 0   ; source calls so far; part of LayoutKey
        this.BeforeFilter := ""   ; the selection when / was pressed
        this.Items := [], this.Visible := [], this.Letters := []
        this.Cursor := 0, this.Mode := "normal", this.Query := "", this.ScopeIndex := 1
    }

    Scope => this.Scopes.Length ? this.Scopes[this.ScopeIndex] : ""
    Selected => this.Cursor ? this.Visible[this.Cursor] : ""
    TitleLine => this.Title (this.Scope != "" ? " · " this.Scope : "") (this.Mode = "filter" ? " / " this.Query "▏" : "")
    ScreenIndex => this.PageSize && this.Cursor ? (this.Cursor - 1) // this.PageSize + 1 : 1
    ; Everything the drawn rows depend on except which row is selected: when it is
    ; unchanged, the controller only moves the selection instead of redrawing.
    LayoutKey => this.Loads "|" this.TitleLine "|" this.Mode "|" this.ScreenIndex "|" this.ScreenCount "|" this.Visible.Length
    ScreenCount =>this.PageSize && this.Visible.Length ? (this.Visible.Length - 1) // this.PageSize + 1 : 1

    Open() {
        this.Mode := "normal", this.Query := ""
        this.ScopeIndex := Max(1, this.StartScopeIndex)
        this.Load()
    }

    Load() {
        source := this.Source
        this.Items := source(this.Scope)
        this.Loads += 1
        this.Refresh(this.Start)
    }

    ; Recomputes the visible rows and letters, putting the cursor on row `cursor` (clamped).
    Refresh(cursor) {
        this.Visible := []
        for item in this.Items
            if LegendPicker.Matches(item, this.Query)
                this.Visible.Push(item)
        this.Cursor := this.Visible.Length ? Max(1, Min(cursor, this.Visible.Length)) : 0
        this.Letters := this.Mode = "normal" ? LegendPicker.AssignLetters(this.Visible, this.TriggerName) : []
    }

    ; key: a LegendKey. Returns "redraw", "pick", "cancel", "density" or "none".
    Key(key) {
        if this.Mode = "filter"
            return this.FilterKey(key)
        if step := this.Step(key, true)
            return this.Move(step)
        switch key.Id {
            case "J": return this.Move(1)
            case "K": return this.Move(-1)
            case "H": return this.ChangeScope(-1)
            case "L": return this.ChangeScope(1)
            case "PgDn", "Ctrl+F": return this.Page(1)
            case "PgUp", "Ctrl+B": return this.Page(-1)
            case "Ctrl+T": return this.ChangeScope(1)
            case "Enter": return this.Cursor ? "pick" : "none"
            case "=": return "density"
            case "Esc", "Ctrl+G": return "cancel"
            case "/":
                this.BeforeFilter := this.Selected
                this.Mode := "filter"
                this.Refresh(this.Cursor)
                return "redraw"
        }
        if !key.Mods.Length && key.Verbatim = "" && StrLen(key.Name) = 1
            for index, letter in this.Letters
                if letter != "" && letter = key.Name {
                    this.Cursor := index
                    return "pick"
                }
        return "none"
    }

    ; Applies keys in order (the ones that piled up while the controller was drawing).
    ; Returns {Action: "pick" | "cancel" | "redraw" | "none", Density: number of "="
    ; presses}; keys after a pick or cancel are dropped.
    KeyBatch(keys) {
        changed := false, density := 0
        for key in keys {
            result := this.Key(key)
            switch result {
                case "pick", "cancel":
                    return {Action: result, Density: density}
                case "density":
                    density += 1, changed := true
                case "redraw":
                    changed := true
            }
        }
        return {Action: changed ? "redraw" : "none", Density: density}
    }

    FilterKey(key) {
        if step := this.Step(key, false)
            return this.Move(step)
        switch key.Id {
            case "Enter": return this.Cursor ? "pick" : "none"
            case "Ctrl+G": return "cancel"
            case "PgDn", "Ctrl+F": return this.Page(1)
            case "PgUp", "Ctrl+B": return this.Page(-1)
            case "Ctrl+T": return this.ChangeScope(1)
            case "Esc":
                selected := IsObject(this.Selected) ? this.Selected : this.BeforeFilter
                this.Mode := "normal", this.Query := ""
                this.Reselect(selected)
                return "redraw"
            case "Backspace":
                if this.Query = "" {
                    selected := IsObject(this.Selected) ? this.Selected : this.BeforeFilter
                    this.Mode := "normal"
                    this.Reselect(selected)
                } else {
                    this.Query := SubStr(this.Query, 1, -1)
                    this.Refresh(1)
                }
                return "redraw"
        }
        char := LegendPicker.CharOf(key)
        if char = ""
            return "none"
        this.Query .= char
        this.Refresh(1)
        return "redraw"
    }

    ; Refreshes and puts the cursor back on item (row 1 if it is gone).
    Reselect(item) {
        this.Refresh(1)
        for index, candidate in this.Visible
            if IsObject(item) && candidate == item
                this.Cursor := index
    }

    ; What a key types into the filter. The controller sets key.Char to the character
    ; the keyboard layout produces (Shift and AltGr included); without it, the key's
    ; own lowercase character with no modifier or Shift only. Control characters and
    ; other modifier combos type nothing; Space types a space.
    static CharOf(key) {
        if key.HasOwnProp("Char") && key.Char != ""
            return Ord(key.Char) >= 32 ? key.Char : ""
        if key.Verbatim != "" || key.Mods.Length > 1 || key.Mods.Length = 1 && key.Mods[1] != "Shift"
            return ""
        if key.Name = "Space"
            return " "
        return StrLen(key.Name) = 1 ? StrLower(key.Name) : ""
    }

    ; +1 / -1 for keys that move in both modes (and, in normal mode, the bare
    ; trigger key), else 0.
    Step(key, bare) {
        keyId := key.Id
        if keyId == this.TriggerId || keyId == "Down" || keyId == "Ctrl+N" || bare && this.Bare(key, "")
            return 1
        if keyId == this.ShiftTriggerId || keyId == "Up" || keyId == "Ctrl+P" || bare && this.Bare(key, "Shift")
            return -1
        return 0
    }

    ; The trigger's key with no modifiers, or with only modName.
    Bare(key, modName) {
        if key.Verbatim != "" || key.Name != this.TriggerName
            return false
        return modName = "" ? !key.Mods.Length : key.Mods.Length = 1 && key.Mods[1] = modName
    }

    Move(delta) {
        count := this.Visible.Length
        if count < 2
            return "none"
        this.Cursor := Mod(this.Cursor - 1 + delta + count, count) + 1
        return "redraw"
    }

    Page(direction) {
        size := this.PageSize, count := this.Visible.Length
        if !size || count <= size
            return "none"
        target := Max(1, Min(this.Cursor + direction * size, count))
        if target = this.Cursor
            return "none"
        this.Cursor := target
        return "redraw"
    }

    ChangeScope(delta) {
        count := this.Scopes.Length
        if count < 2
            return "none"
        this.ScopeIndex := Mod(this.ScopeIndex - 1 + delta + count, count) + 1
        this.Load()
        return "redraw"
    }

    ; Rows of the current screen for drawing.
    ScreenRows() {
        rows := []
        if !this.Cursor
            return rows
        first := this.PageSize ? (this.ScreenIndex - 1) * this.PageSize + 1 : 1
        last := this.PageSize ? Min(first + this.PageSize - 1, this.Visible.Length) : this.Visible.Length
        loop last - first + 1 {
            index := first + A_Index - 1
            item := this.Visible[index]
            rows.Push({Text: item.Text,
                Detail: item.HasOwnProp("Detail") ? item.Detail : "",
                Icon: item.HasOwnProp("Icon") ? item.Icon : 0,
                Letter: this.Letters.Length >= index ? this.Letters[index] : "",
                Selected: index = this.Cursor})
        }
        return rows
    }

    Footer(density) {
        parts := ["↵ pick", "^n/^p move"]
        if this.Mode = "filter" {
            if this.Scopes.Length > 1
                parts.Push("^t scope")
            parts.Push("esc clear")
        } else {
            parts.Push("/ filter")
            if this.Scopes.Length > 1
                parts.Push("^t scope")
            parts.Push("= " density, "esc close")
        }
        if this.ScreenCount > 1
            parts.Push("^f/^b " this.ScreenIndex "/" this.ScreenCount)
        text := ""
        for part in parts
            text .= (A_Index > 1 ? "   ·   " : "") part
        return text
    }

    ; Every space-separated term is a case-insensitive substring of Text or Detail.
    static Matches(item, query) {
        haystack := item.Text (item.HasOwnProp("Detail") ? " " item.Detail : "")
        for term in StrSplit(query, " ")
            if term != "" && !InStr(haystack, term)
                return false
        return true
    }

    ; One letter per item, top to bottom: its fixed Letter if in the pool and free,
    ; else the next free pool letter, else "". triggerName's key is never used.
    static AssignLetters(items, triggerName := "") {
        pool := StrLen(triggerName) = 1 ? StrReplace(this.Pool, StrLower(triggerName)) : this.Pool
        used := Map(), letters := []
        letters.Length := items.Length
        for index, item in items {
            fixed := item.HasOwnProp("Letter") ? StrLower(item.Letter) : ""
            if StrLen(fixed) = 1 && InStr(pool, fixed) && !used.Has(fixed)
                used[fixed] := true, letters[index] := fixed
        }
        next := 1
        for index, item in items {
            if letters.Has(index)
                continue
            letter := ""
            while next <= StrLen(pool) {
                char := SubStr(pool, next, 1), next += 1
                if !used.Has(char) {
                    letter := char, used[char] := true
                    break
                }
            }
            letters[index] := letter
        }
        return letters
    }
}
