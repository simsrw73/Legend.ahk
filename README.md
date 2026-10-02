# Legend

A contextual shortcut overlay for AutoHotkey v2. Press one key to see the
shortcuts for the app you're in, or browse an index of every page. Your
AutoHotkey bindings and hand-written Markdown pages of an app's native
shortcuts are shown side by side; doc-only keys appear in a muted color.

<p align="center">
  <img src="docs/images/overlay-page.png" width="575"
       alt="Legend showing a komorebi page: workspace, window and stack shortcuts in two columns">
</p>

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

Give a page its window `match` before binding keys on it: keys bound earlier were
registered everywhere, and Legend warns. Hotkeys go through `Legend.Binder`, a
function `(keyName, fn, match)` you can replace before binding (for example to
record bindings in tests).

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
PgDn/PgUp or Ctrl+F/Ctrl+B page. Options per item: `If` (condition; the first
matching item whose `If` holds runs), `Status` (running dot), `Hint`. Keys may
use modifiers (`^s`; Shift+; is `+;`, not `:`) and [KeyChord](#acknowledgments) wildcards (`?`, `F*`,
`a-f`). An uppercase letter is Shift + that letter, so `z` and `Z` can be different
items; the menu shows it as `Z`, and Caps Lock doesn't count. Legend warns about an
item that can never run because an earlier one without `If` has its key. `Start` options:
`ChordTimeout` (seconds, 0 = none), `ChordOverlay`, `ChordReference` (chords
appear as pages in Alt+/ unless `false`).

<p align="center">
  <img src="docs/images/chord-menu.png" width="293"
       alt="A Win+Space chord menu: one key per app, with dots for apps that are running, and › for submenus">
</p>

## Pickers

```ahk
Legend.Picker("^!+p", "Colors", scope => ColorItems(scope), {
    OnPick: item => MsgBox(item.Text),
    Scopes: ["warm", "cool"]            ; optional; Ctrl+T switches, source gets the name
})
```

A picker opens a list: Ctrl+N/Ctrl+P or ↓/↑ move, Ctrl+F/Ctrl+B or PgDn/PgUp
page, a letter or Enter picks, `/` filters (every word must match), Ctrl+T changes scope, `=` switches
density, Esc cancels. Items are
`{Text, Detail?, Icon?, Letter?, Data?}`. Options: `OnPick` (required),
`OnHighlight` (gets `""` when a filter leaves nothing selected), `OnCancel`, `Start` (row selected at open), `Scopes`, `Scope`,
`Density`, `Match`, `Reference` (pickers are listed on a "Pickers" page in
Alt+/). Letters are assigned home row first and never use h/j/k/l or the
trigger's key.

<p align="center">
  <img src="docs/images/picker-filter.png" width="380"
       alt="A picker filtered by typing / re: three matching rows, the first selected">
</p>

## Window switcher

```ahk
Legend.WindowSwitcher("!a", {Scope: "all"})       ; every window, every virtual desktop
Legend.WindowSwitcher("!s", {Scope: "monitor"})   ; this desktop, this monitor
Legend.WindowSwitcher("!d", {Scope: "desktop", Scopes: ["desktop"]})   ; locked scope
```

A picker over your windows, most recent first with the previous one selected.
The highlighted window comes forward and gets an outline (theme color
`outline`); Esc puts everything back. Hooks for window managers: `Include`
(`hwnd => true` lets in a cloaked window), `Activate` (`hwnd => …` replaces the
default restore-and-activate) and `Detail` (`win => text`, the row's detail;
`win` has `Hwnd, Title, App, X, Y, W, H, Monitor, Minimized, Cloaked,
OnCurrentDesktop`).

<p align="center">
  <img src="docs/images/window-switcher.png" width="423"
       alt="The window switcher: windows with icons, letters and app · workspace details, the previous window selected">
</p>

`LegendWindows.Focus(direction)` (`"left"`, `"right"`, `"up"`, `"down"`) activates the
nearest visible window that way by top-left corners, crossing to the next
monitor at the edge: bind it to Alt+H/J/K/L for tiling-style focus without a
window manager.

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

