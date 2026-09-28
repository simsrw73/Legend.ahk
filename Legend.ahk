#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\src\KeyName.ahk
#Include %A_LineFile%\..\src\PageFile.ahk
#Include %A_LineFile%\..\src\Registry.ahk
#Include %A_LineFile%\..\src\Rows.ahk
#Include %A_LineFile%\..\src\Layout.ahk
#Include %A_LineFile%\..\src\Navigator.ahk
#Include %A_LineFile%\..\src\Theme.ahk
#Include %A_LineFile%\..\src\Overlay.ahk

; Legend: a contextual shortcut overlay. See README.md.
class Legend {
    static Registry := LegendRegistry()
    static Options := ""
    static Visible := false
    static Nav := "", Gui := "", Theme := "", Measurer := ""
    static ThemeWarnings := []
    static Watcher := "", FocusTimer := "", ActiveHwnd := 0, HelpId := ""

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
                "PgDn", "Next", "PgUp", "Prev", "``", "Pin")
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
        theme := this.Theme := loaded.Values
        this.ThemeWarnings := loaded.Warnings
        measurer := this.Measurer := LegendMeasurer(theme)
        area := LegendOverlay.WorkArea()
        maxHeight := (area.Bottom - area.Top) * theme["maxHeightPercent"] // 100 - 120
        paginate := rows => LegendLayout.Paginate(rows, measurer, maxHeight, theme["maxColumns"], theme["padding"])

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

    static Draw() {
        view := this.Nav.View
        mods := []
        for col in view.Columns
            for row in col.Rows
                mods.Push(row.Mods*)
        legendLine := this.Theme["legend"] = "off" ? "" : LegendKeyName.LegendLine(mods, this.Theme["keyStyle"])
        old := this.Gui
        this.Gui := LegendOverlay.Show(view, this.Theme, this.Measurer, this.Nav.Footer(), legendLine,
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
        switch this.Nav.Press(action) {
            case "redraw": this.Draw()
            case "close": this.Close()
        }
    }

    ; A visible-mode InputHook sees keys without blocking them, so Ctrl/Alt/Win combos
    ; still reach the app while the overlay closes. A timer notices focus changes.
    static StartWatching() {
        ih := this.Watcher := InputHook("V L0")
        ih.KeyOpt("{All}", "N")
        ih.OnKeyDown := (hook, vk, sc) => Legend.OnKeyDown(vk)
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

    static OnKeyDown(vk) {
        static modifierVks := Map(0x10, 1, 0x11, 1, 0x12, 1, 0x5B, 1, 0x5C, 1,
            0xA0, 1, 0xA1, 1, 0xA2, 1, 0xA3, 1, 0xA4, 1, 0xA5, 1)
        if modifierVks.Has(vk)
            return
        mods := []
        if GetKeyState("Ctrl")
            mods.Push("Ctrl")
        if GetKeyState("Alt")
            mods.Push("Alt")
        if GetKeyState("LWin") || GetKeyState("RWin")
            mods.Push("Win")
        if !mods.Length
            return
        if GetKeyState("Shift")
            mods.Push("Shift")
        if LegendKeyName.FromParts(mods, GetKeyName(Format("vk{:X}", vk))).Id == this.HelpId
            return   ; the help key's own hotkey toggles the overlay
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
