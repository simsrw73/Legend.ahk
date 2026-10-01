# Backlog

- Flicker: row moves now repaint only the two changed rows. Page changes and
  filter typing still rebuild the Gui; update rows in place there too (reuse
  the row controls, hide unused ones) and try WS_EX_COMPOSITED double-buffering.
- Decide whether the window switcher should send commands to the selected
  window without leaving the switcher: minimize, close, move to another
  monitor or virtual desktop, and so on. Later.
- Find list of shortcuts to adapt so we can provide a few good collections:
  https://github.com/solomkinmv/hotkys/tree/main
- Refresh the README screenshots (docs/images, taken 2026-09-28): footers now use
  the shared key scheme (↵ open · ^n/^p move · ^f/^b), menus show a selection
  bar, and there is no picture of a picker or the window switcher yet. The
  w11dwm-config README reuses the overlay and chord images.
