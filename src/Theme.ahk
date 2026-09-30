#Requires AutoHotkey v2.0

; Overlay theme: built-in defaults (Catppuccin Mocha) overlaid by an INI file.
class LegendTheme {
    static BuiltinDir := RegExReplace(A_LineFile, "\\src\\[^\\]+$", "\themes")

    ; [section, name, kind, default]. kind: color | font | int:min:max | bool | enum:a|b
    static Schema := [
        ["colors", "background", "color", "11111B"],
        ["colors", "border", "color", "313244"],
        ["colors", "title", "color", "7F849C"],
        ["colors", "category", "color", "89B4FA"],
        ["colors", "group", "color", "7F849C"],
        ["colors", "keyBound", "color", "B4BEFE"],
        ["colors", "keyDoc", "color", "7B81AE"],
        ["colors", "description", "color", "CDD6F4"],
        ["colors", "footer", "color", "6C7086"],
        ["colors", "pinned", "color", "F9E2AF"],
        ["colors", "warning", "color", "FAB387"],
        ["colors", "indicatorOn", "color", "A6E3A1"],
        ["colors", "indicatorOff", "color", "45475A"],
        ["colors", "selection", "color", ""],       ; "" = border
        ["colors", "selectionText", "color", ""],   ; "" = description
        ["colors", "outline", "color", ""],         ; "" = category
        ["fonts", "uiFont", "font", "Segoe UI"],
        ["fonts", "keyFont", "font", "Consolas"],
        ["fonts", "titleSize", "int:6:48", 9],
        ["fonts", "headingSize", "int:6:48", 10],
        ["fonts", "bodySize", "int:6:48", 11],
        ["layout", "density", "enum:comfortable|compact", "comfortable"],
        ["layout", "padding", "int:0:100", ""],       ; "" = from density
        ["layout", "rowSpacing", "int:0:40", ""],     ; "" = from density
        ["layout", "maxColumns", "int:1:8", 3],
        ["layout", "maxHeightPercent", "int:20:100", 80],
        ["layout", "maxWidthPercent", "int:20:100", 90],
        ["layout", "opacity", "int:50:255", 245],
        ["layout", "rounded", "bool", true],
        ["keys", "keyStyle", "enum:text|symbols|ahk", "text"],
        ["keys", "legend", "enum:auto|off|top|bottom", "auto"]
    ]

    ; Spacing each density gives settings the theme leaves empty.
    static Densities := Map("compact", {padding: 20, rowSpacing: 6, columnGap: 40},
        "comfortable", {padding: 28, rowSpacing: 12, columnGap: 56})

    ; Effective settings for drawing: a copy of values with density spacing filled in,
    ; optional session overrides for density and keyStyle, and legend "auto" turned
    ; into "bottom" for symbol styles or "off" for text.
    static Resolve(values, density := "", style := "") {
        resolved := values.Clone()
        if density != ""
            resolved["density"] := density
        if style != ""
            resolved["keyStyle"] := style
        preset := this.Densities[resolved["density"]]
        if resolved["padding"] = ""
            resolved["padding"] := preset.padding
        if resolved["rowSpacing"] = ""
            resolved["rowSpacing"] := preset.rowSpacing
        resolved["columnGap"] := preset.columnGap
        if resolved["legend"] = "auto"
            resolved["legend"] := resolved["keyStyle"] = "text" ? "off" : "bottom"
        for name, fallback in Map("selection", "border", "selectionText", "description", "outline", "category")
            if resolved[name] = ""
                resolved[name] := resolved[fallback]
        return resolved
    }

    ; Loads <name>.ini from the first of dirs that has it, else from the built-in
    ; themes folder. "auto" picks catppuccin-latte or catppuccin-mocha from the
    ; Windows app theme. Returns {Values, Warnings}.
    static Load(name, dirs := []) {
        if name = "auto"
            name := this.WindowsIsLight() ? "catppuccin-latte" : "catppuccin-mocha"
        search := dirs.Clone()
        search.Push(this.BuiltinDir)
        path := ""
        for dir in search {
            if FileExist(dir "\" name ".ini") {
                path := dir "\" name ".ini"
                break
            }
        }
        warnings := []
        if path = ""
            warnings.Push("theme '" name "' not found; using defaults")
        return {Values: this.Read(path, warnings), Warnings: warnings}
    }

    ; Reads path over the defaults ("" = defaults only), adding a warning per bad value.
    static Read(path, warnings := []) {
        values := Map()
        values.CaseSense := false
        for item in this.Schema {
            raw := path = "" ? "" : IniRead(path, item[1], item[2], "")
            values[item[2]] := raw = "" ? item[4] : this.Check(raw, item[3], item[4], item[1] "." item[2], warnings)
        }
        return values
    }

    static Check(raw, kind, fallback, label, warnings) {
        raw := Trim(raw)
        value := raw, ok := true
        if kind = "color" {
            ok := RegExMatch(raw, "^#?([0-9A-Fa-f]{6})$", &found)
            value := ok ? StrUpper(found[1]) : ""
        } else if kind = "bool" {
            ok := RegExMatch(raw, "i)^(1|0|true|false|yes|no|on|off)$")
            value := RegExMatch(raw, "i)^(1|true|yes|on)$") ? true : false
        } else if SubStr(kind, 1, 4) = "int:" {
            bounds := StrSplit(kind, ":")
            ok := IsInteger(raw) && Integer(raw) >= Integer(bounds[2]) && Integer(raw) <= Integer(bounds[3])
            value := ok ? Integer(raw) : 0
        } else if SubStr(kind, 1, 5) = "enum:" {
            value := StrLower(raw), ok := false
            for choice in StrSplit(SubStr(kind, 6), "|")
                if value == choice
                    ok := true
        }
        if ok
            return value
        warnings.Push("theme " label ": invalid value '" raw "'")
        return fallback
    }

    static WindowsIsLight() {
        try
            return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 1
        catch
            return false
    }
}
