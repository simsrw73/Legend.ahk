# Legend picker and window switcher: design

Third mode of Legend (see "Modes" in `2026-09-28-legend-design.md`). A picker
is a hotkey that opens a list with a selection cursor: move, filter, and pick a
row. The window switcher is a picker whose rows are windows, a home-row
alternative to Alt+Tab. Neither depends on komorebi or any window manager;
hosts add that through hooks.

## Goals

- A generic, reusable picker: any host can list items and act on the pick.
- A window switcher built on it that other users can turn on with one line.
- One hotkey per switcher, each with its own scope (all windows, current
  virtual desktop, current monitor), usable at any time.
- The same renderer, theme, density and legend settings as the Alt+/ overlay.
- Pickers appear in the Alt+/ reference, like chords.

## Non-goals

- Live window thumbnails.
- Fuzzy matching (substring terms first; revisit if missed).
- Hold-the-modifier-and-release activation. The picker is modal: Enter or a
  letter picks, Esc cancels.
- Undocumented Windows APIs (see "Virtual desktops").

## API

```ahk
Legend.Picker("!e", "Recent files", scope => RecentItems(), {
    OnPick: item => Run(item.Data),
    OnHighlight: item => "",        ; optional
    OnCancel: () => "",             ; optional
    Start: 1,                       ; optional, row selected at open
    Scopes: ["Today", "This week"], ; optional, h/l cycle them
    Scope: "Today",                 ; optional, scope at open (default Scopes[1])
    Density: "compact",             ; optional, overrides the theme's density
    Match: "ahk_exe code.exe",      ; optional, trigger only in matching windows
    Reference: true                 ; optional, false hides it from Alt+/
})

Legend.WindowSwitcher("!a", {Scope: "all"})
Legend.WindowSwitcher("!s", {Scope: "monitor"})
Legend.WindowSwitcher("!d", {Scope: "desktop", Scopes: ["desktop"]})
```

- `Legend.Picker(hotkey, title, source, options?)` registers `hotkey` through
  the registry's `Binder`. `source(scope)` is called each time the picker
  opens and each time the scope changes. It returns an array of items; `scope`
  is `""` when the picker has no `Scopes`.
- An item is `{Text, Detail?, Icon?, Letter?, Data?}`. `Icon` is an HICON or
  `""`. `Letter` asks for a fixed letter (honoured if free and allowed).
  `Data` is the host's own value, passed back untouched.
- `OnPick(item)` is required. `OnHighlight(item)` runs on every selection
  change, including at open and when the filter changes the selection.
  `OnCancel()` runs when the picker closes without a pick. `OnPick` and
  `OnCancel` run after the overlay is gone, with Critical off.
- `Legend.WindowSwitcher(hotkey, options?)` is `Legend.Picker` with the window
  source, peek/outline highlight and activation below. Title: `Windows`.
  Options: `Scope` (default `"all"`), `Scopes` (default
  `["all", "desktop", "monitor"]`), `Start` (default `2`), `Include`,
  `Activate`, `Detail`, plus the picker options `Density`, `Match` and
  `Reference`.
- Both return the created picker object, for tests.

## Behaviour

### Opening

- The trigger calls `source(scope)` and draws the list at once (no delay:
  a picker is useless unseen).
- The cursor starts at `Start`, clamped to the list. An empty list shows
  "Nothing to pick" (`No windows` for the switcher); Esc still works.
- A second picker trigger while one is open: the same trigger moves the cursor
  down, Shift+trigger moves it up; any other picker's trigger is swallowed.
- Opening a picker closes the Alt+/ overlay or an open chord first, and vice
  versa.

### Normal mode

| Key | Effect |
|---|---|
| J / K, ↓ / ↑, Ctrl+N / Ctrl+P | move the selection; wraps |
| trigger / Shift+trigger | move down / up |
| H / L | previous / next scope (no-op with 0–1 scopes) |
| PgDn / PgUp | next / previous screen |
| assigned letter | pick that row |
| Enter | pick the selected row |
| `/` | enter filter mode |
| `=` | toggle density (until reload, like Alt+/) |
| Esc, Ctrl+G | cancel |
| focus moves to another window | cancel |

