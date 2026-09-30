# Legend Key Scheme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One set of navigation keys for every Legend overlay: Ctrl+N/P and ↓/↑ move a cursor, Ctrl+F/B (plus PgDn/PgUp, Space in Alt+/) change screens, Enter opens or picks, Ctrl+T changes a picker's scope. Alt+/ menus get a cursor.

**Architecture:** `LegendNavigator` menu levels gain a `Cursor` (items and menu rows are 1:1), with `Down`/`Up`/`Enter` actions and footers in the shared wording; `LegendRows` rows carry `Selected`, which `LegendOverlay.Show` draws as a selection bar. The key maps in `Legend.ahk` move into static maps (testable) with the new bindings; `LegendPicker` adds Ctrl+F/B and Ctrl+T and rewrites its footer.

**Tech Stack:** AutoHotkey v2.0, PowerShell 7 test runner.

**Spec:** `docs/specs/2026-09-30-key-scheme-design.md`

## Global Constraints

- Every `.ahk` file starts with `#Requires AutoHotkey v2.0`; library classes start with `Legend`.
- **Never launch AutoHotkey from the Bash tool.** Tests: `pwsh -NoProfile -File tests/Run-Tests.ps1` from the PowerShell tool (exit code = failures).
- Locals must not shadow built-ins (`min`, `max`, `mod`, `hotkey`, `t`…) or the WarnHost fixture's globals (`a`–`z`, `id`, `fn`, `app`, `pad`, `out`, `ch`, `vk`, `sc`, `cx`, `cy`, `wx`, `wy`, `ww`, `wh`, `lh`, `th`, `ty`, `bgr`, `rgb`, `ih`).
- Stored functions are called through a local (`open := level.OpenItem`, `open(item)`).
- Footer wording (spec, exact): Alt+/ menu `↵ open · ^n/^p move · ^f/^b 2/3 · ⌫ back · \` pin · … · esc close`; flat page `^f/^b 2/3 · ⌫ back · \` pin · … · esc close`; chord `esc close · ⌫ back · ^f/^b 1/2 · …`; picker `↵ pick · ^n/^p move · / filter · ^t scope · = density · esc close`. Parts are joined with `   ·   ` as today; the screen counter only when there is more than one screen.
- Pickers keep j/k, h/l and trigger/Shift+trigger working but never mention them in footers or docs.
- Commits are GPG-signed; on `gpg: signing failed: Timeout` ask the user to run `! 'unlock' | gpg --clearsign | Out-Null`. Never bypass signing. Messages end with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01EGM256u2YUxjGNbwDZaxaK`
- Work on branch `keys` in `C:\Users\simsr\projects\Legend`. No pushes without the user's go-ahead.

## Review Focus

1. Pinned Alt+/: Enter, ↓/↑ and Ctrl+N/P/F/B must reach the app (the pin exists so the user can work in the app). Pinned by the key maps in Task 3 (`Legend_KeyMaps` asserts Down/Up/Enter live in the menu-and-not-pinned map) and checked by hand in Task 3 Step 7.
2. On a flat Alt+/ page, Enter must reach the app (nothing to open). Same map test (menu keys only claimed while a menu level is shown) + hand check.
3. A chord that binds Ctrl+F keeps it (items match before overlay keys). Hand check in Task 3 Step 7 with the example's chord.
4. Tab / `=` keep the cursor on the same item. Task 1 `Navigator_CursorRelayout`.
5. Multi-screen menus: Ctrl+N past a screen's last item shows the next screen. Task 1 `Navigator_CursorFollowsScreen`.

---

### Task 1: Navigator cursor

**Files:**
- Modify: `src/Navigator.ahk`, `src/Rows.ahk`
- Test: `tests/Navigator.Tests.ahk`, `tests/Rows.Tests.ahk`

**Interfaces:**
- Produces: level property `Cursor` (0 on levels without a cursor; ≥1 on menu levels); `LegendNavigator.Press("Down" | "Up" | "Enter")` → `"redraw"` or `"none"`; `Press("Next" | "Prev")` also moves the cursor to the new screen's first item; view rows have `Selected` (true on the cursor's row); `LegendRows.Row(...)` rows have `Selected: false`.

- [ ] **Step 1: Branch**

```bash
cd /c/Users/simsr/projects/Legend && git checkout -b keys
```

- [ ] **Step 2: Write the failing tests** — append to `tests/Navigator.Tests.ahk`:

```ahk
; Seven one-entry pages: the index has 7 items, 5 per screen (FakeMeasure rows are 20 px).
Navigator_Many() {
    r := Registry_New()
    loop 7
        r.Bind(["Page " A_Index, "c"], "^!F" A_Index, "x", Noop)
    nav := LegendNavigator(r.SortedPages(), rows => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    nav.Open([])
    return nav
}

T.Test("Navigator: the menu cursor starts on the first item and wraps", Navigator_CursorWraps)
Navigator_CursorWraps() {
    nav := Navigator_Many()
    T.Eq(nav.Level.Cursor, 1)
    T.Eq(nav.Press("Up"), "redraw")
    T.Eq(nav.Level.Cursor, 7)
    T.Eq(nav.View.ScreenIndex, 2)
    nav.Press("Down")
    T.Eq(nav.Level.Cursor, 1)
    T.Eq(nav.View.ScreenIndex, 1)
}

T.Test("Navigator: the screen follows the cursor; paging moves it to the screen's first item", Navigator_CursorFollowsScreen)
Navigator_CursorFollowsScreen() {
    nav := Navigator_Many()
    loop 5
        nav.Press("Down")
    T.Eq(nav.Level.Cursor, 6)
    T.Eq(nav.View.ScreenIndex, 2)
    nav.Press("Prev")
    T.Eq(nav.View.ScreenIndex, 1)
    T.Eq(nav.Level.Cursor, 1)
    nav.Press("Next")
    T.Eq(nav.Level.Cursor, 6)
}

T.Test("Navigator: Enter opens the selected item and the view marks it", Navigator_CursorEnter)
Navigator_CursorEnter() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("Down")
    rows := nav.View.Columns[1].Rows
    T.True(!rows[1].Selected)
    T.True(rows[2].Selected)
    T.Eq(nav.Press("Enter"), "redraw")
    T.Eq(nav.View.Title, "Zen")
}

