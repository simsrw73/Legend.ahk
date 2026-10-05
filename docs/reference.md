# Legend reference

**Audience:** Legend users who know the basics and want exact details.
**Topic:** every public function, option and data shape in Legend.
**Goal:** look up any parameter, default or field without reading the source.

New to Legend? Start with [Getting started](getting-started.md). Each entry
links to the guide that explains it with examples.

**Notation:** `?` marks an optional parameter. *WinTitle* is an AutoHotkey
[window match](https://www.autohotkey.com/docs/v2/misc/WinTitle.htm) such as
`"ahk_exe notepad.exe"`. *Hotkey* is an AutoHotkey
[hotkey name](autohotkey-basics.md#hotkeys-and-their-symbols) such as `"^!d"`.

## Contents

- [Startup](#legendstartoptions): `Legend.Start`
- [Pages](#legendpagetitle-match-options): `Legend.Page`, `Category`, `Legend.Bind`, `Legend.Doc`, `Legend.Binder`
- [Chords](#legendchordhotkey-title-items-options): `Legend.Chord`, `Legend.Run`, `Legend.Menu`
- [Pickers](#legendpickerhotkey-title-source-options): `Legend.Picker`, `Legend.WindowSwitcher`, `LegendWindows.Focus`
- [Other](#legendwarnings): `Legend.Warnings`, page files, theme files
- [Errors](#errors)

---

## `Legend.Start(options?)`

Loads page files and the theme, binds the overlay key, and turns everything on.
Call it **once, after** your pages, chords and pickers.
Guide: [Getting started](getting-started.md).

| Option | Type | Default | Description |
|---|---|---|---|
| `HelpKey` | Hotkey | `"!/"` (Alt+/) | opens and closes the overlay |
| `Pages` | list | `[]` | page files: folders, `.md` files, or `{Path, Key}` ([page files](guide/page-files.md#loading-page-files)) |
| `PageKeys` | Map or object | none | page title → letter ([page letters](guide/page-files.md#page-letters)) |
| `LetterFile` | path | `%AppData%\Legend\page-letters.txt` | where automatic page letters are kept; `""` keeps none |
| `Themes` | list of folders | `[]` | searched for theme files before Legend's own `themes` |
| `Theme` | text | `"auto"` | theme file name without `.ini`; `"auto"` follows Windows light/dark |
| `ChordOverlay` | number or text | `400` | ms before a chord's menu shows; `"always"` or `"never"` |
| `ChordTimeout` | number | `0` | seconds of no key before a chord cancels; `0` = never |
| `ChordReference` | true/false | `true` | list chords as pages in the overlay |

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Start({
    HelpKey: "!/",
    Pages: [A_ScriptDir "\legend\pages"],
    PageKeys: Map("Zen", "z"),
    Themes: [A_ScriptDir "\legend\themes"],
    Theme: "auto",
    ChordOverlay: 400
})
```

**Errors:** calling it twice throws `Legend.Start was already called`.

---

## `Legend.Page(title, match?, options?)`

Returns the page with this title, creating it the first time. Titles match
regardless of case. Guide: [Pages and bindings](guide/pages.md).

| Parameter | Type | Description |
|---|---|---|
| `title` | text | the page's name in the overlay |
| `match` | WinTitle | windows the page is for: Alt+/ opens it there, and its hotkeys work only there. Set it before binding keys |
| `options` | object | `{Key: "x"}`: the page's letter in the index |

**Returns:** a page object with `Category`.

### `page.Category(name, rows?, group?)`

Returns the category with this name on the page (creating it), and binds `rows`
into it.

| Parameter | Type | Description |
|---|---|---|
| `name` | text | the category heading |
| `rows` | list of rows | each row `[hotkey, description, action, options?]` |
| `group` | text | a sub-heading inside the category for these rows |

**Row:**

| Item | Type | Description |
|---|---|---|
| `hotkey` | Hotkey | the key to bind |
| `description` | text | shown in the overlay |
| `action` | function | called with the hotkey name: write `(*) => ...` |
| `options` | object | `{Row: "text", Text: "text"}`: rows sharing a `Row` show as one line with that key text; `Text` is its description ([merged rows](guide/pages.md#merging-related-keys-into-one-row)) |

**Returns:** the category, which also has `.Bind(hotkey, description, action, options?, group?)`.

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Page("Notepad", "ahk_exe notepad.exe", {Key: "n"})
    .Category("Editing", [["^!d", "insert the date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))]])
    .Bind("^!t", "insert the time", (*) => SendText(FormatTime(, "HH:mm")))
```

## `Legend.Bind(path, hotkey, description, action, options?)`

Binds one hotkey and lists it. Pages and categories are created as needed.

| Parameter | Type | Description |
|---|---|---|
| `path` | list | `[page, category]` or `[page, category, group]` |
| `hotkey`, `description`, `action`, `options` | | as in a [row](#pagecategoryname-rows-group) |

## `Legend.Doc(path, keys, description)`

Lists a shortcut without binding it (shown in a muted color).

| Parameter | Type | Description |
|---|---|---|
| `path` | list | `[page, category]` or `[page, category, group]` |
| `keys` | text | written as it reads: `"Ctrl+Shift+T"`; ranges like `"Ctrl+1–8"` shown as written |
| `description` | text | shown in the overlay |

## `Legend.Binder`

The function Legend uses to create hotkeys: `(keyName, action, match) => ...`.
The default registers an AutoHotkey hotkey, active only in windows matching
`match` when it isn't `""`. Assign your own **before** binding anything, for
example to log or test bindings ([example](guide/pages.md#recording-or-replacing-how-hotkeys-are-created)).

---

## `Legend.Chord(hotkey, title, items, options?)`

Makes a chord menu opened by `hotkey`. Guide: [Chords](guide/chords.md).

| Parameter | Type | Description |
|---|---|---|
| `hotkey` | Hotkey | the trigger, e.g. `"#Space"` |
| `title` | text | the menu's title; also its page title in the overlay |
| `items` | list | items from `Legend.Run` and `Legend.Menu` |
| `options` | object | `Match` (WinTitle: trigger only works there), `Reference` (`false` hides it from the overlay) |

## `Legend.Run(key, label, action, options?)`

One chord item.

| Parameter | Type | Description |
|---|---|---|
| `key` | text | a key (`"n"`, `"Space"`, `"^s"`), an uppercase letter for Shift (`"Z"`), or a pattern: `"1-9"`, `"?"`, `"F*"` |
| `label` | text | shown in the menu |
| `action` | function or text | a function is called (with the pressed key, if it takes a parameter); text is sent as keys |
| `options` | object | `Status` (function → true/false: dot), `If` (function → true/false: item exists only then), `Hint` (text shown on the overlay's chord page) |

## `Legend.Menu(key, label, items)`

A submenu: same `key` and `label` as `Legend.Run`, plus its own `items`.

---

## `Legend.Picker(hotkey, title, source, options)`

A list opened by `hotkey`. Guide: [Pickers](guide/pickers.md).

| Parameter | Type | Description |
|---|---|---|
| `hotkey` | Hotkey | opens the picker |
| `title` | text | shown at the top |
| `source` | function | `scope => items`: returns the list each time the picker opens; `scope` is the current scope name, or `""` |
| `options` | object | see below; `OnPick` is required |

| Option | Type | Default | Description |
|---|---|---|---|
| `OnPick` | function | (required) | `item => ...` after a pick |
| `OnHighlight` | function | none | `item => ...` when the selection changes; `item` is `""` when nothing is selected |
| `OnCancel` | function | none | `() => ...` after Esc or focus loss |
| `Scopes` | list | none | scope names; Ctrl+T cycles |
| `Scope` | text | first scope | scope at open |
| `Start` | number | `1` | row selected at open |
| `Density` | text | theme's | `"comfortable"` or `"compact"` |
| `Match` | WinTitle | `""` | the hotkey only works in matching windows |
| `Reference` | true/false | `true` | list on the overlay's "Pickers" page |
| `EmptyText` | text | `"Nothing to pick"` | shown for an empty list |

**Item fields:** `Text` (required), `Detail`, `Icon` (an `HICON` handle), `Letter`
(one character), `Data` (anything; returned to you).

## `Legend.WindowSwitcher(hotkey, options?)`

A picker over open windows, most recent first. Guide:
[window switcher](guide/pickers.md#the-window-switcher).

| Option | Type | Default | Description |
|---|---|---|---|
| `Scope` | text | `"all"` | `"all"`, `"desktop"` or `"monitor"` |
| `Scopes` | list | all three | scopes Ctrl+T cycles |
| `Start` | number | `2` | row at open: 2 is the previous window |
| `Detail` | function | app name | `win => text` for the right-hand column |
| `Include` | function | none | `hwnd => true/false`: allow a hidden (cloaked) window |
| `Activate` | function | restore + activate | `hwnd => ...`: how to switch to a window |
| `Density`, `Match`, `Reference` | | | as for `Legend.Picker` |

**Window fields** (`win` in `Detail`): `Hwnd`, `Title`, `App` (program name without
`.exe`), `X`, `Y`, `W`, `H`, `Monitor` (number), `Minimized`, `Cloaked`,
`OnCurrentDesktop`.

## `LegendWindows.Focus(direction)`

Activates the nearest visible window in `direction` (`"left"`, `"right"`, `"up"`
or `"down"`), comparing top-left corners, and crosses to the next monitor at the
edge. Does nothing when there's no window that way.
[Example](guide/pickers.md#directional-focus-without-a-window-manager).

---

## `Legend.Warnings`

A list of the warning messages so far (text). The overlay shows them on its
**Warnings** page; see [Troubleshooting](troubleshooting.md#warnings).

## Page files

Markdown files of shortcuts: front matter (`match:`, `key:`), `# page`,
`## category`, `### group`, `` - `keys` description ``.
[Format](guide/page-files.md#format).

## Theme files

`.ini` files with `[colors]`, `[fonts]`, `[layout]` and `[keys]` sections.
[Every setting](guide/themes.md#every-setting).

## Overlay keys

| Key | Effect |
|---|---|
| Alt+/ (`HelpKey`) | open (the active app's page, or the index) / close |
| a letter | open that item |
| Ctrl+N / Ctrl+P, ↓ / ↑ | move the cursor in a menu |
| Enter | open the selected item |
| Backspace | back |
| Space, PgDn / PgUp, Ctrl+F / Ctrl+B | next / previous screen |
| `` ` `` | pin: stay open while you use your apps |
| Tab | key notation: text, symbols, AutoHotkey |
| `=` | comfortable or compact spacing |
| Esc | close |
| any Ctrl/Alt/Win shortcut | closes the overlay and reaches the app |

## Errors

Mistakes Legend can't work around stop the script with an AutoHotkey error.
Everything else becomes a [warning](troubleshooting.md#warnings).
See [Troubleshooting](troubleshooting.md#my-script-wont-start) for each message.
