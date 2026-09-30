# Legend Overlay Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One drawing pipeline for every overlay: a shared frame, two body layouts, one `LegendSelection` that moves the selection in place, and one `Legend.Render` check, so Alt+/ cursor moves stop rebuilding the window and the selection never resizes it.

**Architecture:** `LegendOverlay.Frame` / `Finish` wrap `LegendTableBody` (Alt+/, chords) and `LegendListBody` (pickers). Bodies register selectable rows with the window's `LegendSelection` (bar rectangle + controls to recolor), reserve the bar's reach once, and set the initial selection. `Legend.Render(layoutKey, build, index)` moves the selection when the key is unchanged and rebuilds otherwise; `LegendNavigator.LayoutKey` / `SelectedIndex` feed it for Alt+/ and chords, the picker's existing key for pickers.

**Tech Stack:** AutoHotkey v2.0, Win32 via `DllCall`, PowerShell 7 test runner.

**Spec:** `docs/specs/2026-10-01-overlay-pipeline-design.md`

## Global Constraints

- `#Requires AutoHotkey v2.0` in every file; classes start with `Legend`.
- **Never launch AutoHotkey from the Bash tool.** Tests: `pwsh -NoProfile -File tests/Run-Tests.ps1` (PowerShell tool; exit code = failures).
- Locals must not shadow built-ins (`min`, `max`, `mod`, `hotkey`, `t`…) or WarnHost globals (`a`–`z`, `id`, `fn`, `app`, `pad`, `out`, `ch`, `vk`, `sc`, `cx`, `cy`, `wx`, `wy`, `ww`, `wh`, `lh`, `th`, `ty`, `bgr`, `rgb`, `ih`).
- The drawn result of every mode must not change (spec), except that an Alt+/ menu always reserves the selection bar's reach.
- `WM_SETREDRAW` must only be sent to a visible window: sending TRUE to a hidden window makes it visible.
- Commits GPG-signed (ask the user to run `! 'unlock' | gpg --clearsign | Out-Null` on a signing timeout; never bypass). Messages end with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01EGM256u2YUxjGNbwDZaxaK`
- Branch `pipeline` in `C:\Users\simsr\projects\Legend`. No pushes.

## Review Focus

1. Initial selection is applied before the window is shown: `Select` must not send `WM_SETREDRAW` to the hidden window (it would show it unplaced). `LegendSelection.Select` checks `IsWindowVisible`; Task 2 `Selection_Hidden` pins it.
2. Closing and reopening an overlay with an identical layout key must rebuild, not move a selection on a destroyed window. `Render` requires `this.Gui`; `Close`, `CloseChordNow` and `ClosePickerNow` already clear `this.Gui`. Task 4 `Legend_Render` checks the reopen case.
3. A flat Alt+/ page must look exactly as before (no reserved bar width). The table body only registers rows when the view has a cursor; Task 3 `Overlay_FlatUnchanged`.
4. The picker's per-step time stays about 16 ms (Task 5 timing script).
5. Modes can't reuse each other's windows: keys are prefixed (`nav|`, `picker|`).

---

### Task 1: Navigator LayoutKey and SelectedIndex

**Files:** Modify `src/Navigator.ahk`; Test `tests/Navigator.Tests.ahk`

**Interfaces:**
- Produces: `nav.LayoutKey` (string), `nav.SelectedIndex` (int, 1-based on the current screen, 0 without a cursor), `nav.View.SelectedIndex`; levels get `BuildId`.

- [ ] **Step 1: Branch** — `cd /c/Users/simsr/projects/Legend && git checkout -b pipeline`

- [ ] **Step 2: Failing test** (append to `tests/Navigator.Tests.ahk`):

```ahk
T.Test("Navigator: LayoutKey ignores cursor moves within a screen", Navigator_LayoutKey)
Navigator_LayoutKey() {
    nav := Navigator_Many()
    key := nav.LayoutKey
    nav.Press("Down")
    T.Eq(nav.LayoutKey, key, "cursor move")
    T.Eq(nav.SelectedIndex, 2)
    T.Eq(nav.View.SelectedIndex, 2)
    loop 4
        nav.Press("Down")
    T.True(nav.LayoutKey != key, "next screen")
    T.Eq(nav.SelectedIndex, 1, "item 6 is first on screen 2")
    key := nav.LayoutKey
    nav.Press("Pin")
    T.True(nav.LayoutKey != key, "pin")
    key := nav.LayoutKey
    nav.Relayout(rows => LegendLayout.Paginate(rows, FakeMeasure, 100, 1), "text")
    T.True(nav.LayoutKey != key, "relayout")
    key := nav.LayoutKey
    nav.Press("Enter")
    T.True(nav.LayoutKey != key, "opened a level")
    T.Eq(nav.SelectedIndex, 0, "flat page")
    key := nav.LayoutKey
    nav.Press("Backspace")
    T.True(nav.LayoutKey != key, "back")
}
```

- [ ] **Step 3: Run; expect FAIL** (`LayoutKey` missing).

- [ ] **Step 4: Implement** in `src/Navigator.ahk`:
  - `__New`: add `this.Builds := 0`.
  - `WithBuild(level, build)`: add `level.BuildId := ++this.Builds` before `return level`.
  - After the `ClaimsLetters` property:

```ahk
    ; Changes with the shown level, its screen, the pin and the key style, but not
    ; when only the cursor moves (Legend.Render then moves the selection in place).
    LayoutKey => this.Level.BuildId "|" this.Stack.Length "|" this.Level.ScreenIndex "|" this.Pinned "|" this.Style

    ; The cursor's position among the current screen's rows (0 without a cursor).
    SelectedIndex => this.Level.Cursor ? this.Level.Cursor - this.FirstItemOf(this.Level, this.Level.ScreenIndex) + 1 : 0
