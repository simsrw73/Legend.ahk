# Legend game mode: design

Game mode suspends every hotkey in the host script while a game has focus, and
resumes them when the game loses focus. A toggle key switches it by hand.

## Why

Games hold Alt while pressing letters. In the author's setup, Alt+W/A/S/D fired
Legend's window switchers (`!a`, `!s`) and komorebi workspace keys (`!1`–`!9`)
mid-game, and the switcher popup took focus. The fix the author wants is for the
whole script to go quiet in games, not just Legend's own keys.

## Goals

- An opt-in `GameMode` option to `Legend.Start`. Off unless the user sets it.
- When it is on and the foreground window is a game, the **whole script** is
  suspended (AutoHotkey `Suspend`), including hotkeys the host registered
  without Legend. Turning the option on is the user's explicit consent to that.
- Detection that does not depend on how the game was started (Steam, a mod
  manager, a script extender, a desktop shortcut).
- A toggle key that switches game mode on or off on the spot.
- Users can add to or override every built-in list.

## Non-goals

- Suspending only Legend's own hotkeys. (There is one level: on means the whole
  script.)
- Remembering manual toggles per game. The toggle is just a toggle.
- Detecting whether a game is *running* in the background: only the focused
  window matters.
- Any on-screen indicator beyond AutoHotkey's own suspended tray icon (the
  author's call; a builder may revisit if it turns out to be invisible in
  practice).

## Anti-goals

- Game mode suspending hotkeys while the user browses a launcher's store or
  library (Steam's `steamwebhelper.exe`, the EA app's web views, etc.). That
  would make it worse than nothing.
- A detection miss or false positive that the user can't immediately fix from
  the keyboard.
- Any change in behaviour for users who don't set `GameMode`.

## Configuration

```ahk
Legend.Start({
    GameMode: {
        ToggleKey: "^!g",                                ; manual on/off
        Games: ["minecraft.exe"],                        ; always a game
        NotGames: ["vlc.exe"],                           ; never a game
        Folders: ["D:\SteamLibrary\steamapps\common"],   ; extra library folders
        Launchers: ["Playnite.DesktopApp.exe"],          ; extra launchers
        Fullscreen: true                                 ; fullscreen fallback
    }
})
```

- `GameMode` absent, `""` or `false`: game mode is off and Legend does nothing
  new (no hook, no hotkey).
- `GameMode: true`: on, with every default.
- An object: on, with each property overriding its default. Unknown properties
  produce a Legend warning (the existing `Warnings` mechanism).
- `Folders` and `Launchers` **add to** Legend's built-in lists; they never
  replace them. `Games` and `NotGames` have no built-in entries; they are the
  user's overrides. (A user who wants a built-in match undone puts the exe in
  `NotGames`; the built-in fullscreen exclusions below are separate and apply
  only to the fullscreen rule.)
