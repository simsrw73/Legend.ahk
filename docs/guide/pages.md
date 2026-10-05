# Pages and bindings

**Audience:** Legend users who have done [Getting started](../getting-started.md).
**Topic:** building pages from code: categories, groups, merged rows, one-line
bindings, doc-only keys and app-specific pages.
**Goal:** organize a growing set of hotkeys so the overlay stays easy to read.

## How a page is organized

```text
Page            "komorebi"                  what Alt+/ opens
└ Category      "Workspaces"                a heading
  └ Group       "Focus"                     an optional sub-heading
    └ Row       Alt+1   1 dev               one shortcut
```

A page that fits on one screen opens whole. A bigger page opens as a menu of its
categories, and each category opens on its own.

## Binding a table of rows

The usual way to add keys is a table: one row per hotkey.

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Page("Windows").Category("Snap", [
    ["^!Left", "snap left", (*) => Send("#{Left}")],
    ["^!Right", "snap right", (*) => Send("#{Right}")],
    ["^!Up", "maximize", (*) => WinMaximize("A")]
])

Legend.Start()
```

Each row is `[hotkey, description, action, options]`:

| Item | What it is |
|---|---|
| `hotkey` | an AutoHotkey hotkey, like `"^!Left"` ([symbols](../autohotkey-basics.md#hotkeys-and-their-symbols)) |
| `description` | the text shown in the overlay |
| `action` | the function to run; it receives the hotkey name, so write `(*) =>` |
| `options` | optional: `{Row, Text}`, see [merged rows](#merging-related-keys-into-one-row) |

## Groups inside a category

Pass a group name as the third argument of `Category`:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

page := Legend.Page("komorebi")
page.Category("Workspaces", [
    ["!1", "1 dev", (*) => Run("komorebic focus-named-workspace dev", , "Hide")],
    ["!2", "2 notes", (*) => Run("komorebic focus-named-workspace notes", , "Hide")]
], "Focus")
page.Category("Workspaces", [
    ["!+1", "to 1 dev", (*) => Run("komorebic move-to-named-workspace dev", , "Hide")],
    ["!+2", "to 2 notes", (*) => Run("komorebic move-to-named-workspace notes", , "Hide")]
], "Move window")

Legend.Start()
```

The overlay shows *Workspaces* with two sub-headings, *Focus* and *Move window*.

## Merging related keys into one row

Four hotkeys that do the same thing in four directions read better as one row.
Give each row the same `Row` text; the first one's `Text` is the description:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

focus := (dir) => (*) => Run("komorebic focus " dir, , "Hide")

Legend.Page("komorebi").Category("Focus", [
    ["!h", "focus left", focus("left"), {Row: "Alt+H/J/K/L", Text: "focus ← ↓ ↑ →"}],
    ["!j", "focus down", focus("down"), {Row: "Alt+H/J/K/L"}],
    ["!k", "focus up", focus("up"), {Row: "Alt+H/J/K/L"}],
    ["!l", "focus right", focus("right"), {Row: "Alt+H/J/K/L"}]
])

Legend.Start()
```

All four keys are bound; the overlay shows one line: `Alt+H/J/K/L  focus ← ↓ ↑ →`.

`focus` here is a small helper that *returns* an action, so each row doesn't
repeat the `Run` call. `focus("left")` gives back `(*) => Run("komorebic focus left", , "Hide")`.

## One-line bindings

`Legend.Bind([page, category, group?], hotkey, description, action)` binds a
single key without a table. Handy when the key is set up somewhere else in your
script:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Bind(["Tools", "Clipboard"], "^!c", "copy today's date",
    (*) => A_Clipboard := FormatTime(, "yyyy-MM-dd"))
Legend.Bind(["Tools", "Clipboard", "Case"], "^!u", "uppercase the clipboard",
    (*) => A_Clipboard := StrUpper(A_Clipboard))

Legend.Start()
```

The path is `[page, category]` or `[page, category, group]`. Pages and
categories are created as needed, and names match regardless of case.

