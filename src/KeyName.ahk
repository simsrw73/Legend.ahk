#Requires AutoHotkey v2.0

; A parsed shortcut. Mods is a subset of ["Win", "Ctrl", "Alt", "Shift"] in that order.
; Verbatim keys (ranges, sequences, unusual AHK hotkeys) keep their original text and
; are never merged with other keys.
class LegendKey {
    __New(mods, name, verbatim := "") {
        this.Mods := mods
        this.Name := name
        this.Verbatim := verbatim
    }

    ; Written notation for parsed keys ("Ctrl+Shift+T"), "=" + text for verbatim ones.
    Id => this.Verbatim != "" ? "=" this.Verbatim : LegendKeyName.Format(this, "text")
}

; Converts between AHK hotkey syntax, written notation and display styles.
class LegendKeyName {
    static ModOrder := ["Win", "Ctrl", "Alt", "Shift"]
    static AhkMods := Map("^", "Ctrl", "!", "Alt", "+", "Shift", "#", "Win")
    static WrittenMods := Map("ctrl", "Ctrl", "control", "Ctrl", "alt", "Alt", "shift", "Shift",
        "win", "Win", "super", "Win", "meta", "Win")
    static Symbols := Map("Ctrl", "⌃", "Alt", "⌥", "Shift", "⇧", "Win", "⊞")
    static AhkSymbols := Map("Ctrl", "^", "Alt", "!", "Shift", "+", "Win", "#")
    static KeySymbols := Map("Enter", "↵", "Backspace", "⌫", "Tab", "⇥", "Delete", "⌦",
        "Left", "←", "Right", "→", "Up", "↑", "Down", "↓")
    static Named := LegendKeyName.BuildNamed()

    ; lowercase alias → canonical key name
    static BuildNamed() {
        names := Map()
        for canonical, aliases in Map(
            "Space", ["space", "spc"], "Enter", ["enter", "return"], "Tab", ["tab"],
            "Esc", ["esc", "escape"], "Backspace", ["backspace", "bs"],
            "Delete", ["delete", "del"], "Insert", ["insert", "ins"], "Home", ["home"],
            "End", ["end"], "PgUp", ["pgup", "pageup"], "PgDn", ["pgdn", "pagedown"],
            "Up", ["up", "↑"], "Down", ["down", "↓"], "Left", ["left", "←"], "Right", ["right", "→"],
            "PrintScreen", ["printscreen", "prtsc"], "CapsLock", ["capslock"],
            "AppsKey", ["appskey", "menu"], "LButton", ["lbutton"], "RButton", ["rbutton"],
            "MButton", ["mbutton"], "WheelUp", ["wheelup"], "WheelDown", ["wheeldown"],
            "+", ["plus"], "-", ["minus"])
            for alias in aliases
                names[alias] := canonical
        return names
    }

    ; Canonical name for one key, or "" if unknown.
    static NormalizeName(name) {
        lower := StrLower(name)
        if this.Named.Has(lower)
            return this.Named[lower]
        if RegExMatch(lower, "^f([1-9]|1\d|2[0-4])$", &m)
            return "F" m[1]
        if RegExMatch(lower, "^numpad(\w+)$", &m)
            return "Numpad" StrTitle(m[1])
        if StrLen(name) = 1
            return StrUpper(name)
        return ""
    }

    static Ordered(modSet) {
        out := []
        for m in this.ModOrder
            if modSet.Has(m)
                out.Push(m)
        return out
    }

    ; AHK hotkey syntax ("!+h", "#Space"). Custom combos, "up" hotkeys and unknown key
    ; names come back verbatim.
    static FromHotkey(hotkey) {
        if InStr(hotkey, " & ") || RegExMatch(hotkey, "i) up$")
            return LegendKey([], "", hotkey)
        modSet := Map()
        i := 1
        while i < StrLen(hotkey) && InStr("^!+#<>*~$", c := SubStr(hotkey, i, 1)) {
            if this.AhkMods.Has(c)
                modSet[this.AhkMods[c]] := true
            i += 1
        }
        name := this.NormalizeName(SubStr(hotkey, i))
        return name = "" ? LegendKey([], "", hotkey) : LegendKey(this.Ordered(modSet), name)
    }

    ; Written notation ("Ctrl+Shift+T"). Ranges and sequences ("Ctrl+1–8", "Alt+H/J/K/L",
    ; "Ctrl+K Ctrl+S") come back verbatim; anything else unparseable throws ValueError.
    static FromText(text) {
        text := Trim(text)
        modSet := Map()
        rest := text
        while RegExMatch(rest, "i)^(ctrl|control|alt|shift|win|super|meta)\+(.+)$", &m) {
            modSet[this.WrittenMods[StrLower(m[1])]] := true
            rest := m[2]
        }
        if (name := this.NormalizeName(rest)) != ""
            return LegendKey(this.Ordered(modSet), name)
        if RegExMatch(text, "[ /,–…]") || InStr(text, "..")
            return LegendKey([], "", text)
        throw ValueError("unknown key '" text "'", -1)
    }

    ; Modifier names (any order) plus a key name as returned by GetKeyName.
    static FromParts(modList, keyName) {
        modSet := Map()
        for m in modList
            modSet[m] := true
        name := this.NormalizeName(keyName)
        return name = "" ? LegendKey([], "", keyName) : LegendKey(this.Ordered(modSet), name)
    }

    static Format(key, style := "text") {
        if key.Verbatim != ""
            return key.Verbatim
        out := ""
        switch style {
            case "symbols":
                for m in key.Mods
                    out .= this.Symbols[m]
                return out (this.KeySymbols.Has(key.Name) ? this.KeySymbols[key.Name] : key.Name)
            case "ahk":
                for m in key.Mods
                    out .= this.AhkSymbols[m]
                return out (StrLen(key.Name) = 1 ? StrLower(key.Name) : key.Name)
            default:
                for m in key.Mods
                    out .= m "+"
                return out key.Name
        }
    }

    ; "⊞ Win   ⌃ Ctrl" for the modifiers in mods (any order, duplicates fine);
    ; "" for the text style or when mods is empty.
    static LegendLine(mods, style) {
        if style != "symbols" && style != "ahk"
            return ""
        table := style = "symbols" ? this.Symbols : this.AhkSymbols
        out := ""
        for m in this.ModOrder {
            for used in mods {
                if used = m {
                    out .= (out != "" ? "   " : "") table[m] " " m
                    break
                }
            }
        }
        return out
    }
}