```

  - `View`: add `SelectedIndex: this.SelectedIndex` to the returned object.

- [ ] **Step 5: Run; expect PASS.** **Step 6: Commit** "Navigator: LayoutKey and SelectedIndex".

---

### Task 2: LegendSelection

**Files:** Create `src/Selection.ahk`, `tests/Selection.Tests.ahk`; Modify `tests/Legend.Tests.ahk`, `Legend.ahk` (include)

**Interfaces:**
- Produces: `LegendSelection(gui, color)`; `.Bar` (Progress), `.Rows`, `.Index`, `.LastChanged` (row indexes recolored by the last `Select`); `.Add(rect, recolors) → index` with `rect := {X, Y, W, H}`, `recolors := [{Ctrl, Normal, Selected}]`; `.Reserve()`; `.Select(index)`.

- [ ] **Step 1: Failing tests** — create `tests/Selection.Tests.ahk`:

```ahk
#Requires AutoHotkey v2.0

Selection_Window() {
    g := Gui("-Caption +ToolWindow -DPIScale +E0x08000000")
    sel := g.Selection := LegendSelection(g, "45475A")
    loop 3 {
        rowY := 10 + (A_Index - 1) * 20
        label := g.AddText("x10 y" rowY " w50 h20 BackgroundTrans", "row " A_Index)
        sel.Add({X: 5, Y: rowY, W: 60 + A_Index * 20, H: 20}, [{Ctrl: label, Normal: "CDD6F4", Selected: "FFFFFF"}])
    }
    return g
}

Selection_Changed(sel) {
    text := ""
    for rowIndex in sel.LastChanged
        text .= (A_Index > 1 ? "," : "") rowIndex
    return text
}

T.Test("Selection: the bar follows the selected row and only changed rows recolor", Selection_Moves)
Selection_Moves() {
    g := Selection_Window()
    sel := g.Selection
    sel.Reserve()
    g.Show("NA x-3000 y-3000 AutoSize")
    try {
        sel.Select(1)
        sel.Bar.GetPos(&barX, &barY, &barW, &barH)
        T.Eq(barX " " barY " " barW " " barH, "5 10 80 20")
        T.Eq(Selection_Changed(sel), "1")
        sel.Select(3)
        T.Eq(Selection_Changed(sel), "1,3")
        sel.Bar.GetPos(, &barY, &barW)
        T.Eq(barY " " barW, "50 120")
        sel.Select(3)
        T.Eq(Selection_Changed(sel), "", "no change, nothing recolored")
        sel.Select(0)
        T.True(!sel.Bar.Visible, "0 hides the bar")
    } finally
        g.Destroy()
}

