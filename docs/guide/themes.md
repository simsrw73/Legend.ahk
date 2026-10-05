# Themes and layout

**Audience:** Legend users who want the overlay to match their desktop.
**Topic:** theme files: colors, fonts, spacing, how lists grow into columns, and
key notation.
**Goal:** make your own theme, or tune the built-in one.

## The default

Without any theme settings, Legend follows Windows' light or dark mode and uses
[Catppuccin](https://catppuccin.com) Latte (light) or Mocha (dark). Two keys
change the look while the overlay is open, until the script reloads:

- **Tab** cycles key notation: text (`Ctrl+Shift+T`), symbols (`⌃⇧T`) and
  AutoHotkey (`^+t`).
- **=** switches between comfortable and compact spacing.

## Using a theme file

A theme is an `.ini` file. Put it in a folder, then name the folder and the
theme in `Legend.Start`:

```ahk
#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Lib\Legend\Legend.ahk

Legend.Start({Themes: [A_ScriptDir "\legend\themes"], Theme: "sunset"})
```

Legend looks for `sunset.ini` in your folders first, then in its own `themes`
folder (`catppuccin-latte`, `catppuccin-mocha`). `Theme: "auto"` is the
default.

A theme only needs the settings it changes; everything else keeps the default.
This one changes colors and a font size, and turns on compact spacing:

```ini
; legend\themes\sunset.ini
[colors]
background=1F1A24
border=4A3B52
category=F6A26B
keyBound=FFC58F
description=F2E6EE

[fonts]
bodySize=12

[layout]
density=compact
```

Save theme files as ASCII or UTF-16 (Windows' `.ini` reader doesn't read UTF-8
with accents). A value Legend can't use is reported as a
[warning](../troubleshooting.md#warnings) and the default is kept.

## Every setting

### `[colors]`

Colors are hex `RRGGBB`, with or without `#`.

| Setting | Default (Mocha) | Colors |
|---|---|---|
| `background` | `11111B` | the overlay's background |
| `border` | `313244` | the border |
| `title` | `7F849C` | the page title |
| `category` | `89B4FA` | category headings |
| `group` | `7F849C` | group sub-headings |
| `keyBound` | `B4BEFE` | keys your script binds |
| `keyDoc` | `7B81AE` | doc-only keys |
| `description` | `CDD6F4` | descriptions |
| `footer` | `6C7086` | the key hints at the bottom |
| `pinned` | `F9E2AF` | the "pinned" badge |
| `warning` | `FAB387` | the warnings badge |
| `indicatorOn` | `A6E3A1` | a chord item's dot when its `Status` is true |
| `indicatorOff` | `45475A` | the dot when it's false |
| `selection` | `border` | the selected row's background |
| `selectionText` | `description` | the selected row's text |
| `outline` | `category` | the outline around the window the switcher highlights |

### `[fonts]`

| Setting | Default | Meaning |
|---|---|---|
| `uiFont` | `Segoe UI` | titles, headings and descriptions |
| `keyFont` | `Consolas` | keys |
| `titleSize` | `9` | page title, in points |
| `headingSize` | `10` | category and group headings |
| `bodySize` | `11` | rows |

### `[layout]`

| Setting | Default | Meaning |
|---|---|---|
| `density` | `comfortable` | `comfortable` or `compact` spacing |
| `padding` | from density | space inside the border, in pixels (28 comfortable, 20 compact) |
| `rowSpacing` | from density | space between rows (12 comfortable, 6 compact) |
| `maxColumns` | `3` | most columns on one screen; more content pages |
| `maxHeightPercent` | `80` | most of the screen's height the overlay may use |
| `maxWidthPercent` | `90` | most of the screen's width |
| `pickerWidthPercent` | `60` | width of pickers |
| `pageGrowth` | `proportional` | how shortcut pages grow (see below) |
| `menuGrowth` | `proportional` | how the Alt+/ index and category menus grow |
| `chordGrowth` | `proportional` | how chord menus grow |
| `aspect` | `monitor` | the width ÷ height to aim for, or `monitor` for your screen's |
| `opacity` | `245` | 50 (see-through) to 255 (solid) |
| `rounded` | `true` | rounded corners |

### `[keys]`

| Setting | Default | Meaning |
|---|---|---|
| `keyStyle` | `text` | `text`, `symbols` or `ahk` notation |
| `legend` | `auto` | the line explaining modifier symbols: `auto` (only for symbols/ahk), `off`, `top`, `bottom` |

## How lists grow into columns

With `proportional` (the default), a short list stays one column. A list taller
than half the allowed height gets balanced columns: as many as bring the overlay
closest to your screen's shape. So a big page grows wider and taller together
instead of becoming one tall strip. A column may run a little taller to end at
a category, rather than splitting it.

With `vertical`, each column fills to `maxHeightPercent` before the next starts.

Pickers always grow vertically, keeping their order (most recent first, best
match first). In both modes, `maxColumns`, `maxHeightPercent` and
`maxWidthPercent` are hard limits: content beyond them pages to another screen
(**Ctrl+F / Ctrl+B**).
