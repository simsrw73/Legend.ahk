# Legend: design

Legend is an AutoHotkey v2 library that shows a contextual shortcut overlay.

## Goal

One help key (default Alt+/) shows the shortcuts that matter right now,
without looking away from the screen: the active app's page if it has one,
otherwise an index of pages to drill into. AutoHotkey bindings register through
Legend's API, which records page, category, group and description alongside
the hotkey. Hand-written Markdown pages add documentation-only shortcuts (an
app's native keys) that anyone can share. The overlay is built from that data,
so it never drifts from the real bindings.

Prior art: which-key.nvim (descriptions attached to mappings), KeyCue (macOS
overlay), PowerToys Shortcut Guide (Windows shortcuts only, not extensible).

## Requirements

- Bindings made through Legend and documentation-only shortcuts from Markdown
  files merge into the same pages.
- Bound and doc-only shortcuts are visually distinct (theme colors), with the
  option to make them identical.
- Context: the page matching the active window opens first; otherwise an
  index.
- Hierarchy: index → page → category, with `###` groups as headings on a
  screen and extra screens when a list overflows.
- While the overlay is open, a Ctrl/Alt/Win combo closes it and reaches the
  app or AHK binding unchanged.
- A pin mode keeps the overlay up while combos pass through.
- Theming: colors, fonts, layout and key notation; shareable theme files;
  light/dark following Windows.
- Optional legend line explaining the key notation on the current screen.
- Usable as a drop-in library: one `#Include`, no global name collisions, no
  assumptions about the host script's folder layout.

## Repository layout

```
Legend/
  Legend.ahk            single entry point; #Includes everything in src/
  src/                  modules (see Modules)
  themes/               catppuccin-mocha.ini, catppuccin-latte.ini
  examples/
    example.ahk         minimal host script
    pages/zen.md        doc-only example page
  tests/
    Legend.Tests.ahk    unit tests
    fixtures/           sample pages and themes
    Run-Tests.ps1       runs unit tests + /Validate
  docs/
```

## Host setup

```ahk
#Include <path>\Legend\Legend.ahk

Legend.Page("komorebi").Category("Focus", [
    ["!h", "focus left", (*) => Komorebi.Run("focus", "left")],
])

Legend.Start({
    HelpKey: "!/",                               ; default
    Pages:   [A_ScriptDir "\legend\pages"],      ; folders of *.md, default none
    Themes:  [A_ScriptDir "\legend\themes"],     ; searched before built-in themes/
    Theme:   "auto",                             ; "auto" or a theme file name
})
```

Bindings may be registered before or after `Start`; pages and bindings are
merged when the overlay is drawn, so order does not matter. `Start` loads page
files and registers the help key and overlay hotkeys; the theme is read each
time the overlay opens. `Start` may be called once (a second call throws); to
pick up edited page files, reload the host script.

## Page files

The parser reads a strict Markdown subset line by line and ignores everything
else, so notes and links can sit anywhere and the file renders normally on
GitHub or in Obsidian.

```markdown
---
match: ahk_exe zen.exe
key: z
---
# Zen

Notes are ignored.

## Tabs
### Open & close
- `Ctrl+T` New tab
- `Ctrl+Shift+T` Reopen closed tab

### Navigate
- `Ctrl+Tab` Next tab
```

| Markdown | Meaning |
|---|---|
| front matter `match:` | AHK WinTitle criteria for the page; absent means global |
| front matter `key:` | fixed index letter (optional) |
| `# Title` | page title (first one only); pages merge by title, case-insensitive |
| `## Heading` | category |
| `### Heading` | group within a category; entries before any `###` go in an unnamed group |
| ``- `keys` description`` | a shortcut; ``` `` `` ``` delimits keys containing a backtick |
| anything else | ignored |

Entries before any `##` go in an unnamed category. A line that starts like an
entry (``- ` ``) but cannot be parsed (unclosed backtick, unknown key name) is
skipped and recorded as a warning with file and line number. A file with no
`# Title` is skipped with a warning. Legend never stops the host script from
starting because of a page file.

## Binding API

Two explicit forms; there is no implicit "current page" state.

Table form, for declarative blocks:

```ahk
komorebi := Legend.Page("komorebi")                 ; global
komorebi.Category("Focus / move / stack", [
    ["!h", "focus left",  (*) => Komorebi.Run("focus", "left"), {Row: "Alt+H/J/K/L", Text: "focus ← ↓ ↑ →"}],
    ["!j", "focus down",  (*) => Komorebi.Run("focus", "down"), {Row: "Alt+H/J/K/L"}],
], "Focus")                                          ; optional group

zen := Legend.Page("Zen", "ahk_exe zen.exe", {Key: "z"})
zen.Category("Tabs", [
    ["#+o", "open tab in Chrome", (*) => OpenCurrentZenTabInChrome()],
])
```

One-line form, for loops and complicated code:

```ahk
Legend.Bind(["komorebi", "Workspaces", "Focus"], "!" i, "focus " name, FocusWorkspace(name))
```

- `Legend.Page(title, match?, options?)` returns the same object for the same
  title (case-insensitive). If `match` or `Key` is given both in code and in a
  file and they differ, code wins and a warning is recorded.
- `page.Category(name, rows?, group?)` binds each row and returns the category
  object; `category.Bind(key, description, fn, options?)` returns the category
  so short chains work.
- `Legend.Bind(path, key, description, fn, options?)`: `path` is
  `[page, category]` or `[page, category, group]`.
- Binding a key on a page whose `match` was given in code registers it under
  `HotIfWinActive(match)`; otherwise it registers with no condition. A `match`
  that comes only from a page file affects which page opens, never hotkeys.
  The `HotIf` context is reset to none afterwards (AHK cannot read the
  current one).
- `Legend.Doc(path, key, description)` adds a documentation-only entry from
  code (same as a Markdown line).
- Hotkeys are registered through `Legend.Binder`, a replaceable function
  (default: set `HotIfWinActive`, call `Hotkey`, reset), so tests can record
  bindings without creating real hotkeys.
- Options: `Row` (merged-row label) and `Text` (merged-row description, taken
  from the first entry that sets it). Entries in the same group with the same
  `Row` render as one line, shown as bound only if all of them are bound.

## Keys and notation

Both AHK hotkey syntax (`!+h`, `^;`, `#Space`) and written notation
(`Alt+Shift+H`, `Ctrl+;`, `Win+Space`) parse to one canonical form: a
modifier set plus a key name. Canonical forms are compared to merge duplicates:
a key both documented and bound appears once, as bound.

Display is set by the theme's `keyStyle`:

| keyStyle | Example |
|---|---|
| `text` | `Ctrl+Shift+T` |
| `symbols` | `⌃⇧T` |
| `ahk` | `^+t` |

Written notation that does not parse to a single key (ranges like
`Ctrl+1–8`, sequences) is kept verbatim for display and never merged.

## Overlay behavior

Opening (help key):

- Exactly one page's `match` is active → open that page.
- Several match → an index of only those pages.
- None → the full index.

Levels:

1. **Index**: all pages with a letter each (front matter `key:` or code
   `Key` option, otherwise the first unused letter of the title).
2. **Page**: its categories as a lettered list. If the whole page fits on one
   screen, it is shown flattened instead: categories as headings, all keys
   visible.
3. **Category**: its entries under `###` group headings, in columns; overflow
   continues on further screens, shown as `2/3` in the footer.

Keys while open are claimed by hotkeys under `#HotIf Legend.Visible`
(unmodified keys only); letter hotkeys use a narrower
`#HotIf Legend.Visible && Legend.ClaimsLetters`, true only on list screens:

| Key | Effect |
|---|---|
| letter | drill down (list screens only); unassigned letters are ignored |
| Backspace | up one level; from an app page up to the full index |
| Space / PgDn, PgUp | next / previous screen |
| `` ` `` | toggle pin |
| Tab | cycle key notation text → symbols → ahk (until the script reloads) |
| `=` | flip density comfortable ↔ compact (until the script reloads) |
| Esc, help key | close |
| plain letter on a key-list screen | close, key passes through (not claimed) |
| any Ctrl/Alt/Win combo | close (unless pinned), key passes through |

The overlay never takes focus (`WS_EX_NOACTIVATE`), so passed-through keys
reach the active app. A visible-mode `InputHook` (sees keys without
suppressing them) closes it on a Ctrl/Alt/Win combo unless pinned. It also
closes when the active window changes. In pinned mode it stays up through
combos and focus changes until Esc, the help key or the pin key.

## Rendering and theming

The overlay draws one screen into a `Gui` with `+AlwaysOnTop -Caption
+ToolWindow +E0x08000000`, rounded corners and border via DWM, centered on the
work area of the monitor containing the active window. Text is measured before
layout, so column widths fit their content. Each navigation step rebuilds the
screen.

Screen parts: title, optional legend, headings and entries, footer (level
hints, `n/m` screen count, 📌 when pinned, warning count when page files had
problems).

Theme files are INI (`<name>.ini`, ASCII or UTF-16, since Windows' INI API
does not read UTF-8), searched in the host's `Themes` folders and then
Legend's `themes/`:

| Section | Settings |
|---|---|
| `[colors]` | `background`, `border`, `title`, `category`, `group`, `keyBound`, `keyDoc`, `description`, `footer`, `pinned`, `warning` |
| `[fonts]` | `uiFont`, `keyFont`, `titleSize`, `headingSize`, `bodySize` |
| `[layout]` | `density` (`comfortable` / `compact`), `padding`, `rowSpacing`, `maxColumns`, `maxHeightPercent`, `maxWidthPercent`, `opacity`, `rounded` |
| `[keys]` | `keyStyle` (`text` / `symbols` / `ahk`), `legend` (`auto` / `off` / `top` / `bottom`) |

Missing settings fall back to built-in defaults (Catppuccin Mocha, `keyDoc` a
muted lavender, `keyStyle = text`, `legend = auto`, `density = comfortable`, fonts Segoe UI and
Consolas so nothing extra needs installing). Invalid values fall back to the
default and add a warning. `Theme: "auto"` picks `catppuccin-latte` or
`catppuccin-mocha` from Windows' `AppsUseLightTheme` each time the overlay
opens.

The legend line lists only the notation used on the current screen (e.g.
`⌃ Ctrl  ⌥ Alt  ⇧ Shift  ⊞ Win`, or `^ Ctrl  ! Alt  + Shift  # Win` for
`ahk`). `legend = auto` shows it at the bottom for symbol styles and hides it for
`text`.

`density` supplies `padding`, `rowSpacing` and the column gap when the theme
leaves them empty: compact 20 / 6 / 40, comfortable 28 / 12 / 56. Explicit
`padding` or `rowSpacing` always win. Tab and `=` override `keyStyle` and
`density` for the rest of the session; the footer shows the current values.

## Modules

AHK v2 classes are global, so every class is prefixed `Legend` to avoid
collisions with host scripts. `Legend` itself is the only public entry point.

| File | Class | Job | Unit-tested |
|---|---|---|---|
| `src/KeyName.ahk` | `LegendKeyName` | parse AHK and written notation to canonical form; format per `keyStyle`; legend symbols | yes |
| `src/PageFile.ahk` | `LegendPageFile` | Markdown text → page model + warnings | yes |
| `src/Registry.ahk` | `LegendRegistry`, `LegendPage`, `LegendCategory` | pages, `Page`/`Category`/`Bind`/`Doc`, merge with page files, bound/doc-only marking, `Binder` | yes |
| `src/Rows.ahk` | `LegendRows` | page/category/menu model → display rows (headings, groups, entries, merged rows, key formatting) | yes |
| `src/Navigator.ahk` | `LegendNavigator` | state (level, selection, screen, pinned); key → new state + action (`redraw` / `close` / `pass` / `none`); opening page resolution; index letters | yes |
| `src/Layout.ahk` | `LegendLayout` | screen content + measure function → columns and screens | yes (fake measurer) |
| `src/Theme.ahk` | `LegendTheme` | defaults, INI loading with fallback, `auto` light/dark | yes (INI part) |
| `src/Overlay.ahk` | `LegendOverlay` | draw a laid-out screen | manual |
| `Legend.ahk` | `Legend` | public API facade, `Start`, help key, navigation hotkeys, pass-through `InputHook`, focus-change close | manual |

Data model: Page {Title, Match, Letter, Categories} → Category {Name, Groups}
→ Group {Name, Entries} → Entry {Key (canonical or verbatim), Description,
Bound, Row, Text}. `LegendOverlay` and `LegendLayout` read only this model.

## Testing

- `tests/Legend.Tests.ahk`: headless unit tests with a small built-in assert
  helper, run as `AutoHotkey64.exe /ErrorStdOut tests/Legend.Tests.ahk`;
  prints one line per test, exit code = failure count. Covers:
  - `KeyName`: `^;`, `Ctrl+=`, `Ctrl+|`, `+` as a key, `#Space`, backtick keys,
    round-trips in all three styles, verbatim ranges.
  - `PageFile`: the example above, front matter, entries before headings,
    double-backtick keys, malformed lines → warnings with line numbers.
  - `Registry`: `Page()` identity, doc+bound merge by canonical key, merged
    rows, code-vs-file `match` conflict warning, `Binder` receives the right
    `HotIfWinActive` criteria, bindings before and after `Start`.
  - `Navigator`: every row of the key table, flattened vs listed pages,
    Backspace from app page, pinned mode, index letter assignment and
    collisions, opening resolution for 0/1/many matches.
  - `Layout`: single screen, column overflow, multi-screen pagination.
  - `Theme`: partial INI falls back to defaults, invalid value warns, host
    theme folder overrides built-in.
- `tests/Run-Tests.ps1`: runs the unit tests and `/Validate` on `Legend.ahk`
  and `examples/example.ahk`.
- Manual checklist (with `examples/example.ahk`):
  - Zen active → Zen page; other window → index; drill down, Backspace up.
  - Long sample page paginates; `n/m` correct.
  - A bound Alt combo pressed while open closes the overlay and runs.
  - Pin: combos pass through and the overlay stays; `` ` `` unpins.
  - `Theme: "auto"` follows a Windows light/dark switch.
  - Doc-only keys show in `keyDoc` color; a documented-and-bound key shows
    once as bound.
  - `legend = top` with `symbols` and `ahk` styles.
  - A broken `.md` line shows the warning count; the host script still starts.

## Modes

Legend has two modes built on the same parts (data model, rows, layout,
navigator, overlay, theme). v1 implements reference mode; chord mode is the
second pass, and v1 must not make choices that block it.

| | Reference (help key, v1) | Chord (its own hotkey, v2) |
|---|---|---|
| Purpose | show what keys exist | run an action by a key sequence |
| Letters | open a page or category | run an item's action or open its submenu |
| Keyboard | not claimed; combos reach the app | every key swallowed until the menu closes |
| Closes | Esc, help key, combo, focus change | after an action runs, Esc, or a key with no item |
| Extras | pin, paging | status indicator per item, optional timeout |

### Chord mode (v2)

Full design: `2026-09-28-chord-mode-design.md` (supersedes the sketch below where
they differ: timeout and overlay are user-level `Start` options, not per chord).

Replaces the host's Win+Space which-key menu (currently `Chords.ahk` on the
KeyChord library).

```ahk
Legend.Chord("#Space", "Launch", [
    Legend.Run("z", "Zed", (*) => WindowLauncher.ActivateOrRun(Apps.Zed),
        {Status: () => WindowLauncher.Find(Apps.Zed)}),
    Legend.Menu("w", "Research", [
        Legend.Run("b", "Brave", (*) => WindowLauncher.ActivateOrRun(Apps.Brave))
    ]),
    Legend.Run("Space", "Flow Launcher", (*) => Send("^``"))
], {Timeout: 0})
```

- `Legend.Chord(hotkey, title, items, options?)` registers the hotkey that
  opens the menu. `Legend.Run(key, label, fn, options?)` is an action item;
  `Legend.Menu(key, label, items)` a submenu. Keys are fixed by the author
  (any AHK key name, e.g. `Space`), never auto-assigned.
- Options: `Timeout` in seconds (0 = wait for a key, the default); item
  `Status`, a function returning true/false, drawn as a dot in the theme's
  `indicatorOn` / `indicatorOff` colors (evaluated when the menu is drawn).
- Controller `LegendChord`, separate from the reference controller: reads one
  key at a time with a suppressing `InputHook` (modifiers pass through, so
  releasing Win behaves normally), feeds it to a `LegendNavigator`, and on a
  `run` result closes the overlay and calls the action. A key with no item
  shows a brief "Nothing on <key>" and closes.
- Navigator extension: a menu item has either `Target` (drill down, as in v1)
  or `Action`; pressing an `Action` item returns `"run"` with the item.
- Reference integration: each chord tree also becomes a page in the reference
  index (title = chord title), with entries like `Win+Space → w → b` Brave,
  generated from the tree so it cannot drift. `Legend.Start({ChordReference:
  false})` omits all chord pages from the reference (default `true`).
- Theme additions: `[colors] indicatorOn`, `indicatorOff`.

### What v1 keeps open for chord mode

- `LegendNavigator` knows nothing about hotkeys or `InputHook`; menu items are
  plain objects, so adding `Action` needs no change to existing callers.
- `LegendOverlay.Show` draws whatever rows it gets; a row gains an optional
  `Status` field in v2 without changing v1 rows.
- Letter assignment already honors fixed keys.

## Out of scope for v1

Chord mode (above), hotstrings, exporting code bindings to Markdown, search,
readers for other platforms.