T.Test("Navigator: Backspace returns with the cursor on the first item", Navigator_CursorBack)
Navigator_CursorBack() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("k")
    nav.Press("Down"), nav.Press("Down")
    T.Eq(nav.Level.Cursor, 3)
    nav.Press("r")
    nav.Press("Backspace")
    T.Eq(nav.View.Title, "komorebi")
    T.Eq(nav.Level.Cursor, 1)
}

T.Test("Navigator: flat pages ignore Down, Up and Enter", Navigator_CursorFlat)
Navigator_CursorFlat() {
    nav := Navigator_New()
    nav.Open([])
    nav.Press("z")
    T.Eq(nav.Level.Cursor, 0)
    T.Eq(nav.Press("Down"), "none")
    T.Eq(nav.Press("Up"), "none")
    T.Eq(nav.Press("Enter"), "none")
}

T.Test("Navigator: relayout keeps the selected item", Navigator_CursorRelayout)
Navigator_CursorRelayout() {
    nav := Navigator_Many()
    loop 5
        nav.Press("Down")
    nav.Relayout(rows => LegendLayout.Paginate(rows, FakeMeasure, 10000, 1), "text")
    T.Eq(nav.Level.Cursor, 6)
    T.Eq(nav.View.ScreenIndex, 1)
}
```

Append to `tests/Rows.Tests.ahk`:

```ahk
T.Test("Rows: rows start unselected", Rows_Selected)
Rows_Selected() {
    T.Eq(LegendRows.Row("entry", "a", "b").Selected, false)
}
```

- [ ] **Step 3: Run; expect FAIL** — `pwsh -NoProfile -File tests/Run-Tests.ps1` → the new tests fail (`Cursor` / `Selected` missing).

- [ ] **Step 4: Implement**

`src/Rows.ahk`, `Row`:

```ahk
    static Row(kind, key, text, style := "", mods := "", status := "") =>
        {Kind: kind, Key: key, Text: text, Style: style, Mods: IsObject(mods) ? mods : [], Status: status, Selected: false}
