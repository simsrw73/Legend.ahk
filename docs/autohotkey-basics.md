# AutoHotkey basics for Legend

This page covers the AutoHotkey v2 features used in Legend's examples. It is
for people new to v2, including those coming from v1, and should give you
enough context to read and change the examples with confidence.

If you already write AutoHotkey v2 scripts, skip this page and go to
[Getting started](getting-started.md).

## AutoHotkey v2, not v1

Legend needs **AutoHotkey v2** (version 2.0 or later). Version 1 scripts look
similar but follow different rules, and they can't load Legend. Every script in
these docs starts with this line:

```ahk
#Requires AutoHotkey v2.0
```

If you double-click a script and see an error about `#Requires`, you're running
it with v1. Install v2 from [autohotkey.com](https://www.autohotkey.com/), or
right-click the script and open it with AutoHotkey v2.

## Hotkeys and their symbols

A *hotkey* is a key combination that runs something. In code, AutoHotkey writes
the modifier keys as symbols in front of the key:

| Symbol | Key | Example | Means |
|---|---|---|---|
| `^` | Ctrl | `^s` | Ctrl+S |
| `!` | Alt | `!h` | Alt+H |
| `+` | Shift | `+F5` | Shift+F5 |
| `#` | Windows key | `#e` | Win+E |

Combine them freely: `^!+d` is Ctrl+Alt+Shift+D, and `#Space` is Win+Space.
Named keys such as `Space`, `Enter`, `Tab`, `F1`–`F24`, `Left` and `Up` are
written out. The full list is in AutoHotkey's
[key list](https://www.autohotkey.com/docs/v2/KeyList.htm) and
[hotkey modifier](https://www.autohotkey.com/docs/v2/Hotkeys.htm#Symbols) pages.

Legend shows these hotkeys in a friendly form (`Ctrl+Alt+Shift+D`) in the
overlay, so you only write the symbols once.

## Functions as values: `(*) =>`

Legend asks *what to do* when a key is pressed. You give it a function. The
shortest way to write one is an *arrow function*:

```ahk
showHello := (*) => MsgBox("Hello")
showHello()   ; shows a message box
```

- `(*)` means "accept any arguments and ignore them". Hotkeys call their
  function with the hotkey's name, which you usually don't need.
- `=>` means "do this".
- `MsgBox("Hello")` is what happens.

For more than one line, write a normal function and pass its name:

```ahk
SaveAndClose(*) {
    Send("^s")      ; Ctrl+S
    Sleep(200)
    WinClose("A")   ; close the active window
}

action := SaveAndClose   ; the function itself, not a call: no parentheses
```

## Lists and objects

Legend's settings come in two shapes.

An **array** is a list in square brackets, separated by commas:

```ahk
apps := ["Notepad", "Calculator", "Paint"]
MsgBox(apps[1])   ; Notepad: arrays count from 1
```

An **object** is a set of named values in curly braces:

```ahk
options := {HelpKey: "!/", Theme: "auto"}
MsgBox(options.Theme)   ; auto
```

A **Map** is like an object, but its names can contain spaces and are written in
quotes. Legend uses it where the names are page titles:

```ahk
letters := Map("Google Chrome", "c", "Zen", "z")
MsgBox(letters["Google Chrome"])   ; c
```

Long lists can span lines: anything inside `[ ]`, `{ }` or `( )` may break
across lines freely.

```ahk
apps := [
    "Notepad",
    "Calculator"
]
```

## Telling windows apart: `ahk_exe`

Some Legend pages apply only to one app. You identify the app with a *WinTitle*
string, usually the program's file name:

```ahk
isNotepad := WinActive("ahk_exe notepad.exe")   ; non-zero when Notepad is in front
```

To find a program's file name, use **Window Spy**, which comes with AutoHotkey:
right-click any AutoHotkey tray icon, choose *Window Spy*, then click the app.
The `ahk_exe` line is what you want. See AutoHotkey's
[WinTitle](https://www.autohotkey.com/docs/v2/misc/WinTitle.htm) page for other
ways to match windows.

## Paths: `A_ScriptDir`

`A_ScriptDir` is the folder your script is in. Use it to build paths that keep
working when you move the whole folder:

```ahk
pagesFolder := A_ScriptDir "\legend\pages"   ; strings join when placed side by side
```

## Running and reloading a script

- **Run:** double-click the `.ahk` file. A green **H** icon appears in the
  taskbar's notification area while it runs.
- **Reload after editing:** right-click the tray icon and choose *Reload Script*.
  Add `#SingleInstance Force` at the top of a script so running it again
  replaces the old copy instead of asking.
- **Stop:** right-click the tray icon and choose *Exit*.

Next: [Getting started](getting-started.md).
