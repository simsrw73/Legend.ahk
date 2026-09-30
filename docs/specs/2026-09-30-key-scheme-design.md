# Legend key scheme: design

One set of navigation keys for every Legend overlay: the Alt+/ reference,
chord menus and pickers. What a user learns in one works in the others.

## Goals

- The same key does the same thing wherever it applies: Ctrl+N/P always move a
  cursor, Ctrl+F/B always change screens.
- Alt+/ menus (the index and category lists) get a cursor, so they can be
  browsed like a picker.
- Footers use the same key names and wording in every mode.

## Non-goals

- A cursor on flat Alt+/ pages (lists of shortcuts). Their rows can't be
  opened, and running a bound shortcut from the overlay is a separate idea.
- A cursor in chord menus. Chords are for typing keys, often before the menu
  shows.
- A setting to choose between key schemes.

## The scheme

| Key | Alt+/ menu (index, categories) | Alt+/ flat page | Chord menu | Picker |
|---|---|---|---|---|
| Ctrl+N / Ctrl+P | move cursor | — | — (reaches items) | move cursor |
| ↓ / ↑ | move cursor | — | — | move cursor |
| Ctrl+F / Ctrl+B, PgDn / PgUp | next / previous screen | same | same | same |
| Space | next screen | next screen | reaches items | — |
| Enter | open the selected item | — | — (reaches items) | pick |
| letter | open | — | run | pick |
| Ctrl+T | — | — | — | next scope |
| Backspace | back | back | back | edits the filter |
| Esc / Ctrl+G | close | close | close | cancel (Esc clears a filter first) |

- Pickers keep j/k (rows), h/l (scope), and trigger / Shift+trigger (rows) as
  undocumented extras; they are left out of footers and the README table.
- "— (reaches items)" in a chord means the overlay doesn't claim the key, so a
  chord item bound to it still runs. As today, chord items are matched before
  the overlay's own keys, so a chord that binds Ctrl+F keeps it.
- Tab (key notation), `=` (density) and `` ` `` (pin) are unchanged.
- Pinned Alt+/ still passes every Ctrl/Alt/Win shortcut to the app, including
  Ctrl+N/P/F/B.

## Alt+/ cursor

- Menu levels (the index, "Legend › this window", a page's category list) have
  a cursor on one item. It starts on the first item each time a level is
  opened or returned to with Backspace.
- Ctrl+N / ↓ and Ctrl+P / ↑ move it one item, wrapping at the ends. The
  current screen follows the cursor, so moving past the last item on a screen
  shows the next one.
- Ctrl+F/B, PgDn/PgUp and Space change screens and put the cursor on the first
  item of the new screen.
- Enter opens the item under the cursor, exactly as its letter would.
- The selected row is drawn on a bar in the theme's `selection` color, with its
  text in `selectionText`, the same way as picker rows.
- Tab and `=` (which rebuild the levels) keep the cursor on the same item.

## Footers

| Mode | Footer |
|---|---|
| Alt+/ menu | `↵ open · ^n/^p move · ^f/^b 2/3 · ⌫ back · \` pin · … · esc close` |
| Alt+/ flat page | `^f/^b 2/3 · ⌫ back · \` pin · … · esc close` |
| Chord | `esc close · ⌫ back · ^f/^b 1/2 · …` |
| Picker | `↵ pick · ^n/^p move · / filter · ^t scope · = density · esc close` |

The screen counter (`2/3`) appears only when there is more than one screen;
`…` stands for the display toggles each mode already shows.

## Changed for existing users

- In Alt+/ and chord menus, Ctrl+N/P no longer page; they move the cursor
  (Alt+/) or reach chord items. Page with Ctrl+F/B, PgDn/PgUp or Space.
- The README gets a short "Changed" note, and the three specs are updated where
  they list keys.

## Where the changes go

| Unit | Change |
|---|---|
| `src/Navigator.ahk` | Menu levels get `Cursor`. `Press("Down" / "Up")` moves it (wrapping, following screens); `Press("Enter")` opens it; screen changes reset it to the screen's first item; `View` marks the selected row. Flat pages ignore Down, Up and Enter. Relayout keeps the cursor. |
| `src/Rows.ahk` | Rows carry `Selected`. |
| `src/Overlay.ahk` | `Show` draws the selection bar behind a selected row. |
| `Legend.ahk` | Reference key map: Ctrl+N/P and ↓/↑ → Down/Up, Ctrl+F/B → Next/Prev, Enter → Enter; the key watcher claims Ctrl+F/B. Chord overlay keys: Ctrl+F/B and PgDn/PgUp. |
| `src/Picker.ahk` | Ctrl+F/B page; Ctrl+T next scope; footer wording. |
| README, specs | Key tables, the "Changed" note. |

## Testing

- `tests/Navigator.Tests.ahk`: the cursor starts on the first item; Down/Up move
  and wrap; the screen follows the cursor; paging moves the cursor to the
  screen's first item; Enter opens the selected item; Backspace returns with
  the cursor on the first item; flat pages ignore Down/Up/Enter; Relayout
  keeps the selected item; existing paging tests use Next/Prev as before.
- `tests/Rows.Tests.ahk` / `tests/Overlay.Tests.ahk`: the selected row is
  marked and measured like any other row.
- `tests/KeyWatch.Tests.ahk`: Ctrl+F/B, claimed while the overlay is open,
  don't count as closing combos.
- `tests/Picker.Tests.ahk`: Ctrl+F/B page, Ctrl+T cycles scopes, and the footer
  text.
- By hand: Alt+/ index and category menus with the cursor (scripted screenshot,
  then the author), chord paging with Ctrl+F/B, and a chord that binds Ctrl+F.
