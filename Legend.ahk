#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\src\KeyName.ahk
#Include %A_LineFile%\..\src\PageFile.ahk
#Include %A_LineFile%\..\src\Registry.ahk
#Include %A_LineFile%\..\src\Rows.ahk
#Include %A_LineFile%\..\src\Layout.ahk
#Include %A_LineFile%\..\src\Navigator.ahk
#Include %A_LineFile%\..\src\Theme.ahk
#Include %A_LineFile%\..\src\Overlay.ahk
#Include %A_LineFile%\..\src\KeyWatch.ahk
#Include %A_LineFile%\..\src\ChordMatch.ahk

; Legend: a contextual shortcut overlay. See README.md.
class Legend {
    static Registry := LegendRegistry()
    static Options := ""
    static Visible := false
    static Nav := "", Gui := "", Theme := "", Measurer := ""
    static ThemeWarnings := []
    static Watcher := "", FocusTimer := "", ActiveHwnd := 0, HelpId := "", Keys := ""
    static BaseTheme := ""
    static StyleOverride := "", DensityOverride := ""   ; session-only display toggles
    static Styles := ["text", "symbols", "ahk"]

    static Page(title, match := "", options := "") => this.Registry.Page(title, match, options)
    static Bind(path, hotkey, description, fn, options := "") => this.Registry.Bind(path, hotkey, description, fn, options)
    static Doc(path, keyText, description) => this.Registry.Doc(path, keyText, description)
    static Warnings => this.Registry.Warnings
    static ClaimsLetters => this.Visible && this.Nav.ClaimsLetters

    ; options: HelpKey ("!/"), Pages ([] folders of *.md), Themes ([] folders searched
    ; before the built-in themes), Theme ("auto" or a theme file name without .ini).
    static Start(options := {}) {
        if this.Options
            throw Error("Legend.Start was already called", -1)
        get := (name, fallback) => options.HasOwnProp(name) ? options.%name% : fallback
        this.Options := {HelpKey: get("HelpKey", "!/"), Pages: get("Pages", []),
            Themes: get("Themes", []), Theme: get("Theme", "auto")}

        for dir in this.Options.Pages {
            for result in LegendPageFile.LoadDir(dir) {
                for w in result.Warnings
                    this.Registry.Warnings.Push(w)
                if result.Page
                    this.Registry.AddFile(result.Page)
            }
        }

        this.HelpId := LegendKeyName.FromHotkey(this.Options.HelpKey).Id
        HotIf()
        Hotkey(this.Options.HelpKey, (*) => Legend.Toggle())
        HotIf((*) => Legend.Visible)
        for key, action in Map("Esc", "Close", "Backspace", "Backspace", "Space", "Next",
                "PgDn", "Next", "PgUp", "Prev", "``", "Pin", "Tab", "Style", "=", "Density")
            Hotkey(key, this.Handler(action))
        HotIf((*) => Legend.ClaimsLetters)
        for ch in StrSplit("abcdefghijklmnopqrstuvwxyz0123456789")
            Hotkey(ch, this.Handler(ch))
        HotIf()
    }

    static Handler(action) => (*) => Legend.Handle(action)

    static Toggle() => this.Visible ? this.Close() : this.Open()

    static Open() {
        loaded := LegendTheme.Load(this.Options.Theme, this.Options.Themes)
        this.BaseTheme := loaded.Values
        this.ThemeWarnings := loaded.Warnings
        paginate := this.ApplyDisplay()
        theme := this.Theme

        pages := this.Registry.SortedPages()
        matches := []
        for p in pages
            if p.Match != "" && WinActive(p.Match)
                matches.Push(p)
        this.Nav := LegendNavigator(pages, paginate, theme["keyStyle"])
        this.Nav.Open(matches)
        this.ActiveHwnd := WinExist("A")
        this.Visible := true
        this.Draw()
        this.StartWatching()
    }