T.Test("Selection: Reserve makes room for the widest bar", Selection_Reserve)
Selection_Reserve() {
    g := Selection_Window()
    g.Selection.Reserve()
    g.Show("NA x-3000 y-3000 AutoSize")
    try {
        g.GetClientPos(, , &clientW)
        T.True(clientW >= 5 + 120, "client " clientW " fits the widest bar")
    } finally
        g.Destroy()
}

T.Test("Selection: selecting on a hidden window keeps it hidden", Selection_Hidden)
Selection_Hidden() {
    g := Selection_Window()
    try {
        g.Selection.Select(2)
        T.True(!DllCall("IsWindowVisible", "Ptr", g.Hwnd), "WM_SETREDRAW would have shown it")
        T.Eq(g.Selection.Index, 2)
    } finally
        g.Destroy()
}
```

In `tests/Legend.Tests.ahk`, after the Overlay include pair:

```ahk
#Include %A_ScriptDir%\..\src\Selection.ahk
#Include %A_ScriptDir%\Selection.Tests.ahk
```

- [ ] **Step 2: Run; expect FAIL** (Selection.ahk cannot be opened).

- [ ] **Step 3: Implement** `src/Selection.ahk`:

```ahk
#Requires AutoHotkey v2.0

; The selection bar of one overlay window and the rows it can sit on. Bodies register
; each row's bar rectangle and the controls to recolor; Select moves the one bar and
; recolors only the rows whose state changed, repainting just those rows.
class LegendSelection {
    __New(gui, color) {
        this.Gui := gui
        ; created before any row, so the rows' transparent controls draw over it
        this.Bar := gui.AddProgress("x0 y0 w0 h0 Background" color " Disabled")
        this.Bar.Visible := false
        this.Rows := []
        this.Index := 0
        this.LastChanged := []
    }

    ; rect: {X, Y, W, H} of the bar on this row; recolors: [{Ctrl, Normal, Selected}].
    Add(rect, recolors) {
        this.Rows.Push({Rect: rect, Recolors: recolors})
        return this.Rows.Length
    }

    ; An invisible spacer at the furthest corner any bar reaches, so AutoSize always
    ; makes room for it and moving the selection never resizes the window.
    Reserve() {
        if !this.Rows.Length
            return
        right := 0, bottom := 0
        for row in this.Rows
            right := Max(right, row.Rect.X + row.Rect.W), bottom := Max(bottom, row.Rect.Y + row.Rect.H)
        this.Gui.AddText("x" (right - 1) " y" (bottom - 1) " w1 h1")
    }

    ; index: 1-based over the registered rows; 0 hides the bar.
    Select(index) {
        static WM_SETREDRAW := 0x0B, RDW_REPAINT := 0x185   ; INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW
        changed := []
        if index != this.Index {
            if this.Index
                changed.Push(this.Index)
            if index
                changed.Push(index)
        }
        this.LastChanged := changed
        if !changed.Length
            return
        hwnd := this.Gui.Hwnd
        visible := DllCall("IsWindowVisible", "Ptr", hwnd)   ; WM_SETREDRAW TRUE would show a hidden window
        if visible
            DllCall("SendMessageW", "Ptr", hwnd, "UInt", WM_SETREDRAW, "Ptr", 0, "Ptr", 0)
        try {
            for rowIndex in changed {
                selected := rowIndex = index
                for recolor in this.Rows[rowIndex].Recolors
                    recolor.Ctrl.SetFont("c" (selected ? recolor.Selected : recolor.Normal))
            }
            if index {
                rect := this.Rows[index].Rect
                this.Bar.Move(rect.X, rect.Y, rect.W, rect.H)
                this.Bar.Visible := true
            } else
                this.Bar.Visible := false
        } finally {
            if visible
                DllCall("SendMessageW", "Ptr", hwnd, "UInt", WM_SETREDRAW, "Ptr", 1, "Ptr", 0)
        }
        this.Index := index
        if !visible
            return
        area := Buffer(16)
        for rowIndex in changed {
            rect := this.Rows[rowIndex].Rect
            NumPut("Int", rect.X, "Int", rect.Y, "Int", rect.X + rect.W, "Int", rect.Y + rect.H, area)
            DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", area, "Ptr", 0, "UInt", RDW_REPAINT)
        }
    }
}
```

In `Legend.ahk`, add `#Include %A_LineFile%\..\src\Selection.ahk` right after the `Overlay.ahk` include.

