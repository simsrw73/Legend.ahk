# Backlog

- Examples to browse: one small, runnable script per use and mode under
  `examples/` (reference pages from code, Markdown page files, themes, chords,
  pickers, the window switcher and its scopes), each with a comment header on
  what it shows, listed in the README.
- One key scheme for every overlay (next up): Ctrl+N/P next/previous row,
  Ctrl+F/B next/previous screen (PgDn/PgUp stay), Ctrl+T next scope, Enter
  picks, Esc/Ctrl+G cancel. Alt+/ gains a cursor on its index and category
  menus; chords stay letter-driven. j/k/h/l remain hidden extras in pickers.
- Flicker: row moves now repaint only the two changed rows. Page changes and
  filter typing still rebuild the Gui; update rows in place there too (reuse
  the row controls, hide unused ones) and try WS_EX_COMPOSITED double-buffering.