```

`src/Navigator.ahk`:

1. `View` marks the cursor's row:

```ahk
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
                ScreenIndex: level.ScreenIndex, ScreenCount: level.Screens.Length}
        }
    }
```

2. In `Press`, extend the switch (before `case "Pin":`):

```ahk
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
```

and in the existing `Next` / `Prev` cases, after the `level.ScreenIndex` change and before `return "redraw"`:

```ahk
                if level.Cursor
                    level.Cursor := this.FirstItemOf(level, level.ScreenIndex)
```

and in `Backspace`, after `this.Stack.Pop()`:

```ahk
                back := this.Level
                if back.Cursor
                    back.Cursor := 1, back.ScreenIndex := 1
```

3. In `Relayout`, after `fresh.ScreenIndex := Min(...)`:

```ahk
            if fresh.Cursor && level.Cursor {
                fresh.Cursor := Min(level.Cursor, fresh.Items.Length)
                fresh.ScreenIndex := this.ScreenOf(fresh, fresh.Cursor)
            }
```

4. Levels get `Cursor`: `MenuLevel` returns `Cursor: items.Length ? 1 : 0`; the literals in `PageLevel` (flat case), `ChordLevel` and `CategoryLevel` get `Cursor: 0`.

5. Helpers (after `Paginate`):

```ahk
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
```

- [ ] **Step 5: Run; expect PASS** (all tests, validations ok).

- [ ] **Step 6: Commit** — `git add src/Navigator.ahk src/Rows.ahk tests/Navigator.Tests.ahk tests/Rows.Tests.ahk`; message "Navigator: a cursor on menu levels".

---

### Task 2: Navigator footers in the shared wording

**Files:**
- Modify: `src/Navigator.ahk` (`Footer`)
- Test: `tests/Navigator.Tests.ahk` (update `Navigator_Footer`, add `Navigator_FooterKeys`)

**Interfaces:**
- Consumes: Task 1 `level.Cursor`.
- Produces: `Footer(extras*)` text per the Global Constraints.

- [ ] **Step 1: Tests** — in `Navigator_Footer`, replace `T.True(InStr(nav.Footer(), "a–z open"))` with `T.True(InStr(nav.Footer(), "↵ open"))`. Append:

```ahk
T.Test("Navigator: footers use the shared key names", Navigator_FooterKeys)
Navigator_FooterKeys() {
    nav := Navigator_Many()
    f := nav.Footer()
    T.True(InStr(f, "↵ open   ·   ^n/^p move   ·   ^f/^b 1/2"), f)
    T.True(!InStr(f, "spc/") && !InStr(f, "a–z"), f)
    nav.Press("Enter")
    f := nav.Footer()
    T.True(!InStr(f, "↵ open") && !InStr(f, "^n/^p"), f)
    chord := LegendNavigator([], rows => LegendLayout.Paginate(rows, FakeMeasure, 100, 1))
    items := []
    loop 7
        items.Push(LegendChordItem(Chr(96 + A_Index), "item " A_Index, Noop))
    chord.OpenChord(LegendChord("#Space", "Many", items))
    f := chord.Footer()
    T.True(InStr(f, "esc close   ·   ⌫ back   ·   ^f/^b 1/2"), f)
}
```

- [ ] **Step 2: Run; expect FAIL** (`↵ open` missing).

- [ ] **Step 3: Implement** — replace `Footer`:

```ahk
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
```

- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** — "Navigator: footers in the shared key wording".

---

### Task 3: Key maps and the selection bar in Alt+/

**Files:**
- Modify: `Legend.ahk` (`Start` key maps, `StartWatching` claims, `ChordKey` overlay keys)
- Modify: `src/Overlay.ahk` (`Show` draws a selected row)
- Test: `tests/Controller.Tests.ahk`

**Interfaces:**
- Consumes: Task 1 `Press("Down"|"Up"|"Enter")`, `row.Selected`.
- Produces: `Legend.OverlayKeys` (always while visible), `Legend.CtrlKeys` (visible and not pinned), `Legend.MenuKeys` (a menu level shown and not pinned), `Legend.WatchClaims` (array), `Legend.ChordOverlayKeys` (Map key id → action).

- [ ] **Step 1: Failing test** — append to `tests/Controller.Tests.ahk`:

```ahk
T.Test("Legend: key maps follow the shared scheme", Legend_KeyMaps)
Legend_KeyMaps() {
    T.Eq(Legend.CtrlKeys["^n"], "Down")
    T.Eq(Legend.CtrlKeys["^p"], "Up")
    T.Eq(Legend.CtrlKeys["^f"], "Next")
    T.Eq(Legend.CtrlKeys["^b"], "Prev")
    T.Eq(Legend.MenuKeys["Enter"], "Enter")
    T.Eq(Legend.MenuKeys["Down"], "Down")
    T.Eq(Legend.OverlayKeys["Space"], "Next")
    T.True(!Legend.OverlayKeys.Has("Enter") && !Legend.OverlayKeys.Has("Down"), "never claimed on flat pages or while pinned")
    T.Eq(Legend.ChordOverlayKeys["Ctrl+F"], "Next")
    T.Eq(Legend.ChordOverlayKeys["Ctrl+B"], "Prev")
    T.True(!Legend.ChordOverlayKeys.Has("Ctrl+N") && !Legend.ChordOverlayKeys.Has("Ctrl+P"), "Ctrl+N/P reach chord items")
    w := LegendKeyWatch(LegendKeyName.FromHotkey("!/").Id, Legend.WatchClaims)
    w.Down(0xA2, "LControl")
    T.Eq(w.Down(0x46, "f"), "", "Ctrl+F doesn't close the overlay")
    T.Eq(w.Down(0x42, "b"), "")
}
```

- [ ] **Step 2: Run; expect FAIL** (`CtrlKeys` missing).

- [ ] **Step 3: Implement the maps** — in `class Legend`, next to the other statics:

```ahk
    ; Reference-mode keys (see docs/specs/2026-09-30-key-scheme-design.md).
    static OverlayKeys := Map("Esc", "Close", "Backspace", "Backspace", "Space", "Next",
        "PgDn", "Next", "PgUp", "Prev", "``", "Pin", "Tab", "Style", "=", "Density")
    static CtrlKeys := Map("^n", "Down", "^p", "Up", "^f", "Next", "^b", "Prev", "^g", "Close")
    static MenuKeys := Map("Down", "Down", "Up", "Up", "Enter", "Enter")
    static WatchClaims := ["``", "=", "Ctrl+N", "Ctrl+P", "Ctrl+F", "Ctrl+B", "Ctrl+G"]
    static ChordOverlayKeys := Map("PgDn", "Next", "Ctrl+F", "Next", "PgUp", "Prev", "Ctrl+B", "Prev",
        "Tab", "Style", "=", "Density")