- [ ] **Step 4: Run; expect PASS.** **Step 5: Commit** "LegendSelection: one bar, in-place moves, reserved width".

---

### Task 3: Frame, Finish and the two bodies

**Files:** Modify `src/Overlay.ahk`, `Legend.ahk` (`DrawPicker` in-place call); Test `tests/Overlay.Tests.ahk`

**Interfaces:**
- Consumes: Task 1 `view.SelectedIndex`; Task 2 `LegendSelection`.
- Produces: `LegendOverlay.Frame(theme, title) → {Gui, Top, Bottom}`; `LegendOverlay.Finish(frame, theme, footer, pinned := false, warningCount := 0) → Gui`; `LegendTableBody.Draw(frame, view, theme, measurer, legendLine)`; `LegendListBody.Draw(frame, view, theme, measurer, maxWidth)`; every overlay window has `.Selection`. `Show` / `ShowPicker` keep their signatures. `SelectPickerRow` is removed.

- [ ] **Step 1: Failing tests** (append to `tests/Overlay.Tests.ahk`):

```ahk
; Seven one-entry pages laid out in two columns with the real measurer.
Overlay_TwoColumnNav(theme, measurer) {
    r := Registry_New()
    loop 7
        r.Bind(["Page " A_Index, "c"], "^!F" A_Index, "x", Noop)
    nav := LegendNavigator(r.SortedPages(), rows => LegendLayout.Paginate(rows, measurer, 100, 2, theme["padding"], 0, theme["columnGap"]))
    nav.Open([])
    return nav
}

T.Test("Overlay: moving the selection never changes an Alt+/ menu's size", Overlay_SelectionSize)
Overlay_SelectionSize() {
    theme := LegendTheme.Resolve(LegendTheme.Read(""))
    m := LegendMeasurer(theme)
    nav := Overlay_TwoColumnNav(theme, m)
    T.Eq(nav.View.Columns.Length, 2, "two columns")
    first := LegendOverlay.Show(nav.View, theme, m, "f", "", false, 0)
    onScreen := 0
    for col in nav.View.Columns
        onScreen += col.Rows.Length
    loop onScreen - 1   ; the last item of this screen, in the last column
        nav.Press("Down")
    T.Eq(nav.View.ScreenIndex, 1)
    last := LegendOverlay.Show(nav.View, theme, m, "f", "", false, 0)
    try {
        WinGetPos(, , &firstW, &firstH, first)
        WinGetPos(, , &lastW, &lastH, last)
        T.Eq(lastW " " lastH, firstW " " firstH, "cursor in the last column")
        first.Selection.Select(first.Selection.Rows.Length)
        first.Selection.Bar.GetPos(&barX, , &barW)
        first.GetClientPos(, , &clientW)
        T.True(barX + barW <= clientW, "the bar stays inside the window")
    } finally
        first.Destroy(), last.Destroy(), m.Destroy()
}

T.Test("Overlay: flat pages register no selectable rows", Overlay_FlatUnchanged)
Overlay_FlatUnchanged() {
    theme := LegendTheme.Resolve(LegendTheme.Read(""))
    m := LegendMeasurer(theme)
    nav := Overlay_TwoColumnNav(theme, m)
    nav.Press("Enter")   ; Page 1 is flat
    flat := LegendOverlay.Show(nav.View, theme, m, "f", "", false, 0)
    try
        T.Eq(flat.Selection.Rows.Length, 0)
    finally
        flat.Destroy(), m.Destroy()
}
```

- [ ] **Step 2: Run; expect FAIL** (`Selection` missing on the window / sizes differ).

- [ ] **Step 3: Implement** — in `src/Overlay.ahk`, replace `Show`, `ShowPicker` and `SelectPickerRow` with:

