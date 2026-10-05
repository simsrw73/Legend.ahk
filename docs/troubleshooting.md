# Troubleshooting

Use this guide when a Legend setup is not doing what you expect. It covers
common problems, every warning Legend shows, errors that stop a script, and
what Legend can and cannot do on your machine, so you can find and fix the
problem without reading the source.

## My script won't start

| Message | Cause | Fix |
|---|---|---|
| an error mentioning `#Requires` | the script runs with AutoHotkey v1 | install AutoHotkey v2, or open the script with v2 |
| `#Include file ... cannot be opened` | the path to `Legend.ahk` is wrong | check the folder layout in [Getting started](getting-started.md#step-1-install-legend); use `%A_ScriptDir%\Lib\Legend\Legend.ahk` |
| `Legend.Start was already called` | `Legend.Start` appears twice | call it once, at the end |
| `picker '...': OnPick is required` | a `Legend.Picker` has no `OnPick` | add `OnPick: item => ...` |
| `picker '...': scope '...' is not in Scopes` | `Scope` names a scope the list doesn't have | fix the spelling, or add it to `Scopes` |
| `unknown chord key '...'` | a chord item's key isn't a key name or pattern | see [chord keys](guide/chords.md#key-ranges-and-wildcards) |
| `window switcher scope must be all, desktop or monitor` | a typo in `Scope` | use one of those three |
| `path must be [page, category] or [page, category, group]` | a `Legend.Bind` or `Legend.Doc` path has the wrong shape | pass a list of 2 or 3 names |
| `unknown key '...'` | `Legend.Doc` got a key it can't read | write it like `Ctrl+Shift+T`; ranges like `Ctrl+1–8` are fine |
| `picker '...': <message>` when the picker opens | your picker's source function failed | the message is from your source; fix it there |

## A hotkey doesn't work

1. **Is the script running?** Look for its green **H** icon in the taskbar's
   notification area.
2. **Is the page app-specific?** Keys on a page with a match only work in
   matching windows. Check the match with Window Spy
   ([how](autohotkey-basics.md#telling-windows-apart-ahk_exe)).
3. **Does another program own the key?** Some keys are taken before AutoHotkey
   sees them: Windows Terminal uses **F11** for full screen, many apps use
   **Ctrl+Alt** combinations, and a few Win keys (Win+L) can't be overridden.
   Try a different key to confirm.
4. **Another AutoHotkey script?** Two scripts binding the same key fight over it.
   Exit the others to test.
5. **Running as administrator?** A script that isn't elevated can't send keys to
   an elevated window (Task Manager, an admin terminal). Run the script as
   administrator, or accept that limit.

## Alt+/ does nothing, or opens the wrong page

- **Another tool uses Alt+/.** Choose a different key:
  `Legend.Start({HelpKey: "^!/"})` (Ctrl+Alt+/).
- **The wrong page opens.** Alt+/ opens the page whose match fits the active
  window. A page file's `match:` and a page's match in code both count; if
  several pages match, Alt+/ lists them. Check each match with Window Spy.
- **A page is missing from the index.** Pages with no keys at all are hidden.
  For page files, check the [warnings](#warnings).

## Warnings

When something in your setup is wrong but Legend can carry on, it shows a
**⚠ N warnings · see Warnings** badge in the overlay's footer. Hover over it to
read them, or open the **Warnings** page in the Alt+/ index. Fix the cause and
reload the script.

| Warning | Meaning and fix |
|---|---|
| `page file or folder not found: ...` | a `Pages` entry points nowhere: fix the path |
| `<file>:<line>: unknown key '...'` | a page file's key can't be read: write it like `Ctrl+Shift+T` |
| `<file>:<line>: unclosed backtick` | a shortcut line is missing its closing `` ` `` |
| `<file>: no '# Title' line; file skipped` | a page file needs a `# Title` line |
| `<file>:1: front matter is not closed with ---; file skipped` | add the closing `---` |
| `<file>:<line>: key must be one letter or digit` | a page file's `key:` is too long |
| `page '...': match '...' was set after its bindings` | give the page its match **before** binding keys on it ([why](guide/pages.md#app-specific-pages)) |
| `page '...': <key> is bound twice` | the same key is bound twice on one page: remove one |
| `page '...': code match '...' overrides file match '...'` | code and the page file disagree about the match; code wins. Make them agree |
| `page '...': code key 'x' overrides file key 'y'` | code and the page file disagree about the letter; code wins |
| `page '...': key '...' must be one letter or digit; ignored` | `Legend.Page(title, match, {Key})` with a bad key |
| `PageKeys: no page titled '...'` | a `PageKeys` title matches no page: check the spelling |
| `PageKeys: key '...' for '...' must be one letter or digit` | a bad letter in `PageKeys` |
| `pages: an entry object needs a Path` | a `{Path, Key}` entry without `Path` |
| `pages: Key '...' applies to a file, not the folder ...` | `Key` only works for single files |
| `chord '...': '...' on <key> can never run` | an earlier item on the same key has no `If`, so it always wins ([conditions](guide/chords.md#conditions-different-items-for-different-apps)) |
| `theme '...' not found; using defaults` | check `Theme` and `Themes` ([themes](guide/themes.md#using-a-theme-file)) |
| `theme <section.setting>: invalid value '...'` | a theme value out of range or misspelled; the default is used |

## The overlay looks wrong

- **Too small or blurry on a high-DPI screen:** raise `bodySize` and friends in a
  [theme](guide/themes.md#fonts).
- **Too tall or too wide:** lower `maxHeightPercent` or `maxWidthPercent`, or
  switch to compact spacing with **=**.
- **Accented characters in a theme look wrong:** save the `.ini` as UTF-16.

## Safety: what Legend does on your computer

Legend is a library inside your script; it has exactly the permissions your
script has.

- **Page files and themes are only read, never run.** A page file can't execute
  code, so pages shared by others (like the collections) are safe to load.
- **Actions run your code.** A row's action, a chord item or `OnPick` does
  whatever you wrote. Chord items given as a string are *sent as keystrokes* to
  the active window, so be careful with strings that include `{Enter}` or
  shortcuts, and with any item that builds a `Run` command from picker data: run
  only programs and paths you trust.
- **Files Legend writes:** only `%AppData%\Legend\page-letters.txt` (page
  letters, see [`LetterFile`](reference.md#legendstartoptions)).
- **Network:** none. Legend never connects to anything.
- **Keyboard:** while the overlay, a chord or a picker is open, Legend watches
  keys to drive it, and lets Ctrl/Alt/Win shortcuts through to your apps. It
  doesn't record or store keys.
