# Legend chord mode: design

Second mode of Legend (see "Modes" in `2026-09-28-legend-design.md`). A chord
is a hotkey that opens a which-key style menu: the next key runs an action or
opens a submenu. It replaces the KeyChord library in the author's dotfiles
without losing any KeyChord feature that wasn't explicitly dropped (see
"KeyChord parity").

## Goals

- Key chords that work with or without a visible menu: fast typists never see
  it, a pause shows it.
- The same renderer, theme, density and key-notation toggles as the Alt+/
  reference overlay.
- Chord trees also appear as pages in the Alt+/ reference.
- No KeyChord dependency.

## Configuration

User-level, in `Legend.Start`:

| Option | Values | Default |
|---|---|---|
| `ChordTimeout` | seconds of inactivity before an open chord closes; `0` = never | `0` |
| `ChordOverlay` | `"always"`, `"never"`, or a delay in ms before the menu appears | `400` |
| `ChordReference` | `false` hides every chord from the Alt+/ reference | `true` |

## API

```ahk
Legend.Chord("#Space", "Launch", [
    Legend.Run("z", "Zed", (*) => WindowLauncher.ActivateOrRun(Apps.Zed),
        {Status: () => WindowLauncher.Find(Apps.Zed)}),
    Legend.Menu("w", "Research", [
        Legend.Run("b", "Brave", (*) => WindowLauncher.ActivateOrRun(Apps.Brave))
    ]),
    Legend.Run("s", "Sign-off", "Regards,{Enter}Randy"),
    Legend.Run("t", "Terminal here", OpenTerminalHere,
        {If: () => WinActive("ahk_exe explorer.exe"), Hint: "in Explorer"}),
    Legend.Run("t", "TickTick", LaunchTickTick),
    Legend.Run("^s", "Save all", SaveAll),
    Legend.Run("1-9", "Workspace 1–9", key => Komorebi.FocusWorkspace(key)),
    Legend.Run("Space", "Flow Launcher", (*) => Send("^``"))
])
```

- `Legend.Chord(hotkey, title, items, options?)` registers `hotkey` (through
  the registry's `Binder`) to open the chord. Options: `Match` (WinTitle
  criteria; the trigger only works in matching windows, like a page's code
  `match`), `Reference` (`false` hides this chord from the reference).
- `Legend.Run(key, label, action, options?)`: `action` is a function or a
  string. A string is sent with `Send`. A function is called with the pressed
  key's name when it accepts a parameter (`fn.MaxParams >= 1` or variadic),
  otherwise with no arguments. Options: `If` (function returning true/false;
  the item is skipped when false), `Status` (function returning true/false,
  drawn as a dot), `Hint` (short text describing `If`, shown in the reference).
- `Legend.Menu(key, label, items)`: a submenu, nestable to any depth. Takes no
  options (KeyChord also never allowed conditions on nested chords).
- `Run` and `Menu` return `LegendChordItem` objects
  `{Key, Label, Action, Items, If, Status, Hint}` (`Action` for runs, `Items` for
  menus). A chord is `{Hotkey, Title, Items, Match, Reference}`, held by the
  registry.

### Keys

A chord key is an AHK key name, optionally with modifier prefixes (`z`,
`Space`, `F5`, `^s`, `+a`), or a wildcard, optionally with modifier prefixes:

| Pattern | Matches |
|---|---|
| `?` | any single character key (`a`, `9`, `;`; not `F1`, `PgUp`) |
| `F*`, `Num*`, `*PgUp` | key names matching the glob (`*` = any run of characters) |
| `a-f`, `1-9`, `,-/` | any single unshifted character key whose code point is in the inclusive range |
| `^a-f` | the pattern with Ctrl held |

Keys are matched as the unshifted key plus modifiers, as KeyChord did: a
single character means the key itself, so Shift+; is `+;` (not `:`), and
Shift+A is `+a`. Matching compares modifiers exactly (a plain `z` item does not match
Ctrl+Z). Unknown key names in items throw `ValueError` when `Legend.Chord`
runs, like `Legend.Doc`.

### Lookup

On each key press the current level's items are searched in order; the first
item whose key matches and whose `If` is true (or absent) wins. Exactly one
action runs per key press.

## Runtime (`LegendChord` controller)

- The trigger starts a suppressing `InputHook` (all keys `+ES` except
  modifiers, which pass through) driven by callbacks, not a blocking `Wait`,
  so timers run alongside it.
- Modifiers held when the chord opened are ignored until released; once
  released and pressed again they count (so `^s` steps work after
  Win+Space).
- Per key:
  - Menu item → descend one level; redraw if the menu is visible.
  - Run item → close the menu, stop the hook, then run the action.
  - No match → close and show a 1-second tooltip "Nothing on <key>" (key in
    the current notation), whether or not the menu was visible.
- Reserved keys: **Esc** and **Ctrl+G** close; **Backspace** goes up one level
  (closes at the top); the full trigger pressed again (its modifier re-pressed)
  closes. While the trigger's modifier is still held from opening, the trigger's
  key is an ordinary chord key (Win held, Space → a `Space` item); the trigger
  key's own auto-repeat, before it is first released, is ignored. Keys pressed
  with Alt or Win held are followed by a masking key so releasing the modifier
  does not open the Start menu or a menu bar.
- Overlay keys, active only while the menu is visible and only when no item at
  the current level matches the key: **PgDn / Ctrl+N** next screen, **PgUp /
  Ctrl+P** previous screen, **Tab** cycle notation, **=** flip density. Chord
  items always take precedence over overlay keys.
- Closes on its own after `ChordTimeout` seconds without a key (reset at every
  step; closes quietly), or when the active window changes.
