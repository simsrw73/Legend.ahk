# Legend Chord Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add chord mode to Legend: `Legend.Chord` hotkeys that open a which-key menu (optionally delayed or hidden), run one action per key sequence, and appear as pages in the Alt+/ reference, replacing the KeyChord library.

**Architecture:** Pure pieces are unit-tested: key-sequence display (`KeyName`), pattern matching (`ChordMatch`), chord items and held-modifier filtering (`Chord`), reference page generation (`Registry`), chord rows (`Rows`) and chord levels (`Navigator`). The `Legend` facade adds a chord controller: a suppressing, callback-driven `InputHook`, overlay delay, timeout and focus timers, sharing the existing overlay, theme and display toggles.

**Tech Stack:** AutoHotkey v2.0, PowerShell 7 test runner.

**Spec:** `docs/specs/2026-09-28-chord-mode-design.md` (with `docs/specs/2026-09-28-legend-design.md` for the existing parts).

## Global Constraints

- Every `.ahk` file starts with `#Requires AutoHotkey v2.0`; no external libraries; every library class name starts with `Legend`.
- **Never launch AutoHotkey from the Bash tool** (Git Bash rewrites `/ErrorStdOut` into a path and pops a dialog). Run tests with the PowerShell tool: `pwsh -NoProfile -File tests/Run-Tests.ps1` (exit code = failures).
- AHK names are case-insensitive: a local, parameter or global must not share a name with a built-in function or class it (or its scope) uses (`hotkey`/`Hotkey`, `log`/`Log`, `mod`/`Mod`, `c`/class `C`).
- `obj.Prop(args)` passes `obj` as the first argument when `Prop` holds a function: copy stored functions to a local before calling (`fn := this.If`, `fn()`).
- In AHK strings a literal backtick is ``` `` ```.
- Defaults (spec): `ChordTimeout: 0`, `ChordOverlay: 400`, `ChordReference: true`; theme `indicatorOn` `A6E3A1` / `indicatorOff` `45475A` (Latte `40A02B` / `BCC0CC`).
- Commit messages end with (same paragraph):
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01USck9RpHpDzGupiFEosHqF`
- Work on branch `chord-mode` in the Legend repo.

## Review Focus

1. A chord key pressed while the trigger's modifier is still held (Win+Space, then `z` with Win down) must match plain `z`. Test: Task 3, `Chord_HeldModifiers`.
2. A wildcard action function with no parameters (`() => …`) must still run (not error on the passed key). Test: Task 3, `Chord_RunArguments`.
3. Glob `F*` must not match the letter F. Test: Task 2, `ChordMatch_Glob`.
4. Reference pages must not duplicate entries when chords are added both before and after `Start`. Test: Task 4, `Registry_ChordAfterEnable`.
5. Ctrl+N/P/G in reference mode must not be treated as closing combos by the key watcher. Test: Task 6, `KeyWatch_ClaimedCombos`.

---

### Task 1: Key sequences and modifier formatting

**Files:**
- Modify: `src/KeyName.ahk`, `tests/KeyName.Tests.ahk`

**Interfaces:**
- Produces: `LegendKeyName.FormatMods(mods, style := "text") → String` (`"Ctrl+Shift+"`, `"⌃⇧"`, `"^+"`); `LegendKey.Display(style := "text") → String`; `LegendKeyName.Sequence(steps) → LegendKey` with property `Steps` (array of objects with `Display(style)` and `Mods`), `Verbatim` = text-style display, `Mods` = union of step mods. `LegendKeyName.Format` formats a sequence as its steps joined by spaces.

- [ ] **Step 1: Write the failing tests** — append to `tests/KeyName.Tests.ahk`:
```ahk

T.Test("KeyName: modifier prefixes per style", KeyName_FormatMods)
KeyName_FormatMods() {
    T.Eq(LegendKeyName.FormatMods(["Ctrl", "Shift"], "text"), "Ctrl+Shift+")
    T.Eq(LegendKeyName.FormatMods(["Ctrl", "Shift"], "symbols"), "⌃⇧")
    T.Eq(LegendKeyName.FormatMods(["Ctrl", "Shift"], "ahk"), "^+")
    T.Eq(LegendKeyName.FormatMods([], "text"), "")
}