```

In `Start`, replace the three hotkey loops after `Hotkey(this.Options.HelpKey, …)` with:

```ahk
        HotIf((*) => Legend.Visible)
        for key, action in this.OverlayKeys
            Hotkey(key, this.Handler(action))
        HotIf((*) => Legend.ClaimsLetters)
        for char in StrSplit("abcdefghijklmnopqrstuvwxyz0123456789")
            Hotkey(char, this.Handler(char))
        HotIf((*) => Legend.Visible && !Legend.Nav.Pinned)   ; pinned: they reach the app
        for key, action in this.CtrlKeys
            Hotkey(key, this.Handler(action))
        HotIf((*) => Legend.ClaimsLetters && !Legend.Nav.Pinned)   ; a menu is shown
        for key, action in this.MenuKeys
            Hotkey(key, this.Handler(action))
        HotIf()
```

In `StartWatching`: `this.Keys := LegendKeyWatch(this.HelpId, this.WatchClaims)`.

In `ChordKey`, delete the local `static overlayKeys := Map(...)` (two lines) and replace its two uses with `this.ChordOverlayKeys`.

- [ ] **Step 4: Selection bar in `LegendOverlay.Show`** — in the `default:` branch of the row loop, before the key text is added:

```ahk
                        selected := row.Selected
                        if selected
                            overlay.AddProgress("x" (colX - spacing) " y" rowY " w" (col.Width + spacing * 2) " h" size.H
                                " Background" theme["selection"] " Disabled")
                        trans := selected ? " BackgroundTrans" : ""