Tab (key notation) does nothing in a picker.

### Letters

Assigned from the pool `a s d f g ; q w e r t y u i o p z x c v b n m 1–9 0`
in that order. h/j/k/l are never assigned, and neither is `/`. An item's fixed
`Letter` wins if it is in the pool and free; rows beyond the pool get none.
Letters are assigned over the filtered list, top to bottom.

### Filter mode

- Printable keys append to the query; Backspace deletes (Backspace on an empty
  query leaves filter mode). The query is shown in the title line:
  `Windows / zen yt▏`.
- A row matches when every space-separated term is a case-insensitive
  substring of `Text` or `Detail`.
- The first match is selected after every change; letters are hidden.
- ↓ / ↑, Ctrl+N / Ctrl+P and the trigger move; J/K and `=` type.
- Enter picks. Esc clears the query and returns to normal mode; a second Esc
  cancels.

### Serialization

Picker keys, highlight callbacks, redraws and closing run through
`Legend.Serialized`, as chord keys do. Keys are captured with a suppressing
`InputHook` (the chord pattern: `{All}` `+SN`, modifiers unsuppressed); a
key handled while another is being drawn is queued, never dropped.

## Window switcher

### Window list (`LegendWindows`)

`LegendWindows.List(options)` returns switchable windows front to back as
`{hwnd, title, app, icon, x, y, w, h, monitor, minimized, cloaked, desktop}`.
All geometry is physical pixels: the enumeration runs with the thread set to
per-monitor DPI awareness v2, and bounds come from
`DWMWA_EXTENDED_FRAME_BOUNDS` (falling back to `WinGetPos`).

A window is switchable when it is visible (`WS_VISIBLE`), titled, not a tool
window (`WS_EX_TOOLWINDOW`), not the desktop or taskbar (`Progman`, `WorkerW`,
`Shell_TrayWnd`, `Shell_SecondaryTrayWnd`), and either:

- not cloaked, or
- cloaked but on a virtual desktop (a non-null `GetWindowDesktopId`), or
- let in by the host's `Include(hwnd)` hook.

A cloaked window with no desktop and no `Include` is a background ghost (a
suspended UWP app) and is dropped.

Options: `Minimized` (include minimized windows; default `true`),
`VisibleOnly` (drop windows less than `MinVisibleShare` uncovered; default
`false`), `Include`.

`LegendWindows.Coverage` holds the visible-area check: GDI regions, windows
fed top first, each window's on-screen area minus what was already covered.
The host's `WindowFocus` (directional focus) uses `LegendWindows.List` with
`VisibleOnly: true, Minimized: false` instead of its own enumeration.

### Scopes

| Scope | Rows |
|---|---|
| `all` | every switchable window, on every virtual desktop |
| `desktop` | windows on the current virtual desktop |
| `monitor` | `desktop`, and on the monitor of the window that was active at open |

"On the current virtual desktop" is `IVirtualDesktopManager::
IsWindowOnCurrentVirtualDesktop`. A window let in by `Include` counts as on the
current desktop when that call says so; its monitor is the one containing its
top-left corner (nearest monitor if off-screen). The title shows the scope:
`Windows · this monitor`.

### Rows

- Text: the window title. Detail: the host's `Detail(hwnd)` if given,
  otherwise the process name without `.exe`; `(minimized)` and, for a window
  on another virtual desktop, `· desktop N` are appended.
- Icon: `WM_GETICON` (`ICON_SMALL2`, then `ICON_SMALL`, `ICON_BIG`), then the
  class icon, then the first icon of the process's exe. Cached by hwnd for the
  life of the picker, destroyed only when Legend extracted it.
- The window active at open is row 1, so `Start: 2` preselects the previous
  window and trigger → Enter matches a quick Alt+Tab.

### Highlight: peek and outline

On highlight of a window that is neither minimized nor cloaked:

- Peek: raise it to the top of the z-order with `SetWindowPos(…,
  SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOSIZE)`, remembering the window that was
  above it. The next highlight or a cancel puts it back after that window;
  a pick leaves it where activation puts it.
