# Legend overlay pipeline: design

One drawing pipeline for every overlay (Alt+/, chords, pickers), so the flicker
fixes pickers got (the selection moves in place instead of rebuilding the
window) apply everywhere.

## Problem

`LegendOverlay.Show` (Alt+/ and chords) and `LegendOverlay.ShowPicker`
(pickers) each build a whole window: frame, title, body, footer, placement.
Only the picker path records the rows it drew and can move its selection in
place (`SelectPickerRow`); the controller check for "only the cursor moved"
lives only in `DrawPicker`. So every cursor move in an Alt+/ menu destroys and
recreates the window, which flickers. The Alt+/ selection bar also reaches past
the last column, so the window widens (and re-centres) when the cursor enters
it.

## Goals

- One frame, one selection mechanism and one "only the cursor moved" check,
  shared by all modes. The two body layouts stay separate: a key table in
  columns and an item list with icons really are different.
- Moving the cursor in an Alt+/ menu never rebuilds the window.
- Moving the selection never changes the window's size or position.

## Non-goals

- Updating rows in place on page changes or filter typing (the rest of the
  flicker backlog item). Those still rebuild.
- Any change to what is drawn: same rows, colors, fonts and footers.

## Units

| Unit | Job |
|---|---|
| `LegendOverlay.Frame(theme, title)` | Creates the window (`+AlwaysOnTop -Caption +ToolWindow -DPIScale`, WS_EX_NOACTIVATE), background, margins, the title. Returns `{Gui, Top}`: the window and the y where the body starts. Alt+/ and chords pass the title upper-cased; pickers pass it as written, as today. |
| `LegendOverlay.Finish(frame, theme, footer, badges?)` | Adds the footer at `frame.Bottom + rowSpacing` and, for Alt+/, the pinned and warning badges; then `Place`. |
| `LegendTableBody.Draw(frame, view, theme, measurer, legendLine)` | Today's `Show` body: columns of headings, groups and entries, and the legend line (top or bottom). Registers every entry row with the selection. Sets `frame.Bottom`. |
| `LegendListBody.Draw(frame, view, theme, measurer, maxWidth)` | Today's `ShowPicker` body: letter · icon · text · detail rows, or the empty text. Registers every row. Sets `frame.Bottom`. |
| `LegendSelection` | Owned by the window (`gui.Selection`). One selection bar (a disabled Progress control in the theme's `selection` color, created before any row so the transparent row controls draw over it). `Add(rect, recolors)` registers a row: its bar rectangle `{X, Y, W, H}` and the controls to recolor, each with its normal and selected color. `Reserve()` is called once after the body is drawn: it adds an invisible, zero-height spacer at the right-most edge any bar can reach, so AutoSize always includes it. `Select(index)` (1-based over registered rows; 0 = none) pauses painting (WM_SETREDRAW), recolors only the rows whose state changed, moves and resizes the bar to the row's rectangle (hides it for 0), resumes painting and repaints just the old and new rows' rectangles. |
| `Legend.Render(layoutKey, build, index)` | The one check. If a window is showing and `layoutKey` equals the key it was built with, `this.Gui.Selection.Select(index)`; otherwise `build()` returns a new window, which replaces (and then destroys) the old one, and the key is remembered. |
| `LegendNavigator.LayoutKey` | A string that changes when the shown level, its screen, the pin state or the key style/density change, and not when only the cursor moves. It includes a counter bumped whenever a level is built (so a rebuilt level never matches by address). |
| `LegendNavigator.SelectedIndex` | The cursor's position among the current screen's entry rows (0 on levels without a cursor): `Cursor - FirstItemOf(level, ScreenIndex) + 1`. |

`LegendOverlay.Show` and `ShowPicker` become frame + body + finish.
`SelectPickerRow` is replaced by `LegendSelection.Select`. `Legend.Draw` and
`Legend.DrawPicker` call `Render`; the picker's existing layout key
(`LayoutKey` + density) is passed unchanged, and the Navigator's `LayoutKey`
plus the footer's display hints for Alt+/ and chords.

Chords go through the same path. They have no cursor, so each chord step
changes the layout key and rebuilds, as today.

## Behavior that must not change

- The drawn result of every mode (compare screenshots before and after).
- Picker rows, letters, icons, ellipsis, width cap, empty text.
- Overlay placement, rounding, opacity set before showing.
- Picker in-place moves (now through `LegendSelection`) and their timing
  (about 16 ms a step with 19 rows).

## Testing

- `Navigator.LayoutKey`: unchanged after Down/Up within a screen; changed by
  Next/Prev, opening a level, Backspace, Pin, and Relayout.
- `Navigator.SelectedIndex`: 1-based on the current screen; 0 on flat pages.
- `LegendSelection` with a real off-screen window:
  - a two-column table body: selecting a row in the first column, then one in
    the last column, leaves the window's size unchanged;
  - the bar's position and size match the selected row's rectangle;
  - `Select(0)` hides the bar;
  - only the old and new rows' controls change color.
- `Legend.Render`: the same key twice calls `build` once; a new key rebuilds.
- Existing Picker, Navigator and Controller tests pass unchanged.
- Scripted screenshots of Alt+/ (index with a cursor) and a picker, compared
  with the current ones; timing of a picker step; then the author checks by eye
  that holding ↓ in Alt+/ no longer flickers.