```

then append `trans` to the options of the key text, the status dot and the description (`"x" colX " y" keyY " w" col.KeyWidth trans`, …), and draw the description in `selected ? theme["selectionText"] : theme["description"]`.

- [ ] **Step 5: Run; expect PASS** (all tests, validations ok).

- [ ] **Step 6: Scripted screenshot** — PowerShell: a script that includes `Legend.ahk`, registers 7 one-entry pages like `Navigator_Many`, calls `Legend.Start()`, `Legend.Open()`, `Legend.Handle("Down")` twice, writes the overlay's physical bounds (`LegendWindows.InPhysicalPixels(() => LegendWindows.Bounds(Legend.Gui.Hwnd))`) to a file, sleeps 2.5 s and exits; capture those bounds with System.Drawing (per-process DPI aware) and Read the PNG. Expected: the third index row on a selection bar, footer `↵ open · ^n/^p move · …`.

- [ ] **Step 7: Hand check (user)** — after the dotfiles bump (Task 5): Alt+/ index: Ctrl+N/P and ↓/↑ move, Enter opens, Ctrl+F/B page; pinned (`` ` ``): Enter/↓/Ctrl+N reach the app; a flat page: Enter reaches the app; Win+Space chord: Ctrl+F/B page when the menu has several screens.

- [ ] **Step 8: Commit** — `git add Legend.ahk src/Overlay.ahk tests/Controller.Tests.ahk`; message "Alt+/ and chords: the shared key scheme, a selection bar in menus".

---

### Task 4: Picker keys and footer

**Files:**
- Modify: `src/Picker.ahk` (`Key`, `FilterKey`, `Footer`)
- Test: `tests/Picker.Tests.ahk`

**Interfaces:**
- Produces: `Key` handles `Ctrl+F`/`Ctrl+B` (page) and `Ctrl+T` (next scope) in both modes; `Footer(density)` in the shared wording.

- [ ] **Step 1: Failing tests** — append to `tests/Picker.Tests.ahk`:

```ahk
T.Test("Picker: Ctrl+F/B page and Ctrl+T cycles scopes", Picker_CtrlKeys)
Picker_CtrlKeys() {
    p := Picker_New(5)
    p.PageSize := 2
    T.Eq(p.Key(Picker_Key("Ctrl+F")), "redraw")
    T.Eq(p.Cursor, 3)
    T.Eq(p.Key(Picker_Key("Ctrl+B")), "redraw")
    T.Eq(p.Cursor, 1)
    q := Picker_New(3, {Scopes: ["x", "y"]})
    T.Eq(q.Key(Picker_Key("Ctrl+T")), "redraw")
    T.Eq(q.Scope, "y")
    q.Key(Picker_Key("/"))
    T.Eq(q.Key(Picker_Key("Ctrl+T")), "redraw", "works while filtering")
    T.Eq(q.Scope, "x")
}

T.Test("Picker: footers use the shared key names", Picker_FooterKeys)
Picker_FooterKeys() {
    q := Picker_New(3, {Scopes: ["x", "y"]})
    T.Eq(q.Footer("comfortable"), "↵ pick   ·   ^n/^p move   ·   / filter   ·   ^t scope   ·   = comfortable   ·   esc close")
    q.PageSize := 2
    T.True(InStr(q.Footer("compact"), "^f/^b 1/2"))
    q.Key(Picker_Key("/"))
    T.Eq(q.Footer("compact"), "↵ pick   ·   ^n/^p move   ·   esc clear   ·   ^f/^b 1/2")
    T.Eq(Picker_New(3).Footer("compact"), "↵ pick   ·   ^n/^p move   ·   / filter   ·   = compact   ·   esc close")
}
```

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Implement** — in `Key`'s normal-mode switch add `case "Ctrl+F": return this.Page(1)`, `case "Ctrl+B": return this.Page(-1)`, `case "Ctrl+T": return this.ChangeScope(1)`; add the same three cases to `FilterKey`'s switch. Replace `Footer`:

