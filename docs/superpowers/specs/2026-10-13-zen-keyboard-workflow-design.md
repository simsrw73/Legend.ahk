# Zen keyboard workflow

Audience: the owner of the Windows AutoHotkey configuration. This design adds
a daily shortcut reference and a keyboard action menu for Zen without changing
Legend's public API.

## Approved direction

- Keep Alt+/ as the shortcut reference.
- Add a chord menu that works only while Zen is active.
- Restore Copy current URL to Ctrl+Shift+C; remove the Ctrl+Alt+C override.
- Add useful actions that Zen supports but leaves unbound.
- Preserve the existing Win+Space launcher and unrelated custom shortcuts.

## Evidence

The installed browser reports Zen 1.23.2b, build 20261009073723. Its installation
default profile is `Profiles/py9ipep1.Default (release)` under
`C:\Users\simsr\AppData\Roaming\zen`.

The profile's `zen-keyboard-shortcuts.json` and the installed
`browser/omni.ja` component `ZenKeyboardShortcuts.mjs` establish the action IDs
and configuration format. Installed configuration takes precedence over the
online shortcut list, which differs in downloads, reader mode, workspaces,
compact mode, and window handling.

Current custom bindings to retain:

| Action | Current shortcut |
|---|---|
| Compact mode | Ctrl+S |
| Save page | Ctrl+Alt+Shift+S |
| Workspace 1-9 / 10 | Alt+1-9 / Alt+0 |
| Previous / next workspace | Alt+W / Alt+Shift+W |
| Downloads | Ctrl+J |
| Pin / unpin tab | Ctrl+Shift+D |
| Empty split | Ctrl+Shift+8 |
| Expand Glance | Ctrl+O |
| Zen library | Alt+Shift+L |

Reader mode's F9 shortcut is present but disabled. Duplicate tab, create
workspace, reset pinned tab, and expand/collapse the tab sidebar are unbound.

The active AutoHotkey entry points load `hotkeys.ahk` and `Chords.ahk` and read
`legend/pages`. The personal Zen reference already has the basic tab and
navigation shortcuts. `OpenCurrentZenTabInChrome()` still sends Ctrl+Alt+C;
it must change alongside the Zen profile to keep Win+Shift+O working.

Both the Legend checkout and the dotfiles checkout have existing edits.
Implementation must preserve those edits and stage only task-owned changes.

## Action menu

Use **Ctrl+Alt+Space**, with `Match: "ahk_exe zen.exe"`. No matching trigger was
found in the inspected personal AutoHotkey files. The trigger remains available
to other applications. The existing Win+Space launcher keeps its current tree.

The action menu title is **Zen actions**. Keep the native-shortcut page titled
**Zen** so Alt+/ still opens that reference in Zen. Register a documentation row
for Ctrl+Alt+Space on the Zen page. Let Legend's existing chord-reference support
provide the complete action-menu reference.

The top-level menu uses these keys:

| Key | Action |
|---|---|
| n / x / u | New tab / close tab / reopen closed tab |
| l | Focus address bar |
| f | Find on page |
| r / R | Reload / reload without cache |
| c / C | Copy URL / copy URL as Markdown |
| h / H | Back / forward |
| j / k | Next / previous tab |
| p | Private window |
| t | Tabs submenu |
| s | Search submenu |
| b | Bookmarks and history submenu |
| w | Workspaces submenu |
| v | View and splits submenu |

Submenus contain the following actions:

- **Tabs:** pin/unpin, duplicate, reset pinned URL, mute/unmute, tabs 1-8 and
  last tab, move tab backward/forward, new window, and new blank window.
- **Search:** web search, search open tabs, search bookmarks, search history,
  and next/previous find result. Address-bar search filters use literal `%`,
  `*`, and `^`; typing a filter must leave the query ready for the user.
- **Bookmarks and history:** bookmark page, bookmarks sidebar, history
  sidebar, bookmarks library, downloads, and Zen library.
- **Workspaces:** previous, next, workspace 1-9 and 10, and create workspace.
- **View and splits:** compact mode, floating sidebar, sidebar width,
  reader mode, fullscreen, zoom in/out/reset, screenshot, print, save page,
  picture-in-picture, expand Glance, and a split submenu with vertical,
  horizontal, grid, unsplit, and empty split actions.

Chord letters are lowercase unless the table explicitly uses uppercase.
Uppercase means Shift+letter, following Legend's existing behavior. Ordinary
typing remains untouched until the chord trigger is pressed.