```ahk
    ; A window with background, margins, a selection bar and the title. Returns
    ; {Gui, Top, Bottom}: bodies draw from Top and set Bottom.
    static Frame(theme, title) {
        overlay := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")   ; WS_EX_NOACTIVATE
        overlay.BackColor := theme["background"]
        overlay.MarginX := overlay.MarginY := theme["padding"]
        overlay.Selection := LegendSelection(overlay, theme["selection"])
        titleCtrl := this.AddText(overlay, theme, "title", theme["title"], "xm ym", title)
        titleCtrl.GetPos(, &titleY, , &titleHeight)
        return {Gui: overlay, Top: titleY + titleHeight + theme["rowSpacing"] * 2, Bottom: 0}
    }

    ; The footer (and Alt+/'s pinned and warning badges), then placement.
    static Finish(frame, theme, footer, pinned := false, warningCount := 0) {
        overlay := frame.Gui
        this.AddText(overlay, theme, "footer", theme["footer"], "xm y" (frame.Bottom + theme["rowSpacing"]), footer)
        if pinned
            this.AddText(overlay, theme, "footer", theme["pinned"], "x+24 yp", "📌 pinned")
        if warningCount
            this.AddText(overlay, theme, "footer", theme["warning"], "x+24 yp", "⚠ " warningCount " warning" (warningCount = 1 ? "" : "s"))
        this.Place(overlay, theme)
        return overlay
    }

    static Show(view, theme, measurer, footer, legendLine, pinned, warningCount) {
        frame := this.Frame(theme, StrUpper(view.Title))
        LegendTableBody.Draw(frame, view, theme, measurer, legendLine)
        return this.Finish(frame, theme, footer, pinned, warningCount)
    }

    ; view: {Title, Rows: [{Text, Detail, Icon, Letter, Selected}], Empty}.
    static ShowPicker(view, theme, measurer, footer, maxWidth) {
        frame := this.Frame(theme, view.Title)
        LegendListBody.Draw(frame, view, theme, measurer, maxWidth)
        return this.Finish(frame, theme, footer)
    }
```

and append two classes at the end of the file:

