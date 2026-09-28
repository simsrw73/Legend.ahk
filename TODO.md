# Backlog

- **Chord mode** shipped (docs/specs/2026-09-28-chord-mode-design.md); next:
  migrate the dotfiles' Win+Space menu and drop KeyChord.
- **Short local names vs host globals.** Legend uses locals like `w`, `h`, `x`,
  `y`, `p`, `c`, `g`, `out`; a host script with globals of the same names gets
  `#Warn` "local has the same name as a global" noise from Legend under
  `#Warn All`. Rename to longer, Legend-ish names (or declare them `local`).
- Deferred review minors from v1: warn when a page's code `match` is set after
  its bindings; expose `Legend.Binder`; cap overlay width and compute the height
  reserve from real title/legend/footer sizes; warn on invalid code `Key`; set
  `Visible` only after `Draw` succeeds; test index titles with no letters;
  Unicode case-insensitive page/category merge.
