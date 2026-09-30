# Backlog

- Examples to browse: one small, runnable script per use and mode under
  `examples/` (reference pages from code, Markdown page files, themes, chords,
  pickers, the window switcher and its scopes), each with a comment header on
  what it shows, listed in the README.
- Flicker: row moves now repaint only the two changed rows. Page changes and
  filter typing still rebuild the Gui; update rows in place there too (reuse
  the row controls, hide unused ones) and try WS_EX_COMPOSITED double-buffering.
- Decide whether the window switcher should send commands to the selected
  window without leaving the switcher: minimize, close, move to another
  monitor or virtual desktop, and so on. Later.
