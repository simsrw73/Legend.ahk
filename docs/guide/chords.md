# Chords: which-key menus

Use chords to build a keyboard launcher or menus of actions. This guide covers
items, submenus, running-app dots, conditions, sent keys, key ranges, and
timing, then builds a Win+Space launcher that opens an app in two keystrokes.

## What a chord is

A *chord* is a trigger key followed by more keys. Press the trigger, then a
letter; if you pause, a menu appears showing what each key does. This style is
often called *which-key*, after the Emacs and Neovim plugins.

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Chord("#Space", "Launch", [
    Legend.Run("n", "Notepad", (*) => Run("notepad.exe")),
    Legend.Run("c", "Calculator", (*) => Run("calc.exe")),
    Legend.Run("e", "Explorer", (*) => Run("explorer.exe"))
])

Legend.Start()
```

Press **Win+Space**, then **n**. Typed quickly, the app opens and no menu shows.
Pause after Win+Space and the menu appears after 400 ms.

**In a chord:** **Backspace** goes up a level, **Esc** or **Ctrl+G** cancels,
**Ctrl+F / Ctrl+B** (or **PgDn / PgUp**) page through a long menu. A key with
nothing on it cancels and briefly says so.

## Items

| Function | Makes |
|---|---|
| `Legend.Run(key, label, action, options?)` | an item that runs `action` |
| `Legend.Menu(key, label, items)` | a submenu, shown with `›` |

`action` can be:

| Action | When pressed |
|---|---|
| a function `(*) => ...` | is called |
| a function with a parameter `key => ...` | is called with the key you pressed (useful with [key ranges](#key-ranges-and-wildcards)) |
| a string, like `"^w"` or `"Thanks,{Enter}Me"` | is sent as keystrokes, with AutoHotkey's [Send](https://www.autohotkey.com/docs/v2/lib/Send.htm) syntax |

## Submenus

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Chord("#Space", "Launch", [
    Legend.Run("n", "Notepad", (*) => Run("notepad.exe")),
    Legend.Menu("w", "Web", [
        Legend.Run("g", "Google", (*) => Run("https://www.google.com")),
        Legend.Run("m", "Maps", (*) => Run("https://maps.google.com"))
    ])
])

Legend.Start()
```

**Win+Space, w, m** opens Google Maps.

## Item options

The fourth argument of `Legend.Run` is an object with any of:

| Option | Type | What it does |
|---|---|---|
| `Status` | function → true/false | shows a dot: green when it returns true (for example, "the app is running") |
| `If` | function → true/false | the item exists only when it returns true |
| `Hint` | text | shown after the label in the overlay's chord page, e.g. "in Notepad" |

### Running-app dots

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

running := (exe) => () => WinExist("ahk_exe " exe)

Legend.Chord("#Space", "Launch", [
    Legend.Run("n", "Notepad", (*) => Run("notepad.exe"), {Status: running("notepad.exe")}),
    Legend.Run("c", "Calculator", (*) => Run("calc.exe"), {Status: running("CalculatorApp.exe")})
])

Legend.Start()
```

### Conditions: different items for different apps

Several items may share a key; the **first one whose `If` holds** runs. Put the
specific ones first and a general fallback last:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

inBrowser := () => WinActive("ahk_exe chrome.exe") || WinActive("ahk_exe msedge.exe")

Legend.Chord("#Space", "Actions", [
    Legend.Run("x", "close tab", "^w", {If: inBrowser, Hint: "in a browser"}),
    Legend.Run("x", "close window", (*) => WinClose("A"))
])

Legend.Start()
```

Legend warns about an item that can never run because an earlier item on the
same key has no `If`.

## Key ranges and wildcards

An item's key can be a pattern. The action gets the actual key pressed:

| Pattern | Matches |
|---|---|
| `"1-9"` | one character in that range |
| `"?"` | any single-character key |
| `"F*"` | named keys by pattern: `F1`…`F24` |
| `"^s"` | Ctrl+S (modifiers work as in hotkeys) |
| `"Z"` | Shift+Z (an uppercase letter means Shift + that letter) |

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Chord("#Space", "Workspaces", [
    Legend.Run("1-9", "go to workspace", key => MsgBox("Workspace " key))
])

Legend.Start()
```

`z` and `Z` can be different items; the menu shows Shift+Z as `Z`, and Caps Lock
doesn't count. Write Shift+; as `+;`, not `:`.

These patterns follow [KeyChord](https://github.com/tylerjcw/KeyChord), the
library Legend's chords grew from.

## Chord options and timing

The fourth argument of `Legend.Chord` takes:

| Option | Default | What it does |
|---|---|---|
| `Match` | `""` | a WinTitle: the trigger works only in matching windows |
| `Reference` | `true` | list the chord as a page in Alt+/; `false` hides it |

Timing is set once, in `Legend.Start`:

| Option | Default | What it does |
|---|---|---|
| `ChordOverlay` | `400` | ms to wait before showing the menu; `"always"` or `"never"` |
| `ChordTimeout` | `0` | seconds of no key before the chord cancels; `0` waits forever |
| `ChordReference` | `true` | `false` hides every chord from Alt+/ |

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Chord("#Space", "Launch", [Legend.Run("n", "Notepad", (*) => Run("notepad.exe"))])
Legend.Start({ChordOverlay: "always", ChordTimeout: 5})
```

## Recipe: a launcher that focuses or starts apps

Open an app if it isn't running, bring it forward if it is, with a dot for
running apps:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

; Bring the app forward, or start it.
FocusOrRun(exe, command) {
    if hwnd := WinExist("ahk_exe " exe)
        WinActivate(hwnd)
    else
        Run(command)
}

App(key, label, exe, command) => Legend.Run(key, label, (*) => FocusOrRun(exe, command),
    {Status: () => WinExist("ahk_exe " exe)})

Legend.Chord("#Space", "Launch", [
    App("n", "Notepad", "notepad.exe", "notepad.exe"),
    App("e", "Explorer", "explorer.exe", "explorer.exe"),
    Legend.Menu("t", "Tools", [
        App("c", "Calculator", "CalculatorApp.exe", "calc.exe"),
        App("p", "Paint", "mspaint.exe", "mspaint.exe")
    ])
])

Legend.Start()
```

**Explanation:**

1. `FocusOrRun` checks for a window of that program and activates it, or runs the
   command.
2. `App(...)` builds a `Legend.Run` item with a `Status` dot, so each line of the
   menu stays short.
3. Submenus group less-used apps.

<p align="center">
  <img src="../images/chord-menu.png" width="293"
       alt="A Win+Space chord menu: one key per app, with dots for apps that are running, and › for submenus">
</p>
