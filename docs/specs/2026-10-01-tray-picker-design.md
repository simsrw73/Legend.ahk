# Legend tray picker (extra): design

> **Shelved 2026-10-01.** Built and reviewed on the local branch
> `shelved/tray-picker`, then backed out after hand testing: too flaky to ship.
> On the author's machine the first hotkey press flashed the overflow flyout and
> the picker, then closed it (the second press worked); Shift+Enter's real
> right-click left the flyout and the app's menu open at the tray, as if a mouse
> had done it. Reading the tray through UI Automation works; acting on it from a
> background script is the weak part. A future attempt should start there (for
> example, yasb-style callback messages; see "Alternatives considered").

A picker over the notification area (system tray): every tray icon, visible or
hidden, by name; Enter left-clicks the selected icon, Shift+Enter opens its
context menu. It is an **extra**: walled off from Legend's core, opt-in, and
documented as possibly brittle, because it relies on how Windows 11 currently
builds its taskbar.

## Findings it rests on (spike, 2026-10-01, Windows 11 build 26220)

- Windows' UI Automation exposes the tray: `Shell_TrayWnd` holds the visible
  icons (AutomationId `NotifyItemIcon`) and system icons (`SystemTrayIcon`:
  volume, network, clock…) plus the "Show Hidden Icons" button. Hidden icons
  live in a separate window, `TopLevelWindowForOverflowXamlIsland`, which only
  has them while its flyout is open (37 on the author's machine).
- An icon's Name is its tooltip text: sometimes empty, sometimes several lines,
  sometimes the same app more than once.
- Invoke on an icon left-clicks it (opened Everything from a hidden icon).
- Focusing an icon (SetFocus) and sending Shift+F10 opens its context menu, for
  classic Win32 menus (Everything) and custom ones (TickTick). Esc closes it.
- The tray interface gives no images and no owning process. Windows' list of
  tray apps, `HKCU\Control Panel\NotifyIconSettings\*`, has each app's
  `ExecutablePath` and often an `InitialTooltip`.
- yasb's own systray doesn't matter: this reads Windows' tray, which still
  exists.

## Alternatives considered

yasb (a status bar) gets perfect tray data a different way: it registers its own
hidden `Shell_TrayWnd` window kept topmost (or injects a DLL into
`explorer.exe`), receives every app's `Shell_NotifyIcon` data (icon image,
tooltip, owner window, icon id, callback message) and forwards it to the real
taskbar; on start it broadcasts `TaskbarCreated` so all apps re-add their icons.
It clicks by sending the app's own callback message (`WM_LBUTTONUP` /
`WM_RBUTTONUP`, `NIN_SELECT` / `NIN_CONTEXTMENU`) after
`AllowSetForegroundWindow`. Exact icons and no flyout, but invasive for an
opt-in library extra: every app's tray calls would pass through the script,
two such programs (yasb and Legend) would fight to be the topmost fake taskbar,
and the robust variant needs a native DLL. Legend reads the tray through UI
Automation instead: read-only, coexists with yasb or the plain taskbar, and
fails with "not available" when Windows changes.

## Goals

- `LegendTray.Picker(hotkey)` opens a picker over all tray icons.
- Enter or a letter left-clicks; Shift+Enter opens the icon's context menu;
  `/` filters by name; the usual picker keys work.
- Icons where a confident match to an app exists; text otherwise.
- Walled off: its own file, not loaded by `Legend.ahk`; a clear "not
  available" result instead of errors when Windows changes.

## Non-goals

- Intercepting tray icon messages (as yasb does). Not needed.
- Capturing the icons' real pixels.
- Windows 10's tray (a different structure); it gets the "not available" result.

## Core change: alternate pick

`LegendPicker` gains two options:

- `OnAltPick(item)`: when set, Shift+Enter picks the selected row with it
  (normal and filter mode). Without it, Shift+Enter does nothing.
- `AltPickLabel`: the footer text for it, default `"alt"`; the footer shows
  `⇧↵ <label>` after `↵ pick`.

`Key` returns `"altpick"` for Shift+Enter when `OnAltPick` is set (and a row is
selected), and `KeyBatch` treats it like `"pick"` (it ends the batch). The
controller closes the picker and runs `OnAltPick(item)` the same way it runs
`OnPick`.

## The extra: `extras/Tray.ahk`