```ahk
; Alt+/ and chord bodies: columns of headings, groups and key/description entries.
; Menu levels (view.SelectedIndex > 0) register their entries with the selection.
class LegendTableBody {
    static Draw(frame, view, theme, measurer, legendLine) {
        overlay := frame.Gui, gutter := theme["padding"], spacing := theme["rowSpacing"]
        top := frame.Top
        if legendLine != "" && theme["legend"] = "top" {
            line := LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "xm y" top, legendLine)
            line.GetPos(, , , &lineHeight)
            top += lineHeight + spacing * 2
        }
        selection := overlay.Selection
        selectable := view.HasOwnProp("SelectedIndex") && view.SelectedIndex > 0
        colX := gutter, bottom := top
        for col in view.Columns {
            rowY := top
            for row in col.Rows {
                size := measurer(row)
                switch row.Kind {
                    case "heading":
                        LegendOverlay.AddText(overlay, theme, "heading", theme["category"], "x" colX " y" (rowY + spacing), row.Text)
                    case "group":
                        LegendOverlay.AddText(overlay, theme, "group", theme["group"], "x" colX " y" rowY, row.Text)
                    default:
                        keyColor := row.Style = "doc" ? theme["keyDoc"] : theme["keyBound"]
                        ; center the key font's line on the description's
                        keyY := rowY + (measurer.Size(row.Text, "body").H - measurer.Size(row.Key, "key").H) // 2
                        LegendOverlay.AddText(overlay, theme, "key", keyColor, "x" colX " y" keyY " w" col.KeyWidth " BackgroundTrans", row.Key)
                        textX := colX + col.KeyWidth + gutter
                        if row.Status != "" {
                            LegendOverlay.AddText(overlay, theme, "body", row.Status ? theme["indicatorOn"] : theme["indicatorOff"], "x" textX " y" rowY " BackgroundTrans", "●")
                            textX += measurer.Size("● ", "body").W
                        }
                        textCtrl := LegendOverlay.AddText(overlay, theme, "body", theme["description"], "x" textX " y" rowY " BackgroundTrans", row.Text)
                        if selectable
                            selection.Add({X: colX - spacing, Y: rowY, W: col.Width + spacing * 2, H: size.H},
                                [{Ctrl: textCtrl, Normal: theme["description"], Selected: theme["selectionText"]}])
                }
                rowY += size.H
            }
            bottom := Max(bottom, rowY)
            colX += col.Width + theme["columnGap"]
        }
        if legendLine != "" && theme["legend"] = "bottom" {
            line := LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "xm y" (bottom + spacing), legendLine)
            line.GetPos(, , , &lineHeight)
            bottom += spacing + lineHeight
        }
        frame.Bottom := bottom
        if selectable {
            selection.Reserve()
            selection.Select(view.SelectedIndex)
        }
    }
}

; Picker body: letter · icon · text · detail rows, every row selectable.
class LegendListBody {
    static Draw(frame, view, theme, measurer, maxWidth) {
        overlay := frame.Gui, gutter := theme["padding"], gap := theme["rowSpacing"]
        rowY := frame.Top
        rowH := LegendOverlay.PickerRowHeight(theme, measurer), iconW := LegendOverlay.IconSize(theme)
        letterW := measurer.Size("W", "key").W
        textW := 0, detailW := 0
        for row in view.Rows {
            textW := Max(textW, measurer.Size(row.Text, "body").W)
            detailW := Max(detailW, measurer.Size(row.Detail, "body").W)
        }
        textW := Max(60, Min(textW, maxWidth - (gap * 5 + iconW + letterW + detailW)))
        rowW := gap * 5 + iconW + letterW + textW + detailW
        rowX := gutter - gap   ; content lines up with the title
        if !view.Rows.Length {
            LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "xm y" rowY, view.Empty)
            rowY += rowH
        }
        selection := overlay.Selection, selectedIndex := 0
        for row in view.Rows {
            cellX := rowX + gap
            LegendOverlay.AddText(overlay, theme, "key", theme["keyBound"], "x" cellX " y" rowY " w" letterW " h" rowH " BackgroundTrans +0x200", row.Letter)
            cellX += letterW + gap
            if row.Icon
                overlay.AddPicture("x" cellX " y" (rowY + (rowH - iconW) // 2) " w" iconW " h" iconW " BackgroundTrans", "HICON:*" row.Icon)
            cellX += iconW + gap
            textCtrl := LegendOverlay.AddText(overlay, theme, "body", theme["description"], "x" cellX " y" rowY " w" textW " h" rowH " BackgroundTrans +0x4200", row.Text)
            cellX += textW + gap
            detailCtrl := LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "x" cellX " y" rowY " w" detailW " h" rowH " BackgroundTrans +0x202", row.Detail)
            selection.Add({X: rowX, Y: rowY, W: rowW, H: rowH},
                [{Ctrl: textCtrl, Normal: theme["description"], Selected: theme["selectionText"]},
                 {Ctrl: detailCtrl, Normal: theme["footer"], Selected: theme["selectionText"]}])
            if row.Selected
                selectedIndex := A_Index
            rowY += rowH
        }
        frame.Bottom := rowY
        selection.Reserve()
        selection.Select(selectedIndex)
    }
}
```

In `Legend.ahk` `DrawPicker`, replace `LegendOverlay.SelectPickerRow(this.Gui, theme, …)` with `this.Gui.Selection.Select(…)` (same index expression).

- [ ] **Step 4: Run; expect PASS** (all tests, validations).
- [ ] **Step 5: Screenshots** — PowerShell scripts as used before: Alt+/ with 7 pages and the cursor moved down twice; the Colors demo picker after three downs. Read both PNGs; expected: identical to the previous screenshots (bar on the selected row, colors, footer).
- [ ] **Step 6: Commit** "Overlay: one frame, two bodies, LegendSelection".

---

### Task 4: Legend.Render

**Files:** Modify `Legend.ahk` (`Render`, `Draw`, `DrawPicker`, `PickerState` fields); Test `tests/Controller.Tests.ahk`

**Interfaces:**
- Consumes: Task 1 `Nav.LayoutKey`, `Nav.SelectedIndex`; Task 3 `gui.Selection`.
- Produces: `static DrawnLayout := ""`; `static Render(layoutKey, build, index)`.

- [ ] **Step 1: Failing test** (append to `tests/Controller.Tests.ahk`):