Actions send Zen shortcuts after Legend tears down the chord interaction.
Recheck that a Zen window is active before sending: a focus change must not
send browser keys into another application. Use native shortcuts rather than
mouse coordinates or browser-internal JavaScript.

## Zen configuration changes

Change only the following entries, preserving every other shortcut and field:

| Action ID | Desired shortcut | Reason |
|---|---|---|
| zen-copy-url | Ctrl+Shift+C | Remove the user's Copy URL override |
| zen-duplicate-tab | Ctrl+Alt+D | Duplicate the active tab without a mouse |
| zen-workspace-create | Ctrl+Alt+N | Open workspace creation from the menu |
| zen-pinned-tab-reset-shortcut | Ctrl+Alt+P | Return a pinned tab to its saved URL |
| zen-toggle-sidebar | Ctrl+Alt+B | Expand/collapse the tab sidebar |
| key_toggleReaderMode | F9, enabled | Restore the existing reader-mode action |

The four new Ctrl+Alt bindings were not assigned in the inspected profile.
Validate collisions across all active shortcuts, including `accel` as Ctrl on
Windows, before applying. A conflicting new shortcut must be resolved before
publishing a menu that depends on it.

Read the profile through `profiles.ini` and `installs.ini`; do not silently
choose another profile. Recheck the selected profile before applying. Preserve
a byte-for-byte backup of the original shortcut file and use a temporary file
and replacement for the update. Apply only while Zen is closed because its
shortcut component saves its in-memory list during initialization and changes.
Do not close or restart the browser automatically.

## Files and integration

In the Legend repository:

- Expand `collections/apps/zen.md` with the browser's Windows defaults. Keep
  personal overrides and custom action shortcuts in the personal page.
- Add `examples/07-zen.ahk`, a runnable example of the scoped action menu and
  reference. Clearly identify optional Zen bindings the example requires.
- Add a short guide for using the menu and configuring its additional actions.

In `C:\Users\simsr\.local\share\chezmoi\linked\AutoHotKey`:

- Add `Zen.ahk` for the personal action menu and its registration helper.
- Include it from the shared `hotkeys.ahk`, which both entry points already load.
- Change `OpenCurrentZenTabInChrome()` to send Ctrl+Shift+C and remove the
  comment describing the obsolete override.
- Expand `legend/pages/zen.md` using the installed personal shortcuts.

The profile file is outside the Legend workspace, as are the personal
AutoHotkey files. Prepare and validate their exact edits inside the workspace
before requesting the filesystem access required to apply them. Do not commit
the complete browser profile into a public repository.

## Navigation within websites

Include native Tab/Shift+Tab, Enter, Space, PgUp/PgDn, Home/End, Shift+F10,
and caret-browsing F7 in the reference with focus-dependent descriptions.
Scrolling keys can edit text when a form field is focused.

Link hints are a separate optional improvement. Vimium C offers keyboard link
selection and scrolling, but is not currently installed. Do not install or
enable an extension as part of this native Zen configuration change. The
existing ErgoZen extension is installed but inactive; keep its state unchanged.

## Validation

- Parse both Zen reference pages through Legend; require no parser warnings.
- Validate the new example and personal host with AutoHotkey `/Validate`.
- Test chord dispatch, submenu reachability, literal address-bar filters,
  context matching, and the focus-change guard with a captured send adapter.
- Validate the prepared JSON: exactly six intended entries change, all other
  entries remain semantically identical, and new key combinations do not
  collide with enabled shortcuts.
- Run `pwsh -NoProfile -File tests/Run-Tests.ps1` in the implementation checkout
  after the final changes, plus `git diff --check`.
- Run the existing personal AutoHotkey structure checks after integration.
- Live browser behavior requires a user-controlled test after launch/reload.
  Do not send keys to the user's desktop without permission, and do not claim
  live browser validation from parsing or AutoHotkey compilation alone.

## Sources

- [Zen keyboard shortcuts](https://docs.zen-browser.app/user-manual/shortcuts)
- [Zen address bar](https://docs.zen-browser.app/user-manual/urlbar)
- [Firefox keyboard shortcuts](https://support.mozilla.org/en-US/kb/keyboard-shortcuts-perform-firefox-tasks-quickly)
- [Vimium C](https://github.com/gdh1995/vimium-c)
- Installed Zen `application.ini`, profile shortcut JSON, and
  `ZenKeyboardShortcuts.mjs`, inspected on 2026-10-13.