T.Test("KeyName: sequences format step by step", KeyName_Sequence)
KeyName_Sequence() {
    seq := LegendKeyName.Sequence([LegendKeyName.FromHotkey("#Space"), LegendKeyName.FromText("Ctrl+S")])
    T.Eq(LegendKeyName.Format(seq, "text"), "Win+Space Ctrl+S")
    T.Eq(LegendKeyName.Format(seq, "ahk"), "#Space ^s")
    T.Eq(seq.Id, "=Win+Space Ctrl+S")
    T.Eq(seq.Mods.Length, 2)
    T.Eq(LegendKeyName.FromText("Alt+H").Display("symbols"), "⌥H")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `FAIL KeyName: modifier prefixes per style` and `FAIL KeyName: sequences format step by step` (no method `FormatMods` / `Sequence`).

- [ ] **Step 3: Implement** — in `src/KeyName.ahk`:

Add to `class LegendKey` (after `Id`):
```ahk
    Display(style := "text") => LegendKeyName.Format(this, style)
```

Replace `static Format(key, style := "text") { … }` with:
```ahk
    static Format(key, style := "text") {
        if key.HasOwnProp("Steps") {
            out := ""
            for step in key.Steps
                out .= (A_Index > 1 ? " " : "") step.Display(style)
            return out
        }
        if key.Verbatim != ""
            return key.Verbatim
        name := key.Name
        if style = "symbols" && this.KeySymbols.Has(name)
            name := this.KeySymbols[name]
        else if style = "ahk" && StrLen(name) = 1
            name := StrLower(name)
        return this.FormatMods(key.Mods, style) name
    }

    ; "Ctrl+Shift+" / "⌃⇧" / "^+" for mods in the given style.
    static FormatMods(mods, style := "text") {
        out := ""
        for m in mods
            out .= style = "symbols" ? this.Symbols[m] : style = "ahk" ? this.AhkSymbols[m] : m "+"
        return out
    }

    ; A key sequence (e.g. a chord trigger plus steps). steps: objects with
    ; Display(style) and Mods. Never merged with other keys (verbatim Id).
    static Sequence(steps) {
        modSet := Map()
        for step in steps
            for m in step.Mods
                modSet[m] := true
        text := ""
        for step in steps
            text .= (A_Index > 1 ? " " : "") step.Display("text")
        key := LegendKey(this.Ordered(modSet), "", text)
        key.Steps := steps
        return key
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `77 passed, 0 failed`, both validate lines ok.

- [ ] **Step 5: Commit**
```bash
git add src/KeyName.ahk tests/KeyName.Tests.ahk
git commit -m "KeyName: modifier prefixes and key sequences"
```

---

### Task 2: Chord key patterns

**Files:**
- Create: `src/ChordMatch.ahk`, `tests/ChordMatch.Tests.ahk`
- Modify: `tests/Legend.Tests.ahk` (includes above `T.Finish()`), `Legend.ahk` (include after `KeyWatch.ahk`)

**Interfaces:**
- Consumes: `LegendKeyName.AhkMods`, `.Ordered`, `.NormalizeName`, `.FormatMods`, `.Format`; `LegendKey`.
- Produces: `LegendChordMatch.Parse(text) → LegendChordPattern` (throws `ValueError` for unknown key names); `LegendChordMatch.Matches(pattern, key) → Boolean` (`key` is a `LegendKey`); `LegendChordPattern` properties `Text, Mods, Kind ("key"|"any"|"range"|"glob"), Body, Name, Lo, Hi, Regex`, method `Display(style := "text")`.

- [ ] **Step 1: Write the failing tests** — `tests/ChordMatch.Tests.ahk`:
```ahk
#Requires AutoHotkey v2.0

ChordMatch_Hit(pattern, text) => LegendChordMatch.Matches(LegendChordMatch.Parse(pattern), LegendKeyName.FromText(text))

T.Test("ChordMatch: exact keys compare modifiers exactly", ChordMatch_Exact)
ChordMatch_Exact() {
    T.True(ChordMatch_Hit("z", "z"))
    T.True(!ChordMatch_Hit("z", "Ctrl+Z"), "plain z vs Ctrl+Z")
    T.True(ChordMatch_Hit("^s", "Ctrl+S"))
    T.True(!ChordMatch_Hit("^s", "s"))
    T.True(ChordMatch_Hit("Space", "Space"))
    T.True(ChordMatch_Hit("F5", "F5"))
    T.True(ChordMatch_Hit("+", "+"))
}

T.Test("ChordMatch: ? matches any single character key", ChordMatch_Any)
ChordMatch_Any() {
    for text in ["a", "9", ";"]
        T.True(ChordMatch_Hit("?", text), text)
    for text in ["F1", "PgUp", "Space"]
        T.True(!ChordMatch_Hit("?", text), text)
}

T.Test("ChordMatch: globs match named keys only", ChordMatch_Glob)
ChordMatch_Glob() {
    T.True(ChordMatch_Hit("F*", "F1"))
    T.True(ChordMatch_Hit("F*", "F12"))
    T.True(!ChordMatch_Hit("F*", "f"), "letter F")
    T.True(ChordMatch_Hit("*PgUp", "PgUp"))
    T.True(ChordMatch_Hit("Num*", "Numpad1"))
}

T.Test("ChordMatch: ranges by character code, with modifiers", ChordMatch_Range)
ChordMatch_Range() {
    T.True(ChordMatch_Hit("a-f", "c"))
    T.True(!ChordMatch_Hit("a-f", "g"))
    T.True(ChordMatch_Hit("1-9", "5"))
    T.True(!ChordMatch_Hit("1-9", "0"))
    T.True(ChordMatch_Hit(":-@", ";"))
    T.True(ChordMatch_Hit("^a-f", "Ctrl+B"))
    T.True(!ChordMatch_Hit("^a-f", "b"))
}

T.Test("ChordMatch: unknown key names throw", ChordMatch_Unknown)
ChordMatch_Unknown() {
    T.Throws(() => LegendChordMatch.Parse("Entr"))
    T.Throws(() => LegendChordMatch.Parse("zz"))
}

T.Test("ChordMatch: display per style", ChordMatch_Display)
ChordMatch_Display() {
    T.Eq(LegendChordMatch.Parse("z").Display(), "z")
    T.Eq(LegendChordMatch.Parse("^s").Display("text"), "Ctrl+S")
    T.Eq(LegendChordMatch.Parse("^s").Display("symbols"), "⌃S")
    T.Eq(LegendChordMatch.Parse("^s").Display("ahk"), "^s")
    T.Eq(LegendChordMatch.Parse("1-9").Display(), "1–9")
    T.Eq(LegendChordMatch.Parse("^a-f").Display("symbols"), "⌃a–f")
    T.Eq(LegendChordMatch.Parse("Space").Display(), "Space")
    T.Eq(LegendChordMatch.Parse("F*").Display(), "F*")
    T.Eq(LegendChordMatch.Parse("?").Display(), "?")
}
```

Add to `tests/Legend.Tests.ahk` above `T.Finish()`:
```ahk
#Include %A_ScriptDir%\..\src\ChordMatch.ahk
#Include %A_ScriptDir%\ChordMatch.Tests.ahk
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: non-zero exit; cannot open `src\ChordMatch.ahk`.

- [ ] **Step 3: Implement `src/ChordMatch.ahk`**
```ahk
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
        modSet := Map(), i := 1
        while i < StrLen(text) && LegendKeyName.AhkMods.Has(ch := SubStr(text, i, 1)) {
            modSet[LegendKeyName.AhkMods[ch]] := true
            i += 1
        }
        body := SubStr(text, i)
        p := LegendChordPattern()
        p.Text := text, p.Mods := LegendKeyName.Ordered(modSet), p.Body := body
        p.Name := "", p.Lo := "", p.Hi := "", p.Regex := ""
        if body = "?" {
            p.Kind := "any"
        } else if StrLen(body) = 3 && SubStr(body, 2, 1) = "-" && Ord(SubStr(body, 1, 1)) <= Ord(SubStr(body, 3, 1)) {
            p.Kind := "range", p.Lo := StrLower(SubStr(body, 1, 1)), p.Hi := StrLower(SubStr(body, 3, 1))
        } else if StrLen(body) > 1 && InStr(body, "*") {
            p.Kind := "glob"
            p.Regex := "i)^" StrReplace(RegExReplace(body, "[\\.^$|?+()\[\]{}]", "\$0"), "*", ".*") "$"
        } else {
            name := LegendKeyName.NormalizeName(body)
            if name = ""
                throw ValueError("unknown chord key '" text "'", -2)
            p.Kind := "key", p.Name := name
        }
        return p
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
        for i, m in a
            if m != b[i]
                return false
        return true
    }
}
```

Add to `Legend.ahk` after `#Include %A_LineFile%\..\src\KeyWatch.ahk`:
```ahk
#Include %A_LineFile%\..\src\ChordMatch.ahk
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `83 passed, 0 failed`, validate lines ok.

- [ ] **Step 5: Commit**
```bash
git add src/ChordMatch.ahk tests/ChordMatch.Tests.ahk tests/Legend.Tests.ahk Legend.ahk
git commit -m "ChordMatch: KeyChord-compatible key patterns"
```

---

### Task 3: Chord items, lookup and held modifiers

**Files:**
- Create: `src/Chord.ahk`, `tests/Chord.Tests.ahk`
- Modify: `tests/Legend.Tests.ahk`, `Legend.ahk` (include after `ChordMatch.ahk`)

**Interfaces:**
- Consumes: `LegendChordMatch.Parse/Matches`, `LegendKeyWatch.ModVks`, `LegendKeyName.FromParts`.
- Produces:
  - `LegendChordItem(key, label, action := "", items := "", options := "")`: properties `Key, Label, Action, Items, Pattern, If, Status, Hint`; `IsMenu`; `Enabled()`; `StatusNow() → true | false | ""`; `Run(keyName)`.
  - `LegendChord(hotkey, title, items, options := "")`: `Hotkey, Title, Items, Match, Reference`.
  - `LegendChords.Find(items, key) → item | ""`; `LegendChords.Visible(items) → Array`.
  - `LegendChordKeys(heldVks := [])`: `Down(vk) → Boolean` (true = modifier), `Up(vk)`, `Key(keyName) → LegendKey`.

- [ ] **Step 1: Write the failing tests** — `tests/Chord.Tests.ahk`:
```ahk
#Requires AutoHotkey v2.0

Chord_Key(text) => LegendKeyName.FromText(text)

T.Test("Chord: first item whose If holds wins", Chord_Find)
Chord_Find() {
    active := false
    items := [LegendChordItem("t", "Terminal", Noop, "", {If: () => active}),
              LegendChordItem("t", "TickTick", Noop)]
    T.Eq(LegendChords.Find(items, Chord_Key("t")).Label, "TickTick")
    active := true
    T.Eq(LegendChords.Find(items, Chord_Key("t")).Label, "Terminal")
    T.Eq(LegendChords.Find(items, Chord_Key("x")), "")
}

T.Test("Chord: visible items skip false If and duplicate keys", Chord_Visible)
Chord_Visible() {
    items := [LegendChordItem("t", "A", Noop, "", {If: () => false}),
              LegendChordItem("t", "B", Noop),
              LegendChordItem("t", "C", Noop),
              LegendChordItem("w", "R", "", [])]
    labels := ""
    for item in LegendChords.Visible(items)
        labels .= item.Label
    T.Eq(labels, "BR")
}

T.Test("Chord: actions get the key only when they take a parameter", Chord_RunArguments)
Chord_RunArguments() {
    got := []
    LegendChordItem("1-9", "digit", k => got.Push(k)).Run("5")
    LegendChordItem("a", "plain", () => got.Push("none")).Run("a")
    T.Eq(got[1], "5")
    T.Eq(got[2], "none")
}

T.Test("Chord: menus, status and unknown keys", Chord_ItemBasics)
Chord_ItemBasics() {
    T.True(LegendChordItem("w", "R", "", []).IsMenu)
    T.True(!LegendChordItem("z", "Z", Noop).IsMenu)
    T.Eq(LegendChordItem("z", "Z", Noop, "", {Status: () => 1}).StatusNow(), true)
    T.Eq(LegendChordItem("z", "Z", Noop, "", {Status: () => 0}).StatusNow(), false)
    T.Eq(LegendChordItem("z", "Z", Noop).StatusNow(), "")
    T.Throws(() => LegendChordItem("Entr", "x", Noop))
}

T.Test("Chord: modifiers held from the trigger are ignored until released", Chord_HeldModifiers)
Chord_HeldModifiers() {
    keys := LegendChordKeys([0x5B])          ; LWin still down from Win+Space
    T.Eq(keys.Key("z").Id, "Z")
    T.True(keys.Down(0x5B), "auto-repeat of the held Win is a modifier")
    T.Eq(keys.Key("z").Id, "Z", "still ignored while held")
    keys.Up(0x5B)
    keys.Down(0xA2)                          ; LCtrl pressed after opening
    T.Eq(keys.Key("s").Id, "Ctrl+S")
    T.True(!keys.Down(0x41), "A is not a modifier")
}
```

Add to `tests/Legend.Tests.ahk` above `T.Finish()`:
```ahk
#Include %A_ScriptDir%\..\src\Chord.ahk
#Include %A_ScriptDir%\Chord.Tests.ahk
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: non-zero exit; cannot open `src\Chord.ahk`.

- [ ] **Step 3: Implement `src/Chord.ahk`**
```ahk
#Requires AutoHotkey v2.0

; One chord menu item: a run (Action) or a submenu (Items).
class LegendChordItem {
    __New(key, label, action := "", items := "", options := "") {
        this.Key := key
        this.Label := label
        this.Action := action
        this.Items := items
        this.Pattern := LegendChordMatch.Parse(key)
        opt := name => IsObject(options) && options.HasOwnProp(name) ? options.%name% : ""
        this.If := opt("If"), this.Status := opt("Status"), this.Hint := opt("Hint")
    }

    IsMenu => IsObject(this.Items)

    Enabled() {
        if !IsObject(this.If)
            return true
        fn := this.If
        return fn()
    }

    ; true / false for items with a Status function, otherwise "".
    StatusNow() {
        if !IsObject(this.Status)
            return ""
        fn := this.Status
        return fn() ? true : false
    }

    ; Strings are sent; functions get the pressed key if they take a parameter.
    Run(keyName) {
        action := this.Action
        if !IsObject(action)
            return Send(action)
        if HasProp(action, "MaxParams") && (action.MaxParams >= 1 || action.IsVariadic)
            return action(keyName)
        return action()
    }
}

class LegendChord {
    __New(hotkey, title, items, options := "") {
        this.Hotkey := hotkey
        this.Title := title
        this.Items := items
        this.Match := IsObject(options) && options.HasOwnProp("Match") ? options.Match : ""
        this.Reference := IsObject(options) && options.HasOwnProp("Reference") ? options.Reference : true
    }
}

class LegendChords {
    ; The first item whose pattern matches key and whose If holds, or "".
    static Find(items, key) {
        for item in items
            if LegendChordMatch.Matches(item.Pattern, key) && item.Enabled()
                return item
        return ""
    }

    ; Items to show: If holds, and only the first such item per key pattern.
    static Visible(items) {
        seen := Map(), out := []
        for item in items {
            if !item.Enabled()
                continue
            id := item.Pattern.Display("text")
            if seen.Has(id)
                continue
            seen[id] := true
            out.Push(item)
        }
        return out
    }
}

; Tracks modifiers during a chord. Modifiers already down when the chord opened
; (the trigger's) are ignored until released, so Win+Space then z is plain z.
class LegendChordKeys {
    __New(heldVks := []) {
        this.Held := Map(), this.Stale := Map()
        for vk in heldVks
            if LegendKeyWatch.ModVks.Has(vk)
                this.Held[vk] := LegendKeyWatch.ModVks[vk], this.Stale[vk] := true
    }

    ; Returns true when vk is a modifier (tracked here, never a chord key).
    Down(vk) {
        if !LegendKeyWatch.ModVks.Has(vk)
            return false
        this.Held[vk] := LegendKeyWatch.ModVks[vk]
        return true
    }

    Up(vk) {
        if this.Held.Has(vk)
            this.Held.Delete(vk)
        if this.Stale.Has(vk)
            this.Stale.Delete(vk)
    }

    ; The pressed key with the modifiers pressed since the chord opened.
    Key(keyName) {
        mods := []
        for vk, name in this.Held
            if !this.Stale.Has(vk)
                mods.Push(name)
        return LegendKeyName.FromParts(mods, keyName)
    }
}
```

Add to `Legend.ahk` after the `ChordMatch.ahk` include:
```ahk
#Include %A_LineFile%\..\src\Chord.ahk
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `88 passed, 0 failed`, validate lines ok.

- [ ] **Step 5: Commit**
```bash
git add src/Chord.ahk tests/Chord.Tests.ahk tests/Legend.Tests.ahk Legend.ahk
git commit -m "Chord: items, first-true lookup, held-modifier filter"
```

---

### Task 4: Chords in the registry and reference pages

**Files:**
- Modify: `src/Registry.ahk`, `tests/Registry.Tests.ahk`

**Interfaces:**
- Consumes: `LegendChord`, `LegendChordItem`, `LegendKeyName.Sequence/FromHotkey`, existing `AddEntry`, `Page`, `Binder`.
- Produces: `LegendRegistry.Chords` (Array), `.ChordReference` (`""` until enabled); `AddChord(chord, open) → chord` (binds `chord.Hotkey` to `open` under `chord.Match`); `EnableChordReference(enabled)`; `AddChordPage(chord)`.

- [ ] **Step 1: Write the failing tests** — insert in `tests/Registry.Tests.ahk` above `T.Test("Registry: SortedPages skips empty pages", …)`:
```ahk
Registry_LaunchChord(options := "") => LegendChord("#Space", "Launch", [
    LegendChordItem("z", "Zed", Noop),
    LegendChordItem("w", "Research", "", [LegendChordItem("b", "Brave", Noop)]),
    LegendChordItem("t", "Terminal", Noop, "", {If: () => false, Hint: "in Explorer"})
], options)

Registry_Keys(category) {
    out := ""
    for e in category.Groups[1].Entries
        out .= LegendKeyName.Format(e.Key, "text") "=" e.Description ";"
    return out
}

T.Test("Registry: chord reference pages follow the tree", Registry_ChordPage)
Registry_ChordPage() {
    r := Registry_New()
    r.AddChord(Registry_LaunchChord({Match: "ahk_exe x.exe"}), Noop)
    T.Eq(r.BindLog[1].Hotkey, "#Space")
    T.Eq(r.BindLog[1].Match, "ahk_exe x.exe")
    T.Eq(r.SortedPages().Length, 0, "no pages before enabling")
    r.EnableChordReference(true)
    page := r.Page("Launch")
    T.Eq(page.Match, "ahk_exe x.exe")
    T.Eq(page.Categories[1].Name, "Launch")
    T.Eq(page.Categories[2].Name, "Launch › Research")
    T.Eq(Registry_Keys(page.Categories[1]),
        "Win+Space z=Zed;Win+Space w=Research ›;Win+Space t=Terminal (in Explorer);")
    T.Eq(Registry_Keys(page.Categories[2]), "Win+Space w b=Brave;")
    T.True(page.Categories[1].Groups[1].Entries[1].Bound)
}

T.Test("Registry: hidden chords make no pages", Registry_ChordHidden)
Registry_ChordHidden() {
    r := Registry_New()
    r.AddChord(Registry_LaunchChord({Reference: false}), Noop)
    r.EnableChordReference(true)
    T.Eq(r.SortedPages().Length, 0)
    r2 := Registry_New()
    r2.AddChord(Registry_LaunchChord(), Noop)
    r2.EnableChordReference(false)
    T.Eq(r2.SortedPages().Length, 0)
}

T.Test("Registry: chord entries join an existing page", Registry_ChordMerge)
Registry_ChordMerge() {
    r := Registry_New()
    r.Bind(["Launch", "Other"], "^q", "quit", Noop)
    r.EnableChordReference(true)
    r.AddChord(Registry_LaunchChord(), Noop)
    T.Eq(r.Pages.Length, 1)
    T.Eq(r.Page("Launch").Categories.Length, 3)
}

T.Test("Registry: chords added after enabling are paged once", Registry_ChordAfterEnable)
Registry_ChordAfterEnable() {
    r := Registry_New()
    r.AddChord(Registry_LaunchChord(), Noop)
    r.EnableChordReference(true)
    r.AddChord(LegendChord("#j", "Other", [LegendChordItem("a", "A", Noop)]), Noop)
    T.Eq(r.Page("Launch").Categories[1].Groups[1].Entries.Length, 3)
    T.Eq(r.Page("Other").Categories[1].Groups[1].Entries.Length, 1)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: the four new tests FAIL (no method `AddChord`).

- [ ] **Step 3: Implement** — in `src/Registry.ahk`, in `LegendRegistry.__New` add:
```ahk
        this.Chords := []
        this.ChordReference := ""   ; set by EnableChordReference (Legend.Start)
```
Add these methods to `LegendRegistry` (after `AddFile`):
```ahk
    ; Registers a chord: binds its trigger to open (under its Match) and, once the
    ; reference is enabled, adds its reference page.
    AddChord(chord, open) {
        binder := this.Binder
        binder(chord.Hotkey, open, chord.Match)
        this.Chords.Push(chord)
        if this.ChordReference = true
            this.AddChordPage(chord)
        return chord
    }

    ; Legend.Start calls this once with its ChordReference option.
    EnableChordReference(enabled) {
        this.ChordReference := enabled ? true : false
        if enabled
            for chord in this.Chords
                this.AddChordPage(chord)
    }

    AddChordPage(chord) {
        if !chord.Reference
            return
        page := this.Page(chord.Title)
        if chord.Match != "" && page.FileMatch = ""
            page.FileMatch := chord.Match   ; decides which page opens; never conditions hotkeys
        this.AddChordLevel(page, chord.Items, [LegendKeyName.FromHotkey(chord.Hotkey)], chord.Title)
    }

    ; One category per menu level: the level's items first, then each submenu.
    AddChordLevel(page, items, steps, category) {
        for item in items {
            path := steps.Clone()
            path.Push(item.Pattern)
            label := item.Label (item.IsMenu ? " ›" : "") (item.Hint != "" ? " (" item.Hint ")" : "")
            this.AddEntry(page, category, "", LegendKeyName.Sequence(path), label, true)
        }
        for item in items {
            if !item.IsMenu
                continue
            path := steps.Clone()
            path.Push(item.Pattern)
            this.AddChordLevel(page, item.Items, path, category " › " item.Label)
        }
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `92 passed, 0 failed`, validate lines ok.

- [ ] **Step 5: Commit**
```bash
git add src/Registry.ahk tests/Registry.Tests.ahk
git commit -m "Registry: chords and generated reference pages"
```

---

### Task 5: Chord rows, indicator colors and chord levels

**Files:**
- Modify: `src/Rows.ahk`, `src/Theme.ahk`, `themes/catppuccin-mocha.ini`, `themes/catppuccin-latte.ini`, `src/Navigator.ahk`, `tests/Rows.Tests.ahk`, `tests/Theme.Tests.ahk`, `tests/Navigator.Tests.ahk`

**Interfaces:**
- Consumes: `LegendChords.Visible/Find`, `LegendChordItem`, `LegendChord`.
- Produces: rows gain `Status` (`true | false | ""`); `LegendRows.Row(kind, key, text, style := "", mods := "", status := "")`; `LegendRows.ForChord(items, style)`; theme keys `indicatorOn`, `indicatorOff`; `LegendNavigator.Mode` (`"reference" | "chord"`), `OpenChord(chord)`, `PressChord(key) → "redraw" | "run" | "miss"`, `RunItem`; chord levels have `ChordItems`; `Footer` shows chord hints in chord mode.

- [ ] **Step 1: Write the failing tests**

Append to `tests/Rows.Tests.ahk`:
```ahk

T.Test("Rows: chord rows show key, label, submenu mark and status", Rows_Chord)
Rows_Chord() {
    items := [LegendChordItem("z", "Zed", Noop, "", {Status: () => true}),
              LegendChordItem("w", "Research", "", []),
              LegendChordItem("^s", "Save", Noop)]
    rows := LegendRows.ForChord(items, "symbols")
    T.Eq(rows[1].Key, "z")
    T.Eq(rows[1].Status, true)
    T.Eq(rows[2].Text, "Research ›")
    T.Eq(rows[2].Status, "")
    T.Eq(rows[3].Key, "⌃S")
    T.Eq(rows[3].Style, "bound")
}
```

Append to `tests/Theme.Tests.ahk`:
```ahk

T.Test("Theme: running-indicator colors", Theme_Indicators)
Theme_Indicators() {
    T.Eq(LegendTheme.Read("")["indicatorOn"], "A6E3A1")
    T.Eq(LegendTheme.Read("")["indicatorOff"], "45475A")
    latte := LegendTheme.Load("catppuccin-latte").Values
    T.Eq(latte["indicatorOn"], "40A02B")
    T.Eq(latte["indicatorOff"], "BCC0CC")
}
```

Append to `tests/Navigator.Tests.ahk`:
```ahk

Navigator_Chord() => LegendChord("#Space", "Launch", [
    LegendChordItem("z", "Zed", Noop),
    LegendChordItem("w", "Research", "", [LegendChordItem("b", "Brave", Noop)]),
    LegendChordItem("t", "Hidden", Noop, "", {If: () => false}),
    LegendChordItem("t", "Shown", Noop)
])

Navigator_ChordNav() {
    nav := LegendNavigator([], rows => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    nav.OpenChord(Navigator_Chord())
    return nav
}

T.Test("Navigator: chord levels show visible items", Navigator_ChordLevel)
Navigator_ChordLevel() {
    nav := Navigator_ChordNav()
    T.Eq(nav.Mode, "chord")
    T.Eq(nav.View.Title, "Launch")
    texts := ""
    for row in nav.View.Columns[1].Rows
        texts .= row.Key "=" row.Text ";"
    T.Eq(texts, "z=Zed;w=Research ›;t=Shown;")
    T.True(!nav.ClaimsLetters)
}

T.Test("Navigator: chord presses descend, run or miss", Navigator_ChordPress)
Navigator_ChordPress() {
    nav := Navigator_ChordNav()
    T.Eq(nav.PressChord(LegendKeyName.FromText("x")), "miss")
    T.Eq(nav.PressChord(LegendKeyName.FromText("w")), "redraw")
    T.Eq(nav.View.Title, "Launch › Research")
    T.Eq(nav.PressChord(LegendKeyName.FromText("b")), "run")
    T.Eq(nav.RunItem.Label, "Brave")
    T.Eq(nav.Press("Backspace"), "redraw")
    T.Eq(nav.View.Title, "Launch")
    T.Eq(nav.PressChord(LegendKeyName.FromText("t")), "run")
    T.Eq(nav.RunItem.Label, "Shown")
}

T.Test("Navigator: chord footer and relayout", Navigator_ChordFooter)
Navigator_ChordFooter() {
    nav := Navigator_ChordNav()
    nav.PressChord(LegendKeyName.FromText("w"))
    f := nav.Footer("tab text")
    T.True(InStr(f, "esc close") && InStr(f, "⌫ back") && InStr(f, "tab text"), f)
    T.True(!InStr(f, "pin"), f)
    nav.Relayout(rows => LegendLayout.Paginate(rows, FakeMeasure, 1000, 1), "ahk")
    T.Eq(nav.View.Title, "Launch › Research")
    T.Eq(nav.Stack.Length, 2)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: FAIL for `Rows: chord rows…`, `Theme: running-indicator colors`, and the three `Navigator: chord…` tests.

- [ ] **Step 3: Implement**

`src/Rows.ahk` — replace the `Row` helper and add `ForChord` (above `Row`):
```ahk
    ; Chord menu items (already filtered by LegendChords.Visible).
    static ForChord(items, style) {
        rows := []
        for item in items
            rows.Push(this.Row("entry", item.Pattern.Display(style), item.Label (item.IsMenu ? " ›" : ""),
                "bound", item.Pattern.Mods, item.StatusNow()))
        return rows
    }

    static Row(kind, key, text, style := "", mods := "", status := "") =>
        {Kind: kind, Key: key, Text: text, Style: style, Mods: IsObject(mods) ? mods : [], Status: status}
```
Also update the class comment's row shape to include `Status`.

`src/Theme.ahk` — add to `Schema` after the `warning` row:
```ahk
        ["colors", "indicatorOn", "color", "A6E3A1"],
        ["colors", "indicatorOff", "color", "45475A"],
```
`themes/catppuccin-mocha.ini` — after `warning=FAB387` add:
```ini
indicatorOn=A6E3A1
indicatorOff=45475A
```
`themes/catppuccin-latte.ini` — after `warning=FE640B` add:
```ini
indicatorOn=40A02B
indicatorOff=BCC0CC
```

`src/Navigator.ahk`:
- In `__New` add `this.Mode := "reference"` and `this.RunItem := ""`.
- Add after `Open(matches)`:
```ahk
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
```
- Add next to `CategoryLevel`:
```ahk
    ChordLevel(items, title) {
        return this.WithBuild({Title: title, Screens: this.Paginate(LegendRows.ForChord(LegendChords.Visible(items), this.Style)),
            ScreenIndex: 1, Items: [], ChordItems: items}, () => this.ChordLevel(items, title))
    }
```
- Replace `Footer(extras*) { … }` with:
```ahk
    ; extras: display hints (tab / = ).
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
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `97 passed, 0 failed`, validate lines ok.

- [ ] **Step 5: Commit**
```bash
git add src/Rows.ahk src/Theme.ahk src/Navigator.ahk themes tests
git commit -m "Chord rows, indicator colors and navigator chord levels"
```

---

### Task 6: Chord controller, status dot, Emacs keys, example and docs

**Files:**
- Modify: `src/KeyWatch.ahk`, `src/Overlay.ahk`, `Legend.ahk`, `tests/KeyWatch.Tests.ahk`, `tests/Overlay.Tests.ahk`, `examples/example.ahk`, `README.md`, `TODO.md`

**Interfaces:**
- Consumes: everything above.
- Produces (public): `Legend.Chord(hotkey, title, items, options := "")`, `Legend.Run(key, label, action, options := "")`, `Legend.Menu(key, label, items)`; `Legend.Start` options `ChordTimeout`, `ChordOverlay`, `ChordReference`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/KeyWatch.Tests.ahk`:
```ahk

T.Test("KeyWatch: claimed combos do not close", KeyWatch_ClaimedCombos)
KeyWatch_ClaimedCombos() {
    w := LegendKeyWatch(LegendKeyName.FromHotkey("!/").Id, ["``", "=", "Ctrl+N", "Ctrl+P", "Ctrl+G"])
    w.Down(0xA2, "LControl")
    T.Eq(w.Down(0x4E, "n"), "")
    T.Eq(w.Down(0x47, "g"), "")
    T.Eq(w.Down(0x53, "s"), "combo")
}
```

Append to `tests/Overlay.Tests.ahk`:
```ahk

T.Test("Overlay: a status dot widens the text column", Overlay_StatusWidth)
Overlay_StatusWidth() {
    m := LegendMeasurer(LegendTheme.Resolve(LegendTheme.Read("")))
    try {
        plain := m(LegendRows.Row("entry", "z", "Zed", "bound"))
        dotted := m(LegendRows.Row("entry", "z", "Zed", "bound", [], true))
        T.True(dotted.TextW > plain.TextW, dotted.TextW " vs " plain.TextW)
    } finally
        m.Destroy()
}
```

- [ ] **Step 2: Run to verify failure**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: FAIL `KeyWatch: claimed combos do not close` (first `T.Eq` gets `combo`) and FAIL `Overlay: a status dot widens the text column`.

- [ ] **Step 3: Implement KeyWatch and Overlay**

`src/KeyWatch.ahk` — in `Down`, replace
```ahk
        if combo
            return LegendKeyName.FromParts(mods, keyName).Id == this.HelpId ? "" : "combo"
```
with
```ahk
        if combo {
            id := LegendKeyName.FromParts(mods, keyName).Id
            return id == this.HelpId || this.Claimed.Has(id) ? "" : "combo"
        }
```
and update the constructor comment to: `; claimed: keys the overlay handles itself while open — single characters ("=") or combo ids ("Ctrl+N").`

`src/Overlay.ahk`:
- In `LegendMeasurer.Call`, replace the entry branch with:
```ahk
        if row.Kind = "entry" {
            key := this.Size(row.Key, "key"), text := this.Size(row.Text, "body")
            textW := text.W + (row.Status != "" ? this.Size("● ", "body").W : 0)
            return {KeyW: key.W, TextW: textW, H: Max(key.H, text.H) + spacing}
        }
```
- In `LegendOverlay.Show`, replace the default (entry) branch's description line
```ahk
                        this.AddText(g, theme, "body", theme["description"], "x" (x + col.KeyWidth + pad) " y" y, row.Text)
```
with
```ahk
                        textX := x + col.KeyWidth + pad
                        if row.Status != "" {
                            this.AddText(g, theme, "body", row.Status ? theme["indicatorOn"] : theme["indicatorOff"], "x" textX " y" y, "●")
                            textX += measurer.Size("● ", "body").W
                        }
                        this.AddText(g, theme, "body", theme["description"], "x" textX " y" y, row.Text)
```

- [ ] **Step 4: Run to verify pass**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `99 passed, 0 failed`.

- [ ] **Step 5: Implement the facade** — `Legend.ahk`:

Static fields, after `static Styles := …`:
```ahk
    static DefaultOptions := {HelpKey: "!/", Pages: [], Themes: [], Theme: "auto",
        ChordTimeout: 0, ChordOverlay: 400, ChordReference: true}
    static ChordState := ""
```
Public chord API, after `static Doc(…)`:
```ahk
    static Run(key, label, action, options := "") => LegendChordItem(key, label, action, "", options)
    static Menu(key, label, items) => LegendChordItem(key, label, "", items)
    static Chord(hotkey, title, items, options := "") {
        chord := LegendChord(hotkey, title, items, options)
        return this.Registry.AddChord(chord, (*) => Legend.OpenChord(chord))
    }

    ; An option from Start, or its default when Start has not run.
    static Opt(name) => IsObject(this.Options) ? this.Options.%name% : this.DefaultOptions.%name%
```
In `Start`, replace the two lines that build `this.Options` (the `get := …` lambda and the `this.Options := {…}` assignment) with:
```ahk
        this.Options := {}
        for name, fallback in this.DefaultOptions.OwnProps()
            this.Options.%name% := options.HasOwnProp(name) ? options.%name% : fallback
```
In `Start`, after the page-file loop add:
```ahk
        this.Registry.EnableChordReference(this.Options.ChordReference)
```
In `Start`, before the final `HotIf()` add:
```ahk
        HotIf((*) => Legend.Visible && !Legend.Nav.Pinned)
        for key, action in Map("^n", "Next", "^p", "Prev", "^g", "Close")
            Hotkey(key, this.Handler(action))
```
Replace the first three lines of `Open()` (theme loading) with a call to a new helper, and add the helper:
```ahk
    static Open() {
        if this.ChordState
            this.CloseChord()
        this.LoadTheme()
        paginate := this.ApplyDisplay()
        theme := this.Theme
```
```ahk
    static LoadTheme() {
        loaded := LegendTheme.Load(this.Opt("Theme"), this.Opt("Themes"))
        this.BaseTheme := loaded.Values
        this.ThemeWarnings := loaded.Warnings
    }
```
(the rest of `Open()` is unchanged).

In `StartWatching`, change the key watcher line to:
```ahk
        this.Keys := LegendKeyWatch(this.HelpId, ["``", "=", "Ctrl+N", "Ctrl+P", "Ctrl+G"])
```

Add the chord controller (new methods at the end of the class):
```ahk
    ; ---- Chord mode ----

    static OpenChord(chord) {
        if this.ChordState
            return this.CloseChord()          ; trigger again closes
        if this.Visible
            this.Close()
        this.LoadTheme()
        paginate := this.ApplyDisplay()
        this.Nav := LegendNavigator([], paginate, this.Theme["keyStyle"])
        this.Nav.OpenChord(chord)
        held := []
        for vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
            if GetKeyState(Format("vk{:X}", vk), "P")
                held.Push(vk)
        state := this.ChordState := {Chord: chord, Keys: LegendChordKeys(held), Shown: false,
            TriggerId: LegendKeyName.FromHotkey(chord.Hotkey).Id, Timers: Map()}
        ih := state.Hook := InputHook("L0")
        ih.KeyOpt("{All}", "+SN")
        ih.KeyOpt("{LWin}{RWin}{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}", "-S")
        ih.OnKeyDown := (hook, vk, sc) => Legend.ChordKeyDown(vk, sc)
        ih.OnKeyUp := (hook, vk, sc) => Legend.ChordKeyUp(vk)
        ih.Start()
        this.ActiveHwnd := WinExist("A")
        this.ChordTimer("Focus", () => Legend.CheckChordFocus(), 150)
        delay := this.Opt("ChordOverlay")
        if delay = "always"
            this.ShowChord()
        else if IsNumber(delay)
            this.ChordTimer("Show", () => Legend.ShowChord(), -Max(1, Integer(delay)))
        this.RestartChordTimeout()
    }

    static ChordTimer(name, fn, period) {
        timers := this.ChordState.Timers
        if timers.Has(name)
            SetTimer(timers[name], 0)
        timers[name] := fn
        SetTimer(fn, period)
    }

    static RestartChordTimeout() {
        seconds := this.Opt("ChordTimeout")
        if IsNumber(seconds) && seconds > 0
            this.ChordTimer("Timeout", () => Legend.CloseChord(), -Integer(seconds * 1000))
    }

    static ShowChord() {
        state := this.ChordState
        if !state || state.Shown
            return
        state.Shown := true
        this.Draw()
    }

    static CheckChordFocus() {
        if this.ChordState && WinExist("A") != this.ActiveHwnd
            this.CloseChord()
    }

    static ChordKeyUp(vk) {
        if this.ChordState
            this.ChordState.Keys.Up(vk)
    }

    ; Hook callback: track modifiers here, handle real keys on the script thread.
    static ChordKeyDown(vk, sc) {
        state := this.ChordState
        if !state || LegendKeyWatch.IgnoredVks.Has(vk) || state.Keys.Down(vk)
            return
        name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
        key := state.Keys.Key(name)
        SetTimer(() => Legend.ChordKey(key, name), -1)
    }

    static ChordKey(key, name) {
        static overlayKeys := Map("PgDn", "Next", "Ctrl+N", "Next", "PgUp", "Prev", "Ctrl+P", "Prev",
            "Tab", "Style", "=", "Density")
        state := this.ChordState
        if !state
            return
        id := key.Id
        if id == "Esc" || id == "Ctrl+G" || id == state.TriggerId
            return this.CloseChord()
        if id == "Backspace" {
            if this.Nav.Stack.Length = 1
                return this.CloseChord()
            this.Nav.Press("Backspace")
            return this.AfterChordStep()
        }
        if state.Shown && overlayKeys.Has(id) && !LegendChords.Find(this.Nav.Level.ChordItems, key) {
            action := overlayKeys[id]
            if action = "Style" || action = "Density"
                this.ChangeDisplay(action)
            else if this.Nav.Press(action) = "redraw"
                this.Draw()
            return this.RestartChordTimeout()
        }
        switch this.Nav.PressChord(key) {
            case "redraw":
                this.AfterChordStep()
            case "run":
                item := this.Nav.RunItem
                this.CloseChord()
                item.Run(name)
            default:
                shown := key.Verbatim != "" ? key.Verbatim
                    : !key.Mods.Length && StrLen(key.Name) = 1 ? StrLower(key.Name)
                    : LegendKeyName.Format(key, this.Theme["keyStyle"])
                this.CloseChord()
                ToolTip("Nothing on " shown)
                SetTimer(() => ToolTip(), -1000)
        }
    }

    static AfterChordStep() {
        if this.ChordState.Shown
            this.Draw()
        this.RestartChordTimeout()
    }

    static CloseChord() {
        state := this.ChordState
        if !state
            return
        this.ChordState := ""
        state.Hook.Stop()
        for name, fn in state.Timers
            SetTimer(fn, 0)
        if this.Gui
            this.Gui.Destroy(), this.Gui := ""
        if this.Measurer
            this.Measurer.Destroy(), this.Measurer := ""
    }
```

- [ ] **Step 6: Run tests and validation**

Run: `pwsh -NoProfile -File tests/Run-Tests.ps1`
Expected: `99 passed, 0 failed`, `validate Legend.ahk ok`, `validate examples\example.ahk ok`.

- [ ] **Step 7: Example, README, backlog**

`examples/example.ahk` — before `Legend.Start(…)` add:
```ahk
; Ctrl+Alt+Shift+Space: a chord menu (appears after 400 ms unless you type the keys first).
Legend.Chord("^!+Space", "Demo chords", [
    Legend.Run("n", "Notepad", (*) => Run("notepad.exe"), {Status: () => WinExist("ahk_exe notepad.exe")}),
    Legend.Menu("t", "Text", [
        Legend.Run("d", "Type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))),
        Legend.Run("s", "Type a sign-off", "Thanks,{Enter}Me")
    ]),
    Legend.Run("1-3", "Show a digit", key => MsgBox("You pressed " key))
])
```

`README.md` — add a section before `## Page files`:
~~~~markdown
## Chords

```ahk
Legend.Chord("#Space", "Launch", [
    Legend.Run("z", "Zed", (*) => Run("zed"), {Status: () => WinExist("ahk_exe Zed.exe")}),
    Legend.Menu("w", "Web", [Legend.Run("b", "Brave", (*) => Run("brave"))]),
    Legend.Run("s", "Sign-off", "Regards,{Enter}Me"),                 ; sent as keys
    Legend.Run("1-9", "Workspace", key => FocusWorkspace(key))         ; wildcard gets the key
])
```

Press the trigger, then keys. The menu appears after `ChordOverlay` ms (default
400; `"always"` / `"never"`); Esc or Ctrl+G cancels, Backspace goes up a level,
PgDn/PgUp or Ctrl+N/Ctrl+P page. Options per item: `If` (condition; the first
matching item whose `If` holds runs), `Status` (running dot), `Hint`. Keys may
use modifiers (`^s`) and KeyChord wildcards (`?`, `F*`, `a-f`). `Start` options:
`ChordTimeout` (seconds, 0 = none), `ChordOverlay`, `ChordReference` (chords
appear as pages in Alt+/ unless `false`).
~~~~

`TODO.md` — replace the chord-mode line with:
```markdown
- **Chord mode** shipped (docs/specs/2026-09-28-chord-mode-design.md); next:
  migrate the dotfiles' Win+Space menu and drop KeyChord.
```

- [ ] **Step 8: Manual smoke (PowerShell only; `examples/example.ahk`)**

Launch: `Start-Process "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" -ArgumentList "`"$PWD\examples\example.ahk`""` (it replaces nothing else; `#SingleInstance Force`). Check, then exit it from the tray:
- Ctrl+Alt+Shift+Space, then `n` quickly → Notepad opens, no menu flicker.
- Ctrl+Alt+Shift+Space and wait → menu after ~400 ms; Notepad row has a green dot while Notepad runs.
- `t` → Text submenu; Backspace → back; Esc and Ctrl+G close; trigger again closes.
- `2` → message "You pressed 2".
- `q` → "Nothing on q" tooltip.
- Open the menu, click another window → menu closes, next key goes to that window.
- With the menu shown: Tab cycles notation, `=` flips density.
- Alt+/ → index lists "Demo chords"; its page shows `Ctrl+Alt+Shift+Space n  Notepad` etc.
- In the Alt+/ overlay: Ctrl+N/Ctrl+P page (if multi-screen), Ctrl+G closes; pinned, Ctrl+N reaches the app.

- [ ] **Step 9: Commit**
```hbash
git add src/KeyWatch.ahk src/Overlay.ahk Legend.ahk tests examples README.md TODO.md
git commit -m "Chord mode: controller, status dots, Emacs keys, example"
```
