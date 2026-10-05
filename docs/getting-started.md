# Getting started with Legend

**Audience:** anyone with AutoHotkey v2 installed, including first-time scripters.
**Topic:** installing Legend and building one script, step by step.
**Goal:** by the end you have hotkeys that show up in a Legend overlay, an
app-specific page, a page of an app's own shortcuts, and a Win+Space launcher.

Each step is a complete script: copy it over the previous one, reload, and try
it. New to AutoHotkey's syntax? Read [AutoHotkey basics](autohotkey-basics.md)
first, it takes five minutes.

## Step 1: Install Legend

1. Install [AutoHotkey v2](https://www.autohotkey.com/) if you haven't.
2. Pick a folder for your script, for example `Documents\AutoHotkey`.
3. Inside it, create a folder named `Lib`.
4. Download Legend: on its [GitHub page](https://github.com/simsrw73/Legend.ahk)
   choose **Code → Download ZIP**, extract it into `Lib`, and rename the
   extracted folder (`Legend.ahk-main`) to `Legend`. If you use git:
   `git clone https://github.com/simsrw73/Legend.ahk Lib\Legend`.

You should end up with:

```text
Documents\AutoHotkey\
    my-keys.ahk                   your script (you create it in step 2)
    Lib\
        Legend\
            Legend.ahk            the file your script includes
            src\  themes\  collections\  ...
```

## Step 2: Your first hotkey in Legend

Create `my-keys.ahk` in `Documents\AutoHotkey` with this content and
double-click it:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Page("My keys").Category("Text", [
    ["^!d", "type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))]
])

Legend.Start()
```

**Try it:** open Notepad and press **Ctrl+Alt+D**: today's date is typed. Now
press **Alt+/**: the Legend overlay opens and lists your page. Press the page's
letter (or **Enter**) to open it, and **Esc** to close.

**What each part does:**

1. `#Requires` and `#SingleInstance Force` are the usual first lines: they demand
   AutoHotkey v2 and let you rerun the script without a prompt.
2. `#Include` loads Legend. `%A_ScriptDir%` is your script's folder, so the path
   works wherever you keep it.
3. `Legend.Page("My keys")` creates a page, the screen you see in the overlay.
   `.Category("Text", [...])` adds a heading on that page with a list of rows.
4. Each row is `[hotkey, description, action]`:
   - `"^!d"` is the key, Ctrl+Alt+D (see the
     [symbols table](autohotkey-basics.md#hotkeys-and-their-symbols)).
   - `"type today's date"` is what the overlay shows next to it.
   - `(*) => SendText(...)` is what happens when you press it.
5. `Legend.Start()` comes **last**. It loads page files and themes and turns on
   the overlay key, **Alt+/**.

Legend creates the hotkey for you: you don't write `^!d::` separately. That is
the point: the key and its description live in one place, so the overlay is
always right.

## Step 3: More categories, and keys you only want to remember

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Page("My keys").Category("Text", [
    ["^!d", "type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))],
    ["^!u", "uppercase the clipboard", (*) => A_Clipboard := StrUpper(A_Clipboard)]
])

Legend.Page("My keys").Category("Windows", [
    ["^!Left", "snap window left", (*) => Send("#{Left}")],
    ["^!Right", "snap window right", (*) => Send("#{Right}")]
])

; Windows' own shortcuts: listed, not bound. They appear in a muted color.
Legend.Doc(["My keys", "Windows"], "Win+Up", "maximize")
Legend.Doc(["My keys", "Windows"], "Win+D", "show the desktop")

Legend.Start()
```

**What changed:**

1. Calling `Legend.Page("My keys")` again returns the same page, so the second
   `.Category` adds a second heading to it.
2. `Legend.Doc([page, category], key, description)` lists a shortcut you want to
   remember but don't bind: here, Windows' own keys. Write the key the way it
   reads (`Win+Up`), not in symbols.

Open the overlay with **Alt+/**: bound keys and doc-only keys sit side by side,
doc-only ones in a muted color.

## Step 4: A page for one app

Pages can belong to an app. The overlay then opens straight to that page when
the app is in front, and the hotkeys work only there.

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Page("My keys").Category("Text", [
    ["^!d", "type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd"))]
])

; The second argument says which windows the page is for.
notepad := Legend.Page("Notepad", "ahk_exe notepad.exe")
notepad.Category("Editing", [
    ["^!s", "insert a signature", (*) => SendText("-- `nSent from Notepad")],
    ["^!l", "duplicate the line", (*) => Send("{Home}+{End}^c{End}{Enter}^v")]
])

Legend.Start()
```

**Try it:** with Notepad in front, **Alt+/** opens the Notepad page directly, and
**Ctrl+Alt+S** types the signature. In any other app, Ctrl+Alt+S does nothing
and Alt+/ opens the index.

**Explanation:**

1. `"ahk_exe notepad.exe"` matches windows of the program `notepad.exe`. Use
   [Window Spy](autohotkey-basics.md#telling-windows-apart-ahk_exe) to find
   another app's name.
2. Give a page its match **before** binding keys on it. Keys bound earlier were
   already created for every app, and Legend warns you about it.
3. `` `n `` inside a string is a new line.

## Step 5: Pages from Markdown files

Many shortcuts belong to the app itself (Ctrl+T for a new tab, say). You don't
bind them, you just want to see them. Write them in a Markdown file instead of
code.

Create a folder `legend\pages` next to your script and save this as
`legend\pages\notepad.md`:

```markdown
---
match: ahk_exe notepad.exe
---
# Notepad

## Editing
- `Ctrl+F` Find
- `Ctrl+H` Replace
- `Ctrl+G` Go to line
- `F5` Insert time and date
```

Then point `Legend.Start` at the folder:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

notepad := Legend.Page("Notepad", "ahk_exe notepad.exe")
notepad.Category("Editing", [
    ["^!s", "insert a signature", (*) => SendText("-- `nSent from Notepad")]
])

Legend.Start({Pages: [A_ScriptDir "\legend\pages"]})
```

**What happens:** the file's `# Notepad` page has the same title as the page in
your code, so they merge: your bound Ctrl+Alt+S and Notepad's own keys appear on
one page. In the file:

- the lines between `---` are settings (`match:` works like the second argument
  of `Legend.Page`);
- `#` is the page title, `##` a category, `###` a group inside a category;
- `` - `keys` description `` is one shortcut.

Legend ships ready-made pages for about 40 apps in `Lib\Legend\collections\apps`.
Copy the ones you use into `legend\pages` and edit them. See
[Page files](guide/page-files.md).

## Step 6: A Win+Space launcher

A *chord* is a key followed by other keys, like a menu you drive from the
keyboard. Press **Win+Space**, then **n** to open Notepad:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Chord("#Space", "Launch", [
    Legend.Run("n", "Notepad", (*) => Run("notepad.exe")),
    Legend.Run("c", "Calculator", (*) => Run("calc.exe")),
    Legend.Menu("t", "Text", [
        Legend.Run("d", "type today's date", (*) => SendText(FormatTime(, "yyyy-MM-dd")))
    ])
])

Legend.Start({Pages: [A_ScriptDir "\legend\pages"]})
```

**Try it:** press **Win+Space**, wait a moment and a menu appears; press **n**.
Press **Win+Space**, **t**, **d** to type the date. Typed quickly, the chord
runs before the menu even shows.

**Explanation:**

1. `Legend.Chord(trigger, title, items)` makes the menu. `#Space` is Win+Space.
2. `Legend.Run(key, label, action)` is one item.
3. `Legend.Menu(key, label, items)` is a submenu, shown with a `›`.
4. The chord also appears as a page in **Alt+/**, so you can look up what you
   set up.

## Where to go next

- [Pages and bindings](guide/pages.md): rows that merge, groups, one-line
  bindings.
- [Page files](guide/page-files.md): collections, page letters.
- [Chords](guide/chords.md): running-app dots, conditions, key ranges.
- [Pickers and the window switcher](guide/pickers.md): lists to choose from,
  an Alt+Tab replacement.
- [Themes and layout](guide/themes.md): colors, fonts, density.
- [Reference](reference.md): every function and option.
- [Troubleshooting](troubleshooting.md): when something doesn't work.