Included explicitly: `#Include Lib\Legend\extras\Tray.ahk` after `Legend.ahk`.
All Windows-specific names (window classes, AutomationIds, the "Show Hidden
Icons" button's AutomationId) are constants at the top of the file.

### `LegendUIA`

A minimal COM wrapper over `IUIAutomation` (`CUIAutomation`), no external
libraries: create the automation object; element from a window handle; find
first / find all by a property condition (ClassName, AutomationId, Name);
an element's Name, AutomationId, ClassName, BoundingRectangle; the Invoke
pattern's `Invoke`; `SetFocus`. COM objects are released when their wrappers
are freed.

### `LegendTray`

- `List()` → `[{Name, Text, Kind, Hidden, Ordinal}]`:
  - `Name` is the raw tooltip; `Text` the cleaned name (first non-empty line,
    trimmed; empty → the matched app's name, else `(no name)`).
  - `Kind` is `"app"` (NotifyItemIcon) or `"system"` (SystemTrayIcon, minus the
    "Show Hidden Icons" button).
  - `Hidden` is true for icons from the overflow flyout.
  - `Ordinal` counts icons with the same `Name` and `Hidden`, so a pick can
    find "the second CrystalDiskInfo icon" again.
  - Reads the visible icons, then opens the flyout, reads the hidden ones and
    closes it (only when the flyout wasn't already open).
  - Returns `[]` and sets `LegendTray.Available := false` when `Shell_TrayWnd`
    or its icons can't be found.
- `Click(item)` / `Menu(item)`: find the icon again by `Name` + `Hidden` +
  `Ordinal` (opening the flyout for hidden ones), then Invoke it, or SetFocus
  and send Shift+F10. After a left-click on a hidden icon the flyout is closed;
  for a menu it stays open under the menu (it closes when the menu does or
  focus moves). If the icon is gone, a tooltip says "Tray icon not found".
- `Clean(name)`, `Match(names, entries)`: pure helpers (unit-tested):
  `Match` pairs tray names with NotifyIconSettings entries
  (`{ExecutablePath, InitialTooltip}`) — a confident match is an entry whose
  `InitialTooltip` equals the name's first line or starts it, or whose exe's
  base name (without `.exe`) appears as a whole word at the start of the name;
  anything else stays unmatched.
- Icons: for matched rows, the exe's first icon (`LoadPicture(path, "Icon1")`),
  owned and destroyed when the picker closes.

### `LegendTray.Picker(hotkey, options?)`

`Legend.Picker(hotkey, "Tray", source, {OnPick: Click, OnAltPick: Menu,
AltPickLabel: "menu", EmptyText: …})` where the source returns rows
`{Text, Detail, Icon, Data}`:

- Detail: the matched app's name (exe base name) for app icons, `system` for
  system icons, plus ` · hidden` for overflow icons.
- Order: visible app icons, then hidden app icons, then system icons.
- EmptyText: `"Tray not available on this Windows version"` when
  `LegendTray.Available` is false, else `"No tray icons"`.
- Options pass through `Match`, `Reference` and `Density`.

### The flyout flash

Opening the flyout to read hidden icons shows it on screen. The plan's first
step is an experiment: make the overflow window fully transparent
(`WinSetTransparent(0)`) as soon as it exists and restore it before closing.
If reading and invoking still work, keep it; otherwise accept the brief flash
and say so in the README.

## Documentation

README gets an **Extras (may break with Windows updates)** section: what the
tray picker does, how to include it, that it relies on Windows 11's current
tray structure (tested on build 26220), and what happens when that changes.
An example, `examples/07-tray-picker.ahk`, shows it on Ctrl+Alt+Shift+T.

## Testing

- `tests/Picker.Tests.ahk`: Shift+Enter returns `"altpick"` only with
  `OnAltPick`, in both modes; `KeyBatch` ends on it; the footer shows the label.
- `tests/Tray.Tests.ahk` (includes `extras/Tray.ahk`): `Clean` (multi-line,
  empty, whitespace); `Match` (tooltip equal, tooltip prefix, exe word, no
  match, duplicate names); `Ordinal` numbering. A live `List()` test that
  checks the result shape and skips itself when `Available` is false.
- By hand (the author): list, left-click, Shift+Enter menu, filter, a hidden
  icon, system icons, and whether the flyout flashes.