- Exe names compare case-insensitively. Folder entries match as a
  case-insensitive substring of the full exe path, so both
  `\steamapps\common\` and `D:\SteamLibrary\steamapps\common` work.

| Property | Type | Default |
|---|---|---|
| `ToggleKey` | Hotkey | `"^!g"` (Ctrl+Alt+G); `""` = none |
| `Games` | list of exe names | `[]` |
| `NotGames` | list of exe names | `[]` |
| `Folders` | list of path fragments | `[]` (added to built-ins) |
| `Launchers` | list of exe names | `[]` (added to built-ins) |
| `Fullscreen` | true/false | `true` |

## Detection

Legend classifies the foreground window's process. The first rule that answers
wins:

1. **`NotGames`**: never a game.
2. **`Games`**: always a game.
   *(Amended after review:)* a launcher or launcher helper (lists in rule 4) is
   never a game past this point, by any rule, so Big Picture and Playnite's
   fullscreen library don't suspend.
3. **Install path**: the exe's full path contains a library folder. Built-ins:
   `\steamapps\common\`, `\GOG Games\`, `\GOG Galaxy\Games\`, `\EA Games\`,
   `\Epic Games\`, `\XboxGames\`. Battle.net games install wherever the user
   chooses, so they rely on rule 4. (`\WindowsApps\` is not a built-in: every
   Store app lives there, not just games.)
4. **Launcher ancestry**: walking up the parent chain reaches a known launcher
   or mod manager. Built-ins: `steam.exe`, `GalaxyClient.exe`, `Battle.net.exe`,
   `EADesktop.exe`, `EpicGamesLauncher.exe`, `Vortex.exe`,
   `BG3ModManager.exe`, `ModOrganizer.exe`, `Playnite.DesktopApp.exe`,
   `Playnite.FullscreenApp.exe`. A built-in list of **launcher helpers** never
   counts as a game even with a launcher parent: `steamwebhelper.exe`,
   `GalaxyClientHelper.exe`, `EpicWebHelper.exe`, `QtWebEngineProcess.exe`,
   `CrashReportClient.exe`, and the launchers themselves. Electron launchers
   (Vortex) spawn children with the launcher's own exe name; a child whose exe
   name equals a launcher's is not a game.
   The walk stops at a dead or reused parent PID (a parent whose creation time
   is later than the child's is a reused PID, not the real parent).
5. **Fullscreen** (if `Fullscreen` is true): the window has no caption and its
   extended frame bounds (`DwmGetWindowAttribute(9)`) cover its whole monitor,
   in physical pixels. The desktop (`Progman`, `WorkerW`), the shell and
   Legend's own windows never count. Neither do these built-in **fullscreen
   exclusions** (the author's decision). *(Amended after review:)* they also
   apply to rule 4, so a browser started from a link in Steam isn't a game; an
   exe in a game library (rule 3) is unaffected. Users extend them through
   `NotGames`.
   - Browsers: `chrome.exe`, `msedge.exe`, `firefox.exe`, `brave.exe`,
     `vivaldi.exe`, `opera.exe`, `arc.exe`, `zen.exe`
   - Video players: `mpv.exe`, `vlc.exe`, `mpc-hc64.exe`, `mpc-hc.exe`,
     `mpc-be64.exe`, `PotPlayerMini64.exe`, `Microsoft.Media.Player.exe`,
     `Video.UI.exe`
   - Slideshows: `POWERPNT.EXE`
   - Remote desktops and VMs: `mstsc.exe`, `msrdc.exe`, `vmconnect.exe`,
     `vmware.exe`, `vmware-vmx.exe`, `VirtualBoxVM.exe`
   - *(Added after review:)* Task View and the lock screen: `explorer.exe`,
     `LockApp.exe`; the frame around Store apps, which owns their fullscreen
     window: `ApplicationFrameHost.exe`
6. Otherwise: not a game.

If the exe path can't be read (an elevated or protected process), rules 1–2
still use the exe name if readable, rule 3 is skipped, and rules 4–5 still run.

The classification is cached per process (PID plus creation time, so a reused
PID isn't mistaken for the old process). Fullscreen is a property of the
window, not the process, and is re-checked on each focus change.

## When it runs

- Legend hooks foreground changes (`SetWinEventHook`, `EVENT_SYSTEM_FOREGROUND`)
  only when game mode is on. No polling timer.
- On each foreground change: classify, then suspend if it's a game, resume if
  it isn't.
- Legend only resumes a suspension **it** caused. If the host or the user
  suspended the script some other way (tray menu, their own `Suspend`), Legend
  leaves it suspended. *My call:* avoids fighting the host.
- When Legend suspends, any open Legend interaction (overlay, chord, picker) is
  closed first, since their input hooks are not covered by `Suspend`.
- Fullscreen can change without a focus change (a game going fullscreen after
  launch). *My call:* also re-check on `EVENT_OBJECT_LOCATIONCHANGE` for the
  foreground window only, or a builder-chosen equivalent; no polling. This
  re-check can only suspend (not-a-game → game for the same window); it never
  resumes, and it does nothing while a manual override is in effect.

## The toggle key

- Default `^!g` (Ctrl+Alt+G), the author's decision; `ToggleKey: ""` registers
  none.
- Registered with the Suspend-exempt option (`Hotkey(key, fn, "S")`), so it works
  while everything else is suspended.
- Pressing it flips the script's actual state (`A_IsSuspended`) immediately:
  suspended → resumed, resumed → suspended. It doesn't wait for focus to change.
  (The author: "The manual toggle is just a toggle.")
- *My call:* it flips the state even if something other than Legend suspended
  the script; afterwards Legend treats the state as its own.
- *My call:* a toggle sets a **manual override** for the current foreground
  window. Only a real foreground change (a different window) clears it; until
  then detection, including the fullscreen re-check, leaves the state alone.
- *My call:* no overlay entry is generated for it. Users who want it listed add
  it to one of their pages with `Legend.Doc`; the guide shows how.

## Testability

- The classifier is a pure function over a process description
  (`{Exe, Path, Ancestors: [exe…], Fullscreen}`) plus the configured lists, so
  tests cover every rule without real processes.
- The Win32 side (reading path, parent chain, creation time, window bounds; the
  WinEvent hook; `Suspend`) sits behind a small injectable seam, like
  `Registry.Binder`, so tests drive foreground changes and observe suspend calls.
- Tests cover the anti-goal: `steamwebhelper.exe` under `steam.exe` is not a game.

## Docs

- `docs/reference.md`: the `GameMode` option and its properties table.
- A guide section (likely `docs/guide/`): what it does, that it suspends the
  whole script, how to add a library folder, the toggle key, `#SuspendExempt`
  for keys the user wants to keep working.
- `docs/troubleshooting.md`: "a game isn't detected" / "my hotkeys stopped in
  a non-game".

## Left to the builder

- Exact Win32 calls for parent PID and creation time (Toolhelp snapshot vs
  `NtQueryInformationProcess`/`GetProcessTimes`).
- Module name and file (a new `src/GameMode.ahk` fits the structure).
- Validation messages for bad option values.
