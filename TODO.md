# Backlog

- **Toggle key notation while the overlay is open.** Tab cycles key display
  text → symbols → ahk (`Ctrl+Shift+T` → `⌃⇧T` → `^+t`); the legend line shows
  automatically for symbols/ahk. The choice lasts until the script reloads (theme
  `keyStyle` stays the starting style). Needs: a `"Style"` navigator action that
  rebuilds the current level's rows, a Tab hotkey under `Legend.Visible`, and a
  footer hint.
- **Chord mode** (second pass): see "Modes" in docs/specs/2026-09-28-legend-design.md.
- Deferred review minors from v1: warn when a page's code `match` is set after
  its bindings; expose `Legend.Binder`; cap overlay width and compute the height
  reserve from real title/legend/footer sizes; warn on invalid code `Key`; set
  `Visible` only after `Draw` succeeds; test index titles with no letters;
  Unicode case-insensitive page/category merge.