    ; Resolves the theme with the session's display toggles, replaces the measurer, and
    ; returns the matching paginate function.
    static ApplyDisplay() {
        theme := this.Theme := LegendTheme.Resolve(this.BaseTheme, this.DensityOverride, this.StyleOverride)
        if this.Measurer
            this.Measurer.Destroy()
        measurer := this.Measurer := LegendMeasurer(theme)
        area := LegendOverlay.WorkArea()
        maxHeight := (area.Bottom - area.Top) * theme["maxHeightPercent"] // 100 - 120
        return rows => LegendLayout.Paginate(rows, measurer, maxHeight, theme["maxColumns"], theme["padding"])
    }

    ; Tab cycles key notation, = flips density; both last until the script reloads.
    static ChangeDisplay(action) {
        if action = "Style" {
            for i, style in this.Styles
                if style = this.Theme["keyStyle"]
                    this.StyleOverride := this.Styles[Mod(i, this.Styles.Length) + 1]
        } else
            this.DensityOverride := this.Theme["density"] = "compact" ? "comfortable" : "compact"
        paginate := this.ApplyDisplay()
        this.Nav.Relayout(paginate, this.Theme["keyStyle"])
        this.Draw()
    }

    static Draw() {
        view := this.Nav.View
        mods := []
        for col in view.Columns
            for row in col.Rows
                mods.Push(row.Mods*)
        legendLine := this.Theme["legend"] = "off" ? "" : LegendKeyName.LegendLine(mods, this.Theme["keyStyle"])
        old := this.Gui
        footer := this.Nav.Footer("tab " this.Theme["keyStyle"], "= " this.Theme["density"])
        this.Gui := LegendOverlay.Show(view, this.Theme, this.Measurer, footer, legendLine,
            this.Nav.Pinned, this.Registry.Warnings.Length + this.ThemeWarnings.Length)
        if old
            old.Destroy()
    }

    static Close() {
        this.StopWatching()
        if this.Gui
            this.Gui.Destroy(), this.Gui := ""
        if this.Measurer
            this.Measurer.Destroy(), this.Measurer := ""
        this.Visible := false
    }

    static Handle(action) {
        if !this.Visible
            return
        if action = "Style" || action = "Density"
            return this.ChangeDisplay(action)
        switch this.Nav.Press(action) {
            case "redraw": this.Draw()
            case "close": this.Close()
        }
    }

    ; A visible-mode InputHook sees keys without blocking them, so Ctrl/Alt/Win combos
    ; still reach the app while the overlay closes. A timer notices focus changes.
    static StartWatching() {
        this.Keys := LegendKeyWatch(this.HelpId, ["``", "="])
        held := []
        for vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
            if GetKeyState(Format("vk{:X}", vk), "P")
                held.Push(vk)
        this.Keys.Seed(held)
        ih := this.Watcher := InputHook("V L0")
        ih.KeyOpt("{All}", "N")
        ih.OnKeyDown := (hook, vk, sc) => Legend.OnKeyDown(vk)
        ih.OnKeyUp := (hook, vk, sc) => Legend.Keys.Up(vk)
        ih.Start()
        this.FocusTimer := () => Legend.CheckFocus()
        SetTimer(this.FocusTimer, 150)
    }

    static StopWatching() {
        if this.Watcher
            this.Watcher.Stop(), this.Watcher := ""
        if this.FocusTimer
            SetTimer(this.FocusTimer, 0), this.FocusTimer := ""
    }

    ; A shortcut closes the overlay (unless pinned), and so does a plain letter on a
    ; screen that does not use letters; either way the key itself reaches the app.
    static OnKeyDown(vk) {
        kind := this.Keys.Down(vk, GetKeyName(Format("vk{:X}", vk)))
        if kind = "combo" || (kind = "letter" && this.Visible && !this.Nav.ClaimsLetters)
            SetTimer(() => Legend.Handle("Combo"), -1)
    }

    static CheckFocus() {
        if this.Nav.Pinned {
            this.ActiveHwnd := WinExist("A")
            return
        }
        if WinExist("A") != this.ActiveHwnd
            this.Handle("FocusLost")
    }
}
