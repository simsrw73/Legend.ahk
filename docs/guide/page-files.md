# Page files, collections and page letters

Page files let you list an app's own shortcuts without writing code. This guide
shows how to write pages in Markdown, use the ready-made collections, and
control the letters in the Alt+/ index.

## Why page files

Most shortcuts you want to remember belong to the app itself: Ctrl+T for a new
tab, Ctrl+Shift+P for a command palette. You don't bind them, you look them up.
Writing them in code works ([`Legend.Doc`](pages.md#keys-you-only-document)),
but a Markdown file is shorter, easier to edit, and readable on its own.

## Format

```markdown
---
match: ahk_exe zen.exe
key: z
---
# Zen

Anything that isn't a heading or a shortcut line is ignored, so notes are fine.

## Tabs
### Open & close
- `Ctrl+T` New tab
- `Ctrl+Shift+T` Reopen closed tab
### Move
- `Ctrl+1–8` Go to tab 1–8
- `Ctrl+9` Go to the last tab

## Page
- `Ctrl+L` Focus the address bar
```

| Line | Meaning |
|---|---|
| `---` … `---` | optional settings at the very top (*front matter*) |
| `match:` | which windows the page is for, like `Legend.Page`'s second argument |
| `key:` | the page's letter in the index (one letter or digit) |
| `# Title` | the page |
| `## Name` | a category |
| `### Name` | a group inside the category |
| `` - `keys` description `` | one shortcut |

**Writing keys:** spell them as they read, `Ctrl+Shift+T`, not AutoHotkey
symbols. Ranges and alternatives (`Ctrl+1–8`, `J / K`, `Alt+←/→`) are shown as
written. A key Legend can't read shows up as a [warning](../troubleshooting.md#warnings)
with the file and line.

**A file's `match:` only chooses the page.** It decides which page Alt+/ opens
for the active window. It never makes a hotkey app-specific: only a match in
code (`Legend.Page(title, match)`) does that.

## Loading page files

Tell `Legend.Start` where your files are with `Pages`:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Start({Pages: [A_ScriptDir "\legend\pages"]})
```

`Pages` is a list. Each entry is one of:

| Entry | Loads |
|---|---|
| a folder | every `.md` file in it |
| a `.md` file | that file |
| `{Path: file, Key: "x"}` | that file, and gives its page the letter `x` |

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

apps := A_ScriptDir "\Lib\Legend\collections\apps\"
Legend.Start({
    Pages: [
        A_ScriptDir "\legend\pages",                 ; a folder of your own pages
        apps "zed.md",                               ; one file from the collection
        {Path: apps "google-gmail.md", Key: "g"}     ; one file, with letter g
    ]
})
```

**Pages from code and files merge** when they have the same title (ignoring
case). A typical app page has its few bound keys in code and the app's own keys
in a file.

## Collections: ready-made pages

`Lib\Legend\collections\apps\` has pages for about 40 apps: browsers (Chrome,
Edge, Firefox, Zen), mail and calendars, editors (VS Code, Zed, Cursor,
Notepad++), chat, password managers, launchers, terminals and file managers
(File Explorer, Everything, Yazi). Each one lists what's worth knowing by
keyboard, not keys every Windows app shares.

To use them, copy the files you want into your own pages folder and edit them
freely. Your copies won't change when you update Legend.

Pages for web apps (Gmail, Google Calendar, Fastmail) match the window title, so
they work in any browser.

## Page letters

Every page in the Alt+/ index has a letter. Legend chooses it in this order:

1. a letter set in code: `Legend.Page(title, match, {Key: "k"})`;
2. `PageKeys` in `Legend.Start`, or a `{Path, Key}` entry in `Pages`;
3. the page file's `key:`;
4. otherwise, the first free character of the title.

`PageKeys` sets letters by title, without editing any files. It suits pages
loaded from a folder or a collection:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Start({
    Pages: [A_ScriptDir "\legend\pages"],
    PageKeys: Map("Google Chrome", "c", "Zen", "z", "File Explorer", "e")
})
```

### Letters that don't move

Letters chosen automatically (step 4) are saved to a small file,
`%AppData%\Legend\page-letters.txt`, and reused next time. A page keeps its
letter even when you add, remove or rename other pages, so you can learn them.
New pages only take letters nobody holds.

To keep the file elsewhere, or not at all:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Start({LetterFile: A_ScriptDir "\legend\letters.txt"})   ; or LetterFile: "" for no file
```

**Tip:** match page letters with your [chord launcher](chords.md), so a letter
means the same app in both. Legend's own setup does this with `PageKeys`.