```ahk
T.Test("Legend: Render builds once per layout key", Legend_Render)
Legend_Render() {
    builds := 0
    make := () => (builds += 1, Legend_RenderWindow())
    savedGui := Legend.Gui, savedKey := Legend.DrawnLayout
    Legend.Gui := ""
    try {
        Legend.Render("test|a", make, 0)
        Legend.Render("test|a", make, 0)
        T.Eq(builds, 1, "same key: moved in place")
        Legend.Render("test|b", make, 0)
        T.Eq(builds, 2, "new key: rebuilt")
        Legend.Gui.Destroy(), Legend.Gui := ""
        Legend.Render("test|b", make, 0)
        T.Eq(builds, 3, "no window: rebuilt even with the same key")
    } finally {
        if Legend.Gui
            Legend.Gui.Destroy()
        Legend.Gui := savedGui, Legend.DrawnLayout := savedKey
    }
}

Legend_RenderWindow() {
    g := Gui("-Caption +ToolWindow +E0x08000000")
    g.Selection := LegendSelection(g, "45475A")
    return g
}
```

- [ ] **Step 2: Run; expect FAIL** (`DrawnLayout` / `Render` missing).

- [ ] **Step 3: Implement** in `class Legend`:

```ahk
    static DrawnLayout := ""   ; layout key of the window in this.Gui

    ; Shows an overlay. When a window is up and layoutKey is the one it was built
    ; with, only the cursor moved: move the selection in place. Otherwise build() a
    ; new window and swap it in.
    static Render(layoutKey, build, index) {
        if this.Gui && this.DrawnLayout == layoutKey {
            this.Gui.Selection.Select(index)
            return
        }
        old := this.Gui
        this.Gui := build()
        this.DrawnLayout := layoutKey
        if old
            old.Destroy()
    }
```

Replace `Draw`'s last five lines (`old := this.Gui` … `old.Destroy()`) with:

```ahk
        footer := this.Nav.Footer("tab " this.Theme["keyStyle"], "= " this.Theme["density"])
        warnings := this.Registry.Warnings.Length + this.ThemeWarnings.Length
        view := this.Nav.View
        this.Render("nav|" this.Nav.LayoutKey "|" footer "|" legendLine "|" warnings,
            () => LegendOverlay.Show(view, this.Theme, this.Measurer, footer, legendLine, this.Nav.Pinned, warnings),
            this.Nav.SelectedIndex)
```

(keeping the existing `view` / `mods` / `legendLine` lines above it, and removing the old `footer :=` line so it is computed once).

In `DrawPicker`, replace everything from `layout := picker.LayoutKey "|" theme["density"]` to the end of the method with:

```ahk
        index := picker.Cursor ? picker.Cursor - (picker.ScreenIndex - 1) * picker.PageSize : 0
        this.Render("picker|" picker.LayoutKey "|" theme["density"],
            () => LegendOverlay.ShowPicker({Title: picker.TitleLine, Rows: picker.ScreenRows(), Empty: picker.EmptyText},
                theme, measurer, picker.Footer(theme["density"]), maxWidth),
            index)
```

and remove `DrawnLayout: ""` from the `PickerState` object literal in `OpenPickerNow`.

- [ ] **Step 4: Run; expect PASS.** **Step 5: Commit** "Legend.Render: one in-place-or-rebuild check for every overlay".

---

### Task 5: Verify, review, merge, dotfiles

- [ ] **Step 1: Timing** — run the earlier picker timing script (`Legend.WindowSwitcher`, 10 × `Legend.PickerKey(j)`, then `ExitApp`); expected step average ≤ 20 ms.
- [ ] **Step 2: Alt+/ timing** — same idea with `Legend.Open()` and 10 × `Legend.Handle("Down")` on the 7-page setup; record the average (it used to rebuild: expect well under the old ~100+ ms).
- [ ] **Step 3: TODO.md** — in the Flicker item, remove "Alt+/ menus rebuild on every cursor move; reuse the picker's in-place row update there. The Alt+/ selection bar reaches past the last column, so the window widens (and re-centres) when the cursor enters it."; in the key-scheme follow-ups, remove "and an Overlay selected-row test". Commit "Backlog: Alt+/ flicker and bar width done".
- [ ] **Step 4: Final review** (fresh reviewer on the whole branch); fix Critical/Important RED→GREEN.
- [ ] **Step 5: Merge** `pipeline` into `main` locally, run the tests on `main`, delete the branch.
- [ ] **Step 6: Dotfiles** — point `linked/AutoHotKey/Lib/Legend` at Legend `main`, validate `autohotkey.ahk`, ask the user to reload and hold ↓ in Alt+/ and in Alt+A, then commit "AutoHotKey: bump Legend (overlay pipeline)".