- Outline: a click-through (`WS_EX_TRANSPARENT | WS_EX_LAYERED`), always-on-top,
  non-activating border in the theme's `outline` color around its visible
  bounds, 4 px, drawn just below the overlay.

Minimized and cloaked windows get neither; their row detail says why they are
not shown. Both effects are removed when the picker closes.

### Pick

The host's `Activate(hwnd)` if given; otherwise restore the window if
minimized and `WinActivate` it. If the window no longer exists, a tooltip says
"Window closed" for a second.

### Virtual desktops

Only the documented `IVirtualDesktopManager` is used. Activating a window on
another desktop relies on `WinActivate` making Windows switch desktops.
**Implementation step 1 is a spike** on the author's machine: if that switch is
not reliable, pick falls back to `MoveWindowToDesktop(hwnd, current desktop)`
and the README documents that picking a window on another desktop brings it
to the current one.

### Komorebi (host side, not in Legend)

The dotfiles pass the same hooks to each switcher:

- `Include`: `Komorebi.WorkspaceOf(hwnd) != ""` (windows cloaked on other
  workspaces), queried once per open, not per window.
- `Activate`: `WindowLauncher.Activate`, which focuses the workspace first.
- `Detail`: the app name plus `· <workspace>` for managed windows.

## Drawing

Pickers reuse `LegendOverlay`: the same GUI, rounding, opacity, fonts,
padding, row spacing and placement (centered on the active monitor).

- A row: icon (16 px compact, 20 px comfortable) · letter (`keyBound`) · text
  (`description`) · detail right-aligned (`footer`).
- The selected row: `selection` background, `selectionText` for its text and
  detail.
- Width: capped by `maxWidthPercent`; text is cut with an ellipsis, the
  detail is kept.
- Height: rows beyond `maxHeightPercent` are split into screens with
  `LegendLayout.Paginate` (one column). The screen follows the cursor.
- Footer: `↵ pick · / filter · h/l scope · = density · esc`, dropping `h/l
  scope` without scopes, placed by the `legend` theme setting.
- Every change redraws the GUI, as chord steps do. If that flickers with long
  lists, update only the two changed rows (measure first).

### Theme additions

`[colors]` gains `selection`, `selectionText` and `outline`. When a theme
does not set them: `selection` = `border`, `selectionText` = `title`,
`outline` = `category`. The Catppuccin themes set them explicitly.

## Reference

Every picker with `Reference` not `false` appears on a "Pickers" page of the
Alt+/ reference: the trigger and the title (the switcher's title includes its
starting scope, e.g. `Windows · this monitor`).

## Files

| File | Contents |
|---|---|
| `src/Picker.ahk` | `LegendPicker`: items, cursor, scopes, filter, letters. Pure logic. |
| `src/Windows.ahk` | `LegendWindows`: `List`, `Coverage`, monitors, virtual desktop checks. |
| `src/WindowSwitcher.ahk` | `LegendWindowSwitcher`: source, rows, icons, peek, outline, pick. |
| `src/Overlay.ahk` | picker rows and footer. |
| `src/Theme.ahk` | the three new colors and their fallbacks. |
| `Legend.ahk` | `Legend.Picker`, `Legend.WindowSwitcher`, picker key capture. |

## Testing

- `tests/Picker.Tests.ahk` (pure): wrap-around movement; trigger and
  Shift+trigger; scope cycling calls the source with the right scope; letter
  pool order, never h/j/k/l, fixed letters; filter terms across Text and
  Detail, first match auto-selected, Backspace on an empty query, Esc then
  Esc; `Start` clamped to short lists; empty list.
- `tests/Windows.Tests.ahk`: coverage on injected rectangles (fully buried,
  partly covered, off-screen, exactly `MinVisibleShare`); monitor choice for
  points off every monitor.
- By hand: a `tests/race` script that hammers J/K, letters and triggers and
  checks the overlay is never stranded; peek, outline, cancel-restore,
  minimized windows and virtual desktops in `examples/example.ahk`.
- Syntax checks for the new files through `tests/Run-Tests.ps1`.