`Pages` takes folders (every `.md` in them), single files, or `{Path, Key}` to load
one file and give its page a letter. `PageKeys` sets letters by page title for
pages loaded from a folder, without editing the files:

```ahk
apps := A_ScriptDir "\Lib\Legend\collections\apps\"
Legend.Start({
    Pages: [A_ScriptDir "\legend\pages",                 ; a folder
            apps "zed.md",                                 ; one file
            {Path: apps "google-gmail.md", Key: "g"}],     ; one file, letter g
    PageKeys: Map("Google Chrome", "c", "Zen", "z")        ; letters by title
})
```

A letter set in code (`Legend.Page(title, , {Key: "k"})`) wins, then `PageKeys` or
an entry's `Key`, then the file's `key:`; pages without one get the next free
letter. Legend warns about a `PageKeys` title no page has.

Automatic letters stick: Legend saves them to `LetterFile` (default
`%AppData%\Legend\page-letters.txt`), so a page keeps its letter across runs and
adding, removing or renaming other pages never moves it. New pages take letters
nobody holds. `LetterFile: ""` turns this off.

When something is wrong (a page file that won't parse or can't be found, a bad or
clashing key, a chord item that can never run, a `PageKeys` title with no page, a bad
theme value) the overlay's footer shows `⚠ N warnings · see Warnings`. The index
then lists a **Warnings** page with each message, and hovering over the badge shows
them as a tooltip.

## Collections

`collections/apps/` holds ready-made pages for about 40 apps: browsers, mail and
calendars, editors, chat, password managers, launchers, file managers and more.
Each one covers what is worth knowing by keyboard (an app's palette, search,
navigation and its own features), not the keys every Windows app shares. Copy
the ones you use into your pages folder and edit them freely:

```ahk
Legend.Start({Pages: [A_ScriptDir "\legend\pages"]})   ; your copies live here
```

Pages for web apps (Gmail, Google Calendar, Fastmail) match the window title, so
they open in any browser. Keys were checked against each vendor's Windows docs
where they exist; corrections are welcome.

## Using the overlay