## Keys you only document

`Legend.Doc(path, keys, description)` lists a shortcut without binding it:
Windows' own keys, an app's keys, or something another tool provides.

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Doc(["Windows", "Desktop"], "Win+D", "show the desktop")
Legend.Doc(["Windows", "Desktop"], "Win+Ctrl+Left / Right", "previous / next virtual desktop")

Legend.Start()
```

Write the keys as they read (`Win+D`, `Ctrl+Shift+T`); ranges and alternatives
(`Ctrl+1–8`, `Left / Right`) are shown as written. Doc-only keys appear in a
muted color. If you later bind the same key on that page, the bound row takes
its place.

For many doc-only keys, a [page file](page-files.md) is easier than code.

## App-specific pages

The second argument of `Legend.Page` is a *match*: which windows the page is
for.

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

zen := Legend.Page("Zen", "ahk_exe zen.exe")
zen.Category("Tabs", [
    ["#+o", "open this tab in Chrome", (*) => Run("chrome.exe")]
])

Legend.Start()
```

A match does two things:

1. **Alt+/ opens this page directly** when a matching window is active. If several
   pages match, Alt+/ shows a short list of just those.
2. **The page's hotkeys work only in matching windows**, so the same key can do
   different things in different apps.

Set the match **before** binding keys on the page. Keys bound earlier were
created for every window, and Legend shows a warning (see
[Troubleshooting](../troubleshooting.md#warnings)).

The match is any AutoHotkey [WinTitle](https://www.autohotkey.com/docs/v2/misc/WinTitle.htm):
`ahk_exe zen.exe`, `ahk_class Notepad`, or a title like `Gmail`.

## Choosing a page's letter

In the Alt+/ index, each page has a letter. Legend picks one from the title and
remembers it (see [Page files](page-files.md#page-letters)). To choose it
yourself:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Page("komorebi", "", {Key: "w"}).Category("Focus", [
    ["!h", "focus left", (*) => Run("komorebic focus left", , "Hide")]
])

Legend.Start()
```

## Recipe: a complete window-manager page

A real-world page from the author's setup: komorebi workspaces, focus and
moves, with one helper and merged rows.

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

komorebic(args) => (*) => Run("komorebic " args, , "Hide")

page := Legend.Page("komorebi", "", {Key: "w"})

workspaces := ["dev", "notes", "research"]
for i, name in workspaces {
    page.Category("Workspaces", [["!" i, i " " name, komorebic("focus-named-workspace " name)]], "Focus")
    page.Category("Workspaces", [["!+" i, "to " i " " name, komorebic("move-to-named-workspace " name)]], "Move window")
}

dirs := Map("h", "left", "j", "down", "k", "up", "l", "right")
for key, dir in dirs {
    page.Category("Windows", [
        ["!" key, "focus " dir, komorebic("focus " dir), {Row: "Alt+H/J/K/L", Text: "focus ← ↓ ↑ →"}],
        ["!+" key, "move " dir, komorebic("move " dir), {Row: "Alt+Shift+H/J/K/L", Text: "move window ← ↓ ↑ →"}]
    ])
}

Legend.Start()
```

**Explanation:**

1. `komorebic(args)` returns an action that runs `komorebic` hidden.
2. The workspace loop binds Alt+1–3 and Alt+Shift+1–3 into two groups.
3. The direction loop binds eight keys but shows two merged rows.

## Recording or replacing how hotkeys are created

Legend creates hotkeys through `Legend.Binder`, a function
`(keyName, action, match)`. Replace it **before** binding anything, for example
to log every binding while debugging your script:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

original := Legend.Binder
Legend.Binder := (keyName, action, match) => (
    OutputDebug("Legend binds " keyName (match != "" ? " in " match : "") "`n"),
    original(keyName, action, match)
)

Legend.Page("Demo").Category("Keys", [["^!F9", "demo", (*) => MsgBox("hi")]])
Legend.Start()
```

See the [reference](../reference.md#legendbinder) for details.
