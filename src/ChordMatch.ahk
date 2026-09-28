#Requires AutoHotkey v2.0

; One chord key pattern: an AHK key name or a wildcard, optionally prefixed
; with modifier symbols (^ ! + #).
class LegendChordPattern {
    Display(style := "text") {
        switch this.Kind {
            case "key":
                if !this.Mods.Length && StrLen(this.Name) = 1
                    return StrLower(this.Name)
                return LegendKeyName.Format(LegendKey(this.Mods, this.Name), style)
            case "any":
                return LegendKeyName.FormatMods(this.Mods, style) "?"
            case "range":
                return LegendKeyName.FormatMods(this.Mods, style) this.Lo "–" this.Hi
            default:
                return LegendKeyName.FormatMods(this.Mods, style) this.Body
        }
    }
}

; Parses and matches chord key patterns (KeyChord-compatible wildcards):
;   ?      any single character key
;   F*     glob over named keys (* = any run of characters)
;   a-f    single characters with code points in the range
class LegendChordMatch {
    static Parse(text) {
        modSet := Map(), pos := 1
        while pos < StrLen(text) && LegendKeyName.AhkMods.Has(modChar := SubStr(text, pos, 1)) {
            modSet[LegendKeyName.AhkMods[modChar]] := true
            pos += 1
        }
        body := SubStr(text, pos)
        pattern := LegendChordPattern()
        pattern.Text := text, pattern.Mods := LegendKeyName.Ordered(modSet), pattern.Body := body
        pattern.Name := "", pattern.Lo := "", pattern.Hi := "", pattern.Regex := ""
        if body = "?" {
            pattern.Kind := "any"
        } else if StrLen(body) = 3 && SubStr(body, 2, 1) = "-" && Ord(SubStr(body, 1, 1)) <= Ord(SubStr(body, 3, 1)) {
            pattern.Kind := "range", pattern.Lo := StrLower(SubStr(body, 1, 1)), pattern.Hi := StrLower(SubStr(body, 3, 1))
        } else if StrLen(body) > 1 && InStr(body, "*") {
            pattern.Kind := "glob"
            pattern.Regex := "i)^" StrReplace(RegExReplace(body, "[\\.^$|?+()\[\]{}]", "\$0"), "*", ".*") "$"
        } else {
            name := LegendKeyName.NormalizeName(body)
            if name = ""
                throw ValueError("unknown chord key '" text "'", -2)
            pattern.Kind := "key", pattern.Name := name
        }
        return pattern
    }

    ; key: a LegendKey for the pressed key and the modifiers that count.
    static Matches(p, key) {
        if key.Verbatim != "" || !this.SameMods(p.Mods, key.Mods)
            return false
        switch p.Kind {
            case "key":
                return p.Name == key.Name
            case "any":
                return StrLen(key.Name) = 1
            case "range":
                if StrLen(key.Name) != 1
                    return false
                code := Ord(StrLower(key.Name))
                return code >= Ord(p.Lo) && code <= Ord(p.Hi)
            default:
                return StrLen(key.Name) > 1 && RegExMatch(key.Name, p.Regex) > 0
        }
    }

    static SameMods(a, b) {
        if a.Length != b.Length
            return false
        for index, modName in a
            if modName != b[index]
                return false
        return true
    }
}
