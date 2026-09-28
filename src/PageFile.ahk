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
                lineNo := A_Index + 1
                line := Trim(lines[lineNo])
                if line = "---" {
                    closed := true, start := lineNo + 1
                    break
                }
                if !RegExMatch(line, "^(\w+)\s*:\s*(.*)$", &found)
                    continue
                switch StrLower(found[1]) {
                    case "match":
                        page.Match := Trim(found[2])
                    case "key":
                        letter := StrLower(Trim(found[2]))
                        if RegExMatch(letter, "^[a-z0-9]$")
                            page.Letter := letter
                        else
                            warnings.Push(source ":" lineNo ": key must be one letter or digit")
                }
            }
            if !closed {
                warnings.Push(source ":1: front matter is not closed with ---; file skipped")
                return {Page: "", Warnings: warnings}
            }
        }

        category := "", group := "", inFence := false
        loop lines.Length - start + 1 {
            lineNo := start + A_Index - 1
            line := lines[lineNo]
            if RegExMatch(line, "^\s*(``{3,}|~{3,})") {
                inFence := !inFence
                continue
            }
            if inFence
                continue
            if RegExMatch(line, "^#\s+(.+?)(?:\s+#+)?\s*$", &found) {
                if page.Title = ""
                    page.Title := found[1]
                continue
            }
            if RegExMatch(line, "^##\s+(.+?)(?:\s+#+)?\s*$", &found) {
                category := found[1], group := ""
                continue
            }
            if RegExMatch(line, "^###\s+(.+?)(?:\s+#+)?\s*$", &found) {
                group := found[1]
                continue
            }
            if !RegExMatch(line, "^\s*[-*+]\s+(``+)(.*)$", &found)
                continue
            ticks := found[1], rest := found[2]
            closeAt := InStr(rest, ticks)
            if !closeAt {
                warnings.Push(source ":" lineNo ": unclosed backtick")
                continue
            }
            keyText := Trim(SubStr(rest, 1, closeAt - 1))
            description := RegExReplace(Trim(SubStr(rest, closeAt + StrLen(ticks))), "^[—–:-]\s*")
            try
                key := LegendKeyName.FromText(keyText)
            catch ValueError as err {
                warnings.Push(source ":" lineNo ": " err.Message)
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
        catch OSError as err
            return {Page: "", Warnings: [name ": cannot read file: " err.Message]}
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
