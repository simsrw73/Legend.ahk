#Requires AutoHotkey v2.0

; Reads a Markdown help page. Only front matter, #/##/### headings and "- `keys` text"
; list items mean anything; everything else is ignored. Never throws on bad content:
; problems come back as warnings ("file:line: message").
class LegendPageFile {
    ; Returns {Page, Warnings}. Page is "" when the file is unusable, otherwise
    ; {Title, Match, Letter, Entries: [{Category, Group, Key, Description}]}.
    static Parse(text, source := "page") {
        lines := StrSplit(StrReplace(LTrim(text, Chr(0xFEFF)), "`r"), "`n")
        page := {Title: "", Match: "", Letter: "", Entries: []}
        warnings := []
        start := 1

        if lines.Length && Trim(lines[1]) = "---" {
            closed := false
            loop lines.Length - 1 {
                n := A_Index + 1
                line := Trim(lines[n])
                if line = "---" {
                    closed := true, start := n + 1
                    break
                }
                if !RegExMatch(line, "^(\w+)\s*:\s*(.*)$", &m)
                    continue
                switch StrLower(m[1]) {
                    case "match":
                        page.Match := Trim(m[2])
                    case "key":
                        letter := StrLower(Trim(m[2]))
                        if RegExMatch(letter, "^[a-z0-9]$")
                            page.Letter := letter
                        else
                            warnings.Push(source ":" n ": key must be one letter or digit")
                }
            }
            if !closed {
                warnings.Push(source ":1: front matter is not closed with ---; file skipped")
                return {Page: "", Warnings: warnings}
            }
        }

        category := "", group := "", inFence := false
        loop lines.Length - start + 1 {
            n := start + A_Index - 1
            line := lines[n]
            if RegExMatch(line, "^\s*(``{3,}|~{3,})") {
                inFence := !inFence
                continue
            }
            if inFence
                continue
            if RegExMatch(line, "^#\s+(.+?)(?:\s+#+)?\s*$", &m) {
                if page.Title = ""
                    page.Title := m[1]
                continue
            }
            if RegExMatch(line, "^##\s+(.+?)(?:\s+#+)?\s*$", &m) {
                category := m[1], group := ""
                continue
            }
            if RegExMatch(line, "^###\s+(.+?)(?:\s+#+)?\s*$", &m) {
                group := m[1]
                continue
            }
            if !RegExMatch(line, "^\s*[-*+]\s+(``+)(.*)$", &m)
                continue
            ticks := m[1], rest := m[2]
            closeAt := InStr(rest, ticks)
            if !closeAt {
                warnings.Push(source ":" n ": unclosed backtick")
                continue
            }
            keyText := Trim(SubStr(rest, 1, closeAt - 1))
            description := RegExReplace(Trim(SubStr(rest, closeAt + StrLen(ticks))), "^[—–:-]\s*")
            try
                key := LegendKeyName.FromText(keyText)
            catch ValueError as e {
                warnings.Push(source ":" n ": " e.Message)
                continue
            }
            page.Entries.Push({Category: category, Group: group, Key: key, Description: description})
        }

        if page.Title = "" {
            warnings.Push(source ": no '# Title' line; file skipped")
            return {Page: "", Warnings: warnings}
        }
        return {Page: page, Warnings: warnings}
    }

    static Load(path) {
        SplitPath(path, &name)
        try
            text := FileRead(path, "UTF-8")
        catch OSError as e
            return {Page: "", Warnings: [name ": cannot read file: " e.Message]}
        return this.Parse(text, name)
    }

    ; Parses every *.md file in dir.
    static LoadDir(dir) {
        if !DirExist(dir)
            return [{Page: "", Warnings: ["pages folder not found: " dir]}]
        results := []
        loop files dir "\*.md"
            results.Push(this.Load(A_LoopFileFullPath))
        return results
    }
}