- `ChordOverlay`: `"always"` shows the menu at once; `"never"` never shows it;
  a number shows it after that many ms unless a key completes the chord first.
  Descending into a submenu before the menu appears keeps the original timer.

## Chord menu display

- Same `LegendOverlay`, theme, density and notation as the reference.
- Title = chord title, then ` › ` submenu labels.
- Rows: key, label; menu items end with ` ›`; items with `Status` show a dot
  in the new theme colors `indicatorOn` (true) / `indicatorOff` (false),
  evaluated when the level is drawn.
- Items whose `If` is false are hidden; when several items share a key, only
  the first whose `If` is true is shown.
- Plain single-character keys display lowercase in chord menus and
  sequences (`z`, not `Z`), since that is what you press; modifiers and named
  keys follow the notation (`Ctrl+S` / `⌃S` / `^s`). Wildcards display as
  written, with `-` in ranges shown as `–`.
- Footer: `esc close · ⌫ back`, plus `pgdn/^n pgup/^p` when there is more than
  one screen, and the Tab / `=` display hints.

## Reference pages

When the reference overlay opens, each chord (unless hidden) is converted into
a page:

- Title = chord title; `match` = the chord's `Match`.
- One category per menu level, in tree order: `Launch`, `Launch › Research`, …
- Entries show the full sequence and label: `Win+Space z  Zed`,
  `Win+Space w  Research ›`, `Win+Space w b  Brave`. Sequences are verbatim
  keys (never merged with other entries) drawn as bound.
- Conditional items are all listed, with `(Hint)` appended when given.
- No status dots.
- If a code page or page file already uses the chord's title, the chord's
  entries are added to that page under their own categories.

## Reference-mode additions

The reference overlay gains the same secondary keys: **Ctrl+N / Ctrl+P** next
/ previous screen, **Ctrl+G** close. While the reference overlay is **pinned**
they are not claimed (Ctrl+N, Ctrl+P, Ctrl+G reach the app). When claimed,
`LegendKeyWatch` must not treat them as closing combos (its claimed list
accepts key ids such as `Ctrl+N`, not only single characters).

## KeyChord parity

| KeyChord feature | Legend chord mode |
|---|---|
| Nested chords | kept: `Legend.Menu` |
| Function actions | kept, and wildcard actions receive the pressed key |
| String / number actions (`Send`) | kept |
| Modifier steps (`^s`) | kept |
| Timeout | improved: user-level, `0` = none (KeyChord required > 0) |
| Conditions; first true wins | kept: `If` |
| Run modes last / all | **dropped** (decided: one function per key press) |
| Wildcards `?`, `*`, ranges | kept, same syntax |
| Mouse buttons as chord keys, click-blocking overlay | **dropped** (decided) |
| Help window | replaced by the chord menu and reference pages |
| `RemindKeys` | replaced by `ChordOverlay` delay |
| "Press a key…" tooltip | replaced by the menu |
| "Key not found" tooltip | kept as "Nothing on <key>" |
| Map-style API (`Set`, `Get`, `Merge`, `Transform`, `Find*`, `ToString`, enumeration, `MatchKey`) | **dropped** (decided) |
| Readable key names | replaced by Legend notation |

## Modules

| File | Change | Unit-tested |
|---|---|---|
| `src/ChordMatch.ahk` (new) | `LegendChordMatch`: parse and match key patterns | yes |
| `src/Chord.ahk` (new) | `LegendChordItem`; `LegendChords`: registry of chords, first-true lookup, held-modifier filter, reference page generation | yes |
| `src/Navigator.ahk` | chord levels (visible items, first-true per key, `›`, status); `Press` returns `"run"` with `RunItem`; `OpenChord(chord)` | yes |
| `src/Rows.ahk` | rows gain `Status` | yes |
| `src/Theme.ahk` | `indicatorOn` (`A6E3A1`), `indicatorOff` (`45475A`); Latte `40A02B` / `BCC0CC` | yes |
| `src/Overlay.ahk` | status dot | manual |
| `Legend.ahk` | `Chord` / `Run` / `Menu`; `Start` options; chord controller; Ctrl+N/P/G in both modes | manual |

## Testing

- Unit: pattern matching (every row of the Keys table, modifiers exact,
  unknown names throw); lookup order with `If`; held-modifier filter;
  reference page generation (categories per level, sequences, hints, hidden
  chords, merge into an existing page); navigator chord levels (hidden false
  items, duplicate keys, `run` result, Backspace, status in rows); theme
  indicator colors.
- Manual (example script gets a demo chord):
  - Fast trigger + key runs with no menu flicker; a pause shows the menu after
    400 ms; `"always"` / `"never"` behave.
  - Submenus, Backspace, Esc, Ctrl+G, trigger-again close.
  - Clicking another window closes the chord; the next key goes to that window.
  - "Nothing on x" with the menu hidden and shown.
  - Status dots follow running apps.
  - Space bound as a chord item still runs it; Tab and `=` work in the menu.
  - `^s`-style step after Win+Space; wildcard `1-9` passes the digit.
  - `ChordTimeout: 3` closes after 3 s idle.
  - Chord page in Alt+/; Ctrl+N/P/G in reference mode, not while pinned.

## Dotfiles migration (separate plan)

`Chords.ahk` switches to `Legend.Chord`; `ChordLaunch` / `ChordSubmenu` /
`ChordAction` become one-line wrappers around `Legend.Run` / `Legend.Menu`
(`ChordLaunch` adds `Status`). `ChordOverlay`, the KeyChord include and the
KeyChord submodule are removed; the structure test is updated.
