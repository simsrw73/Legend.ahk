#Requires AutoHotkey v2.0

; Sticky index letters. A page keeps the letter it was given on every later run (the
; letters are saved to a file), so adding, removing or renaming pages never moves the
; letters of the others. Explicit letters (PageKeys, a file's key:, code) still win.
class LegendLetterStore {
    ; pages: objects with Title and Letter ("" = automatic). path: the file the letters
    ; live in ("" = don't remember: plain automatic letters). Returns a Map of
    ; lower-case title → letter for every page that got one.
    static Assign(pages, path) {
        local fresh, index, letter, letters, page, rest, saved, title, used
        saved := path != "" ? this.Read(path) : Map()
        letters := Map(), used := Map()
        for page in pages {   ; explicit letters first
            letter := StrLower(page.Letter)
            if letter != "" && !used.Has(letter)
                used[letter] := true, letters[StrLower(page.Title)] := letter
        }
        for page in pages {   ; then the letter each page had last time
            title := StrLower(page.Title)
            if !letters.Has(title) && saved.Has(title) && !used.Has(saved[title])
                used[saved[title]] := true, letters[title] := saved[title]
        }
        rest := []
        for page in pages
            if !letters.Has(StrLower(page.Title))
                rest.Push(page)
        fresh := LegendNavigator.AssignLetters(rest, page => page.Title, page => "", used)
        for index, page in rest
            if fresh[index] != ""
                letters[StrLower(page.Title)] := fresh[index]
        if path != ""
            this.Write(path, pages, letters, saved)
        return letters
    }

    ; Lines of "<letter><Tab><lower-case title>".
    static Read(path) {
        local parts, saved, text
        saved := Map()
        try
            text := FileRead(path, "UTF-8")
        catch
            return saved
        loop parse text, "`n", "`r" {
            parts := StrSplit(A_LoopField, "`t", , 2)
            if parts.Length = 2 && RegExMatch(parts[1], "^[a-z0-9]$")
                saved[parts[2]] := parts[1]
        }
        return saved
    }

    ; Saves the automatic letters of the pages that exist now (explicit ones live in
    ; the host's script), only when they changed. A file that can't be written is
    ; skipped: letters then last for this run only.
    static Write(path, pages, letters, saved) {
        local dir, keep, letter, page, stream, temp, text, title
        keep := Map()
        for page in pages {
            title := StrLower(page.Title)
            if page.Letter = "" && letters.Has(title)
                keep[title] := letters[title]
        }
        if this.Same(keep, saved)
            return
        text := ""
        for title, letter in keep
            text .= letter "`t" title "`n"
        stream := 0, temp := ""
        try {
            SplitPath(path, , &dir)
            if dir != "" && !DirExist(dir)
                DirCreate(dir)
            loop {
                temp := path ".tmp-" DllCall("GetCurrentProcessId", "UInt") "-" A_TickCount "-" Random(1, 2147483647)
                if !FileExist(temp)
                    break
            }
            stream := this.OpenTemp(temp)
            if stream.Write(text) != StrPut(text, "UTF-8") - 1
                throw Error("Incomplete letter mapping write")
            stream.Close()
            stream := 0
            this.Replace(temp, path)
        } catch {
            ; Persistence is optional; keep the previous mapping on failure.
        } finally {
            if IsObject(stream)
                try stream.Close()
            if temp != "" && FileExist(temp)
                try FileDelete(temp)
        }
    }

    static OpenTemp(path) => FileOpen(path, "w", "UTF-8-RAW")

    static Replace(temp, path) => FileMove(temp, path, 1)

    static Same(a, b) {
        local key, value
        if a.Count != b.Count
            return false
        for key, value in a
            if !b.Has(key) || b[key] != value
                return false
        return true
    }
}
