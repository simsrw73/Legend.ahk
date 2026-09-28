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
#Include %A_LineFile%\..\src\Chord.ahk

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
    static DefaultOptions := {HelpKey: "!/", Pages: [], Themes: [], Theme: "auto",
        ChordTimeout: 0, ChordOverlay: 400, ChordReference: true}
    static ChordState := ""

    static Page(title, match := "", options := "") => this.Registry.Page(title, match, options)
    static Bind(path, hotkey, description, fn, options := "") => this.Registry.Bind(path, hotkey, description, fn, options)
    static Doc(path, keyText, description) => this.Registry.Doc(path, keyText, description)

    static Run(key, label, action, options := "") => LegendChordItem(key, label, action, "", options)
    static Menu(key, label, items) => LegendChordItem(key, label, "", items)
    static Chord(hotkey, title, items, options := "") {
        chord := LegendChord(hotkey, title, items, options)
        return this.Registry.AddChord(chord, (*) => Legend.OpenChord(chord))
    }

    ; An option from Start, or its default when Start has not run.
    static Opt(name) => IsObject(this.Options) ? this.Options.%name% : this.DefaultOptions.%name%
    static Warnings => this.Registry.Warnings
    static ClaimsLetters => this.Visible && this.Nav.ClaimsLetters

    ; options: HelpKey ("!/"), Pages ([] folders of *.md), Themes ([] folders searched
    ; before the built-in themes), Theme ("auto" or a theme file name without .ini),
    ; ChordTimeout (seconds, 0 = none), ChordOverlay ("always", "never" or a delay in
    ; ms, default 400), ChordReference (false hides chords from the reference).
    static Start(options := {}) {
        if this.Options
            throw Error("Legend.Start was already called", -1)
        this.Options := {}
        for name, fallback in this.DefaultOptions.OwnProps()
            this.Options.%name% := options.HasOwnProp(name) ? options.%name% : fallback

        for dir in this.Options.Pages {
            for result in LegendPageFile.LoadDir(dir) {
                for w in result.Warnings
                    this.Registry.Warnings.Push(w)
                if result.Page
                    this.Registry.AddFile(result.Page)
            }
        }
        this.Registry.EnableChordReference(this.Options.ChordReference)

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
        HotIf((*) => Legend.Visible && !Legend.Nav.Pinned)   ; pinned: they reach the app
        for key, action in Map("^n", "Next", "^p", "Prev", "^g", "Close")
            Hotkey(key, this.Handler(action))
        HotIf()
    }

    static Handler(action) => (*) => Legend.Handle(action)

    static Toggle() => this.Visible ? this.Close() : this.Open()

    static Open() {
        if this.ChordState
            this.CloseChord()
        this.LoadTheme()
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

    static LoadTheme() {
        loaded := LegendTheme.Load(this.Opt("Theme"), this.Opt("Themes"))
        this.BaseTheme := loaded.Values
        this.ThemeWarnings := loaded.Warnings
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
        this.Keys := LegendKeyWatch(this.HelpId, ["``", "=", "Ctrl+N", "Ctrl+P", "Ctrl+G"])
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

    ; ---- Chord mode ----

    static OpenChord(chord) {
        if this.ChordState
            return this.CloseChord()          ; trigger again closes
        if this.Visible
            this.Close()
        this.LoadTheme()
        paginate := this.ApplyDisplay()
        this.Nav := LegendNavigator([], paginate, this.Theme["keyStyle"])
        this.Nav.OpenChord(chord)
        held := []
        for vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
            if GetKeyState(Format("vk{:X}", vk), "P")
                held.Push(vk)
        state := this.ChordState := {Chord: chord, Keys: LegendChordKeys(held), Shown: false,
            TriggerId: LegendKeyName.FromHotkey(chord.Hotkey).Id, Timers: Map()}
        ih := state.Hook := InputHook("L0")
        ih.KeyOpt("{All}", "+SN")
        ih.KeyOpt("{LWin}{RWin}{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}", "-S")
        ih.OnKeyDown := (hook, vk, sc) => Legend.ChordKeyDown(vk, sc)
        ih.OnKeyUp := (hook, vk, sc) => Legend.ChordKeyUp(vk)
        ih.Start()
        this.ActiveHwnd := WinExist("A")
        this.ChordTimer("Focus", () => Legend.CheckChordFocus(), 150)
        delay := this.Opt("ChordOverlay")
        if delay = "always"
            this.ShowChord()
        else if IsNumber(delay)
            this.ChordTimer("Show", () => Legend.ShowChord(), -Max(1, Integer(delay)))
        this.RestartChordTimeout()
    }

    static ChordTimer(name, fn, period) {
        timers := this.ChordState.Timers
        if timers.Has(name)
            SetTimer(timers[name], 0)
        timers[name] := fn
        SetTimer(fn, period)
    }

    static RestartChordTimeout() {
        seconds := this.Opt("ChordTimeout")
        if IsNumber(seconds) && seconds > 0
            this.ChordTimer("Timeout", () => Legend.CloseChord(), -Integer(seconds * 1000))
    }

    static ShowChord() {
        state := this.ChordState
        if !state || state.Shown
            return
        state.Shown := true
        this.Draw()
    }

    static CheckChordFocus() {
        if this.ChordState && WinExist("A") != this.ActiveHwnd
            this.CloseChord()
    }

    static ChordKeyUp(vk) {
        if this.ChordState
            this.ChordState.Keys.Up(vk)
    }

    ; Hook callback: track modifiers here, handle real keys on the script thread.
    static ChordKeyDown(vk, sc) {
        state := this.ChordState
        if !state || LegendKeyWatch.IgnoredVks.Has(vk) || state.Keys.Down(vk)
            return
        name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
        key := state.Keys.Key(name)
        SetTimer(() => Legend.ChordKey(key, name), -1)
    }

    static ChordKey(key, name) {
        static overlayKeys := Map("PgDn", "Next", "Ctrl+N", "Next", "PgUp", "Prev", "Ctrl+P", "Prev",
            "Tab", "Style", "=", "Density")
        state := this.ChordState
        if !state
            return
        id := key.Id
        if id == "Esc" || id == "Ctrl+G" || id == state.TriggerId
            return this.CloseChord()
        if id == "Backspace" {
            if this.Nav.Stack.Length = 1
                return this.CloseChord()
            this.Nav.Press("Backspace")
            return this.AfterChordStep()
        }
        if state.Shown && overlayKeys.Has(id) && !LegendChords.Find(this.Nav.Level.ChordItems, key) {
            action := overlayKeys[id]
            if action = "Style" || action = "Density"
                this.ChangeDisplay(action)
            else if this.Nav.Press(action) = "redraw"
                this.Draw()
            return this.RestartChordTimeout()
        }
        switch this.Nav.PressChord(key) {
            case "redraw":
                this.AfterChordStep()
            case "run":
                item := this.Nav.RunItem
                this.CloseChord()
                item.Run(name)
            default:
                shown := key.Verbatim != "" ? key.Verbatim
                    : !key.Mods.Length && StrLen(key.Name) = 1 ? StrLower(key.Name)
                    : LegendKeyName.Format(key, this.Theme["keyStyle"])
                this.CloseChord()
                ToolTip("Nothing on " shown)
                SetTimer(() => ToolTip(), -1000)
        }
    }

    static AfterChordStep() {
        if this.ChordState.Shown
            this.Draw()
        this.RestartChordTimeout()
    }

    static CloseChord() {
        state := this.ChordState
        if !state
            return
        this.ChordState := ""
        state.Hook.Stop()
        for name, fn in state.Timers
            SetTimer(fn, 0)
        if this.Gui
            this.Gui.Destroy(), this.Gui := ""
        if this.Measurer
            this.Measurer.Destroy(), this.Measurer := ""
    }
}