| Key | Effect |
|---|---|
| Alt+/ | open (the active app's page, or the index) / close |
| letter | open the lettered item |
| Ctrl+N / Ctrl+P, ↓ / ↑ | move the cursor in a menu |
| Enter | open the selected item |
| Backspace | back |
| Space / PgDn, PgUp / Ctrl+F, Ctrl+B | next / previous screen |
| `` ` `` | pin: stay open while you use shortcuts |
| Tab | show keys as text, symbols (`⌃⇧T`) or AHK (`^+t`) |
| `=` | switch between comfortable and compact spacing |
| Esc | close |
| any Ctrl/Alt/Win shortcut | closes the overlay and goes to the app |

> **Changed:** Ctrl+N/Ctrl+P used to page in Alt+/ and chord menus. They now move
> the cursor in Alt+/ menus and reach chord items (a chord menu without them
> closes); page with Ctrl+F/Ctrl+B, PgDn/PgUp or Space.

<p align="center">
  <img src="docs/images/overlay-index.png" width="414" alt="The index of pages, each with its letter">
  &nbsp;
  <img src="docs/images/overlay-symbols.png" width="362" alt="The komorebi page with keys shown as symbols (Tab)">
</p>

## Themes

`Legend.Start({Themes: [folder], Theme: "name"})` loads `name.ini` from your
folders or Legend's `themes/`; `"auto"` (default) follows Windows light/dark
with Catppuccin Latte/Mocha. Settings: `[colors]` background, border, title,
category, group, keyBound, keyDoc, description, footer, pinned, warning,
selection, selectionText, outline (pickers; default border, description, category);
`[fonts]` uiFont, keyFont, titleSize, headingSize, bodySize; `[layout]`
density (comfortable/compact), padding, rowSpacing, maxColumns,
maxHeightPercent, maxWidthPercent, pickerWidthPercent (60), opacity, rounded,
pageGrowth, menuGrowth, chordGrowth, aspect; `[keys]` keyStyle (text/symbols/ahk),
legend (auto/off/top/bottom).

Lists grow `proportional` by default: a list up to half of maxHeightPercent stays
one column; a longer one gets balanced columns, as many as bring the overlay closest
to your screen's shape (`aspect=monitor`, or a width ÷ height like `1.5`), instead of
one tall column. A column may run up to 20% taller to end at a category. `vertical` fills each column
to maxHeightPercent before starting the next. pageGrowth covers shortcut pages,
menuGrowth the Alt+/ index and category menus, chordGrowth chord menus; pickers
always grow vertically, keeping their order. maxHeightPercent, maxWidthPercent and
maxColumns stay hard limits for both. Leave padding and rowSpacing out to get them from
density. Tab and `=` change keyStyle and density until the script reloads.
Save theme files as ASCII or UTF-16.

## Examples

Small runnable scripts in `examples/`, one per feature. Each opens with a comment
on what it shows and which keys to press. They use Ctrl+Alt+Shift keys (and
Ctrl+Alt+Shift+/ for the overlay) so they run alongside your own script.

| Script | Shows |
|---|---|
| `01-reference.ahk` | pages and categories from code, `Legend.Bind`, groups, merged rows, doc-only keys, an app-only page |
| `02-page-files.ahk` | Markdown page files (`examples/pages`), bound vs doc-only keys, a page big enough to become a menu |
| `03-themes.ahk` | a theme file (`examples/themes/sunset.ini`), key notation and density toggles |
| `04-chords.ahk` | a chord menu with a submenu, a running dot, a condition, sent keys and a key range |
| `05-picker.ahk` | `Legend.Picker` with two scopes, details, a fixed letter and callbacks |
| `06-window-switcher.ahk` | `Legend.WindowSwitcher` on two scopes with a Detail hook, and `LegendWindows.Focus` for directional focus |

## Development

`pwsh -File tests/Run-Tests.ps1` runs the unit tests and syntax checks.
`tests/race/ChordRace.ahk` (run by hand) checks that fast chord keys never strand
the overlay.
`tests/Run-Tests.ps1` also syntax-checks every example.

## Acknowledgments

Chord mode is built on ideas from [KeyChord](https://github.com/tylerjcw/KeyChord)
by [tylerjcw](https://github.com/tylerjcw), which ran my own chord menus before
Legend had any. Nested chords, conditions where the first match wins, modifier
steps and the wildcard syntax all come from it, and the wildcards keep KeyChord's
syntax on purpose. Many thanks to tylerjcw for building KeyChord and sharing it:
it showed how good chords can feel in AutoHotkey.

Many of the collection pages started from
[hotkys](https://github.com/solomkinmv/hotkys) by Maksym Solomkin (MIT), a
searchable catalog of app shortcuts, translated to Windows keys.

## Related

Legend grew out of my own desktop setup. These are the projects around it:

- **[dotfiles-windows](https://github.com/simsrw73/dotfiles-windows)**: My whole Windows setup, managed with chezmoi: `~/.config`, the PowerShell profile, apps, keys and secrets. The other projects here are either used by it or published from it.
- **[w11dwm-config](https://github.com/simsrw73/w11dwm-config)**: The keyboard-driven tiling desktop (komorebi, AutoHotkey, yasb, Flow Launcher, wpm), copied out of dotfiles-windows to share and discuss. Its key bindings, app launcher and window switcher are built on Legend.ahk.
- **[DotForge](https://github.com/simsrw73/DotForge)**: A PowerShell module that installs and configures command-line tools: XDG paths, fzf pickers, completions, shell hooks. The PowerShell profile in dotfiles-windows loads it, and it sets up Starship to read the starship-p9cat config.
- **[starship-p9cat](https://github.com/simsrw73/starship-p9cat)**: A Starship prompt in the powerlevel9k style, in Catppuccin colors. It's the prompt in dotfiles-windows, and a port of the CatPow theme from poshcat.omp.
- **[poshcat.omp](https://github.com/simsrw73/poshcat.omp)**: Catppuccin themes for Oh My Posh, including CatPow, a powerlevel10k-style theme. It was my prompt before Starship; starship-p9cat carries CatPow over.

## License

MIT
