# Backlog

- Examples to browse: one small, runnable script per use and mode under
  `examples/` (reference pages from code, Markdown page files, themes, chords,
  pickers, the window switcher and its scopes), each with a comment header on
  what it shows, listed in the README.
- One key scheme for every overlay (next up): Ctrl+N/P next/previous row,
  Ctrl+F/B next/previous screen (PgDn/PgUp stay), Ctrl+T next scope, Enter
  picks, Esc/Ctrl+G cancel. Alt+/ gains a cursor on its index and category
  menus; chords stay letter-driven. j/k/h/l remain hidden extras in pickers.
- Flicker: moving through a picker repaints the whole overlay (RedrawWindow on
  every control) and page/filter changes rebuild the Gui. Try double-buffering
  (WS_EX_COMPOSITED), invalidating only the two changed rows, and updating rows
  in place instead of rebuilding.
- Picker review minors (2026-09-30):
  - LayoutKey uses ObjPtr(Items); use a load counter so a reused address after
    two scope changes in one batch can't skip a rebuild.
  - A filter that empties the list leaves the last peek and outline up.
  - A deferred OnCancel can clear the peek of a picker reopened within one tick.
  - Esc from a no-match filter returns to row 1, not the row selected before `/`.
  - Filter typing drops shifted and AltGr characters (translate with ToUnicodeEx).
  - PageSize reserves a legend line pickers never draw (symbols/ahk key styles).
  - Start 2 skips the most recent window when the active window isn't listed.
  - The peek anchor can be a transient invisible window; prefer visible ones.
  - Minimized windows' monitor comes from workspace coordinates (taskbar offset).
  - Very long window titles stretch the switcher to maxWidthPercent; consider a
    narrower cap for pickers.