```ahk
    Footer(density) {
        parts := ["↵ pick", "^n/^p move"]
        if this.Mode = "filter" {
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
```

- [ ] **Step 4: Run; expect PASS.**
- [ ] **Step 5: Commit** — "Picker: Ctrl+F/B pages, Ctrl+T scope, shared footer".

---

### Task 5: Docs, merge, dotfiles

**Files:**
- Modify: `README.md`, `docs/specs/2026-09-28-chord-mode-design.md`, `docs/specs/2026-09-30-picker-design.md`

- [ ] **Step 1: README**
  - "Using the overlay" table: replace the `Space / PgDn, PgUp` row with `| Space / PgDn, PgUp / Ctrl+F, Ctrl+B | next / previous screen |` and add after `letter`: `| Ctrl+N / Ctrl+P, ↓ / ↑ | move the cursor in a menu |` and `| Enter | open the selected item |`.
  - Chords paragraph: "PgDn/PgUp or Ctrl+N/Ctrl+P page" → "PgDn/PgUp or Ctrl+F/Ctrl+B page".
  - Pickers paragraph: "A picker opens a list: j/k, ↓/↑ or Ctrl+N/Ctrl+P move (the trigger again moves down, Shift+trigger up), a letter or Enter picks, `/` filters (every word must match), h/l change scope, `=` switches density, Esc cancels." → "A picker opens a list: Ctrl+N/Ctrl+P or ↓/↑ move (the trigger again moves down, Shift+trigger up), Ctrl+F/Ctrl+B or PgDn/PgUp page, a letter or Enter picks, `/` filters (every word must match), Ctrl+T changes scope, `=` switches density, Esc cancels."
  - After the "Using the overlay" table: `> **Changed:** Ctrl+N/Ctrl+P used to page in Alt+/ and chord menus. They now move the cursor in Alt+/ menus; page with Ctrl+F/Ctrl+B, PgDn/PgUp or Space.`
- [ ] **Step 2: Specs** — below each place that lists Ctrl+N/P as paging or a footer (`chord-mode-design.md`: the "PgDn / Ctrl+N" bullet, the footer bullet, the "reference overlay gains the same secondary keys" paragraph; `picker-design.md`: the Normal-mode table, the filter-mode move bullet, the Footer bullet), add one line: `Superseded by 2026-09-30-key-scheme-design.md: Ctrl+F/B page, Ctrl+N/P move a cursor, Ctrl+T changes scope.`
- [ ] **Step 3: Run the tests**, commit "Docs: the shared key scheme".
- [ ] **Step 4: Final review** (fresh reviewer, whole branch), fix Critical/Important with RED→GREEN tests.
- [ ] **Step 5: Merge** `keys` into `main` locally (the user chose local merges), run the tests on `main`, delete the branch.
- [ ] **Step 6: Dotfiles** — point `linked/AutoHotKey/Lib/Legend` at Legend `main` (`git fetch C:/Users/simsr/projects/Legend main && git checkout FETCH_HEAD` inside the submodule), validate `autohotkey.ahk` with `/validate` from PowerShell, then do Task 3 Step 7's hand check with the user, and commit the submodule bump ("AutoHotKey: bump Legend (shared key scheme)").
