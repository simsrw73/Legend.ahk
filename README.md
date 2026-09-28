# Legend

A contextual shortcut overlay for AutoHotkey v2. Press one key to see the
shortcuts for the app you're in, or browse an index of every page. Your
AutoHotkey bindings and hand-written Markdown pages of an app's native
shortcuts are shown side by side; doc-only keys appear in a muted color.

## Install

Copy or submodule this repo next to your script and include it:

```ahk
#Include Lib\Legend\Legend.ahk
```

## Bind keys

```ahk
komorebi := Legend.Page("komorebi")                       ; global page
komorebi.Category("Focus", [
    ["!h", "focus left", (*) => Run("komorebic focus left", , "Hide")],
    ["!l", "focus right", (*) => Run("komorebic focus right", , "Hide")]
])

zen := Legend.Page("Zen", "ahk_exe zen.exe")              ; only active in Zen
zen.Category("Tabs", [["#+o", "open tab in Chrome", OpenInChrome]])

Legend.Bind(["komorebi", "Workspaces"], "!1", "focus dev", FocusDev)   ; one line
Legend.Doc(["Zen", "Tabs"], "Ctrl+T", "new tab")                        ; doc only

Legend.Start({Pages: [A_ScriptDir "\legend\pages"]})
```

A row's optional 4th item `{Row: "Alt+H/J/K/L", Text: "focus ← ↓ ↑ →"}` merges
entries into one line.

## Page files

```markdown
---
match: ahk_exe zen.exe
key: z
---
# Zen

## Tabs
### Open & close
- `Ctrl+T` New tab
- `Ctrl+Shift+T` Reopen closed tab
```

`#` page, `##` category, `###` group, ``- `keys` description`` shortcut;
everything else is ignored. Write keys as `Ctrl+Shift+T`; ranges like
`Ctrl+1–8` are shown as written. A `match:` in a file decides which page opens
for the active window; only a match given in code makes hotkeys app-specific.

## Using the overlay

| Key | Effect |
|---|---|
| Alt+/ | open (the active app's page, or the index) / close |
| letter | open the lettered item |
| Backspace | back |
| Space / PgDn, PgUp | next / previous screen |
| `` ` `` | pin: stay open while you use shortcuts |
| Esc | close |
| any Ctrl/Alt/Win shortcut | closes the overlay and goes to the app |

## Themes

`Legend.Start({Themes: [folder], Theme: "name"})` loads `name.ini` from your
folders or Legend's `themes/`; `"auto"` (default) follows Windows light/dark
with Catppuccin Latte/Mocha. Settings: `[colors]` background, border, title,
category, group, keyBound, keyDoc, description, footer, pinned, warning;
`[fonts]` uiFont, keyFont, titleSize, headingSize, bodySize; `[layout]`
padding, rowSpacing, maxColumns, maxHeightPercent, opacity, rounded; `[keys]`
keyStyle (text/symbols/ahk), legend (off/top/bottom). Save theme files as
ASCII or UTF-16.

## Development

`pwsh -File tests/Run-Tests.ps1` runs the unit tests and syntax checks.
`examples/example.ahk` is a runnable demo.

## License

MIT
