# Legend

**A shortcut overlay for AutoHotkey v2.** Press **Alt+/** to see the shortcuts
for the app you're in: the hotkeys your script binds and the app's own keys, side
by side. Legend also gives you which-key chord menus (press Win+Space, then a
letter), pickers, and a keyboard-first window switcher.

It's for anyone who writes AutoHotkey scripts, from a first script with a
handful of hotkeys to a full keyboard-driven desktop.

<p align="center">
  <img src="docs/images/overlay-page.png" width="735"
       alt="Legend showing a komorebi page: workspace, window and stack shortcuts in three balanced columns">
</p>

## Quick start

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Next to your script, create a `Lib` folder and put Legend in `Lib\Legend`:
   download this repo (**Code → Download ZIP**), extract it there, and rename
   the folder to `Legend`.
3. Save this as `my-keys.ahk` and double-click it:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Page("My keys").Category("Text", [
    ["^!d", "type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))]
])

Legend.Start()
```

Press **Ctrl+Alt+D** to type today's date, and **Alt+/** to see it listed.
Legend binds the hotkey and documents it in one place, so the overlay is never
out of date.

**New to AutoHotkey?** [Getting started](docs/getting-started.md) walks through
this script and builds it up step by step, and
[AutoHotkey basics](docs/autohotkey-basics.md) explains the syntax it uses.

## What it does

**Pages from your hotkeys.** Group keys into pages and categories; make a page
belong to one app so Alt+/ opens straight to it there.
[Pages and bindings →](docs/guide/pages.md)

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

notepad := Legend.Page("Notepad", "ahk_exe notepad.exe")   ; only in Notepad
notepad.Category("Editing", [
    ["^!s", "insert a signature", (*) => SendText("-- `nSent from Notepad")]
])
Legend.Doc(["Notepad", "Editing"], "Ctrl+H", "replace")      ; listed, not bound

Legend.Start()
```

**Pages from Markdown files.** List an app's own shortcuts without code, or use
the ready-made pages for about 40 apps in `collections/apps`.
[Page files →](docs/guide/page-files.md)

```markdown
---
match: ahk_exe zen.exe
---
# Zen

## Tabs
- `Ctrl+T` New tab
- `Ctrl+Shift+T` Reopen closed tab
```

**Chord menus.** Press a trigger, then keys; pause and a menu shows what's
available, with dots for apps that are running.
[Chords →](docs/guide/chords.md)

<p align="center">
  <img src="docs/images/chord-menu.png" width="293"
       alt="A Win+Space chord menu: one key per app, with dots for apps that are running, and › for submenus">
</p>

**Pickers and a window switcher.** Lists you open with a hotkey, filter by
typing and pick from with one key; an Alt+Tab replacement over your windows.
[Pickers →](docs/guide/pickers.md)

<p align="center">
  <img src="docs/images/window-switcher.png" width="423"
       alt="The window switcher: windows with icons, letters and app · workspace details, the previous window selected">
</p>

**Themes.** Follows Windows light/dark with Catppuccin by default; every color,
font and spacing is configurable, and big pages spread into balanced columns.
[Themes and layout →](docs/guide/themes.md)

<p align="center">
  <img src="docs/images/overlay-index.png" width="289" alt="The index of pages, each with its letter">
  &nbsp;
  <img src="docs/images/overlay-symbols.png" width="691" alt="The komorebi page with keys shown as symbols (Tab)">
</p>

## Using the overlay

| Key | Effect |
|---|---|
| Alt+/ | open (the active app's page, or the index) / close |
| a letter, or Ctrl+N / Ctrl+P and Enter | open an item |
| Backspace | back |
| Space, Ctrl+F / Ctrl+B | next / previous screen |
| `` ` `` | pin: keep it open while you work |
| Tab / `=` | key notation / spacing |
| Esc | close |

## Documentation

| Page | For |
|---|---|
| [Getting started](docs/getting-started.md) | installing Legend and building your first script, step by step |
| [AutoHotkey basics](docs/autohotkey-basics.md) | the v2 syntax the docs use: hotkey symbols, `(*) =>`, lists |
| [Pages and bindings](docs/guide/pages.md) | categories, groups, merged rows, app-specific pages |
| [Page files](docs/guide/page-files.md) | Markdown pages, collections, page letters |
| [Chords](docs/guide/chords.md) | which-key menus, conditions, running-app dots |
| [Pickers](docs/guide/pickers.md) | pickers, the window switcher, directional focus |
| [Themes and layout](docs/guide/themes.md) | colors, fonts, spacing, columns |
| [Reference](docs/reference.md) | every function and option |
| [Troubleshooting](docs/troubleshooting.md) | when something doesn't work; every warning explained; safety |

Runnable examples, one per feature, are in [`examples/`](examples): they use
Ctrl+Alt+Shift keys, so they run alongside your own script.

## Development

`pwsh -File tests/Run-Tests.ps1` runs the unit tests and syntax-checks
`Legend.ahk`, every example, and every AutoHotkey code block in this README and
`docs/`. `tests/race/ChordRace.ahk` (run by hand) checks that fast chord keys
never strand the overlay. Design notes are in `docs/specs`.

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
