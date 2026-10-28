# Game mode

Games hold keys like Alt while you press letters, so a hotkey such as Alt+S can
fire in the middle of a game and pull a window over it. Game mode turns your
script's hotkeys off while a game has focus and back on when you leave it. This
guide covers turning it on, how Legend recognises a game, the toggle key, and
how to fix a game it misses or an app it mistakes for one.

## Turning it on

Game mode is off unless you ask for it. Add `GameMode: true` to `Legend.Start`:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

!s::MsgBox("Alt+S")   ; off while a game has focus

Legend.Start({GameMode: true})
```

> **It suspends the whole script.** While a game has focus, *every* hotkey and
> hotstring in your script is off, not just the ones you registered through
> Legend. This is AutoHotkey's own `Suspend`, so the tray icon changes to show
> it. To keep one hotkey working in games, put `#SuspendExempt` above it.

When the game loses focus, your hotkeys come back on. If you suspended the
script yourself (from the tray menu, or with `Suspend`), Legend leaves it
suspended.

## The toggle key

**Ctrl+Alt+G** switches game mode by hand, at once: hotkeys off, or back on. Use
it when Legend misses a game, or turns your hotkeys off in an app that isn't
one. Your choice holds until you switch to another window; then Legend decides
again.

The toggle key still works while everything else is off. Change it with
`ToggleKey`, or turn it off with `ToggleKey: ""`. If your script already uses
the key, yours wins: Legend warns and registers no toggle key, so pick another. It doesn't appear in the
overlay by itself; to list it, add it to one of your pages:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Doc(["AutoHotkey", "Game mode"], "Ctrl+Alt+G", "hotkeys off / on")
Legend.Start({GameMode: true})
```

## How Legend recognises a game

Each time a window comes to the front, Legend looks at the program behind it.
It's a game if, in order:

1. it isn't in your `NotGames` list, and
2. it's in your `Games` list, **or**
3. it's installed in a game library folder: Steam (`steamapps\common`), GOG,
   EA, Epic or Xbox, **or**
4. it was started by a game launcher or mod manager that is still running:
   Steam, GOG Galaxy, Battle.net, the EA app, Epic, Vortex, BG3 Mod Manager,
   Mod Organizer or Playnite, **or**
5. its window fills the whole screen with no title bar.

The launchers' own windows (Steam's store and library, Big Picture, Playnite's
fullscreen mode) never count, so browsing your library leaves your hotkeys on.
Rules 4 and 5 skip browsers, video players (including Store apps like Movies &
TV), PowerPoint slideshows, Remote Desktop, virtual machines, Task View and the
lock screen, so a fullscreen video, or a browser opened from a link in Steam,
doesn't turn your hotkeys off either.

## Adjusting it

Pass an object instead of `true` to change any of these:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Start({
    GameMode: {
        ToggleKey: "^!g",                               ; the default
        Games: ["minecraft.exe"],                       ; always a game
        NotGames: ["blender.exe"],                      ; never a game
        Folders: ["D:\Games\"],                         ; more game folders
        Launchers: ["lutris.exe"],                      ; more launchers
        Fullscreen: true                                ; rule 5; false turns it off
    }
})
```

- Names are the program's file name, as Task Manager's **Details** tab shows
  it. Case doesn't matter.
- `Folders` and `Launchers` add to Legend's own lists; they don't replace them.
- A folder matches anywhere in the program's path, so `D:\Games\` covers
  everything under it.

## When it gets it wrong

- **A game isn't detected:** add it to `Games`, or its folder to `Folders`.
  Until you reload the script, press **Ctrl+Alt+G**.
- **Your hotkeys stop in an app that isn't a game:** add it to `NotGames`. A
  fullscreen app you don't want counted at all can also be handled by setting
  `Fullscreen: false`.
- **A game run as administrator:** Legend may not be able to read where it's
  installed, so rule 3 can't see it. The other rules still work, and a script
  that isn't elevated can't take keys from an elevated window anyway.

Options are in the [reference](../reference.md#gamemode-options).
