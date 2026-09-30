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
#Include %A_LineFile%\..\src\Picker.ahk
#Include %A_LineFile%\..\src\Windows.ahk
#Include %A_LineFile%\..\src\WindowSwitcher.ahk

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
    static PickerState := ""

    static Page(title, match := "", options := "") => this.Registry.Page(title, match, options)

    ; The function that registers hotkeys: binder(keyName, fn, match). Replace it
    ; before binding keys to change how they're registered (e.g. to record them).
    static Binder {
        get => this.Registry.Binder
        set => this.Registry.Binder := value
    }
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
                for warning in result.Warnings
                    this.Registry.Warnings.Push(warning)
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
        for char in StrSplit("abcdefghijklmnopqrstuvwxyz0123456789")
            Hotkey(char, this.Handler(char))
        HotIf((*) => Legend.Visible && !Legend.Nav.Pinned)   ; pinned: they reach the app
        for key, action in Map("^n", "Next", "^p", "Prev", "^g", "Close")
            Hotkey(key, this.Handler(action))
        HotIf()
    }

    static Handler(action) => (*) => Legend.Handle(action)

    static Toggle() => this.Visible ? this.Close() : this.Open()

    static Open() {
        if this.PickerState
            this.ClosePickerNow(true)
        if this.ChordState
            this.CloseChord()
        this.LoadTheme()
        paginate := this.ApplyDisplay()
        theme := this.Theme

        pages := this.Registry.SortedPages()
        matches := []
        for page in pages
            if page.Match != "" && WinActive(page.Match)
                matches.Push(page)
        this.Nav := LegendNavigator(pages, paginate, theme["keyStyle"])
        this.Nav.Open(matches)
        this.ActiveHwnd := WinExist("A")
        try
            this.Draw()              ; only claim keys once there is an overlay to show
        catch as err {
            this.Close()
            throw err
        }
        this.Visible := true
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
        maxHeight := (area.Bottom - area.Top) * theme["maxHeightPercent"] // 100 - LegendOverlay.Chrome(theme, measurer)
        maxWidth := (area.Right - area.Left) * theme["maxWidthPercent"] // 100 - theme["padding"] * 2
        return rows => LegendLayout.Paginate(rows, measurer, maxHeight, theme["maxColumns"], theme["padding"],
            maxWidth, theme["columnGap"])
    }

    ; Tab cycles key notation, = flips density; both last until the script reloads.
    static ChangeDisplay(action) {
        if action = "Style" {
            for index, style in this.Styles
                if style = this.Theme["keyStyle"]
                    this.StyleOverride := this.Styles[Mod(index, this.Styles.Length) + 1]
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

    static Handle(action) => this.Serialized(() => this.HandleNow(action))

    static HandleNow(action) {
        ; serialized by Handle
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
        for modVk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
            if GetKeyState(Format("vk{:X}", modVk), "P")
                held.Push(modVk)
        this.Keys.Seed(held)
        keyHook := this.Watcher := InputHook("V L0")
        keyHook.KeyOpt("{All}", "N")
        keyHook.OnKeyDown := (hook, vk, sc) => Legend.OnKeyDown(vk)
        keyHook.OnKeyUp := (hook, vk, sc) => Legend.Keys.Up(vk)
        keyHook.Start()
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

    static OpenChord(chord) => this.Serialized(() => this.OpenChordNow(chord))

    static OpenChordNow(chord) {
        ; serialized by OpenChord
        if this.PickerState
            this.ClosePickerNow(true)
        if this.ChordState
            return this.CloseChord()          ; trigger again closes
        if this.Visible
            this.Close()
        this.LoadTheme()
        paginate := this.ApplyDisplay()
        this.Nav := LegendNavigator([], paginate, this.Theme["keyStyle"])
        this.Nav.OpenChord(chord)
        held := []
        for modVk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
            if GetKeyState(Format("vk{:X}", modVk), "P")
                held.Push(modVk)
        trigger := LegendKeyName.FromHotkey(chord.Hotkey)
        triggerHeld := StrLen(trigger.Name) > 0 && GetKeyState(trigger.Name, "P")
        state := this.ChordState := {Chord: chord, Keys: LegendChordKeys(held, trigger.Name, triggerHeld),
            Shown: false, TriggerId: trigger.Id, Timers: Map()}
        keyHook := state.Hook := InputHook("L0")
        keyHook.KeyOpt("{All}", "+SN")
        keyHook.KeyOpt("{LWin}{RWin}{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}", "-S")
        keyHook.OnKeyDown := (hook, vk, sc) => Legend.ChordKeyDown(vk, sc)
        keyHook.OnKeyUp := (hook, vk, sc) => Legend.ChordKeyUp(vk, sc)
        keyHook.Start()
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
        Critical
        state := this.ChordState
        if !state || state.Shown
            return
        state.Shown := true
        this.Draw()
    }

    static CheckChordFocus() {
        Critical
        if this.ChordState && WinExist("A") != this.ActiveHwnd
            this.CloseChord()
    }

    static ChordKeyUp(vk, sc) {
        if this.ChordState
            this.ChordState.Keys.Up(vk, GetKeyName(Format("vk{:X}sc{:X}", vk, sc)))
    }

    ; Hook callback: track modifiers here, handle real keys on the script thread.
    static ChordKeyDown(vk, sc) {
        state := this.ChordState
        if !state || LegendKeyWatch.IgnoredVks.Has(vk) || state.Keys.Down(vk)
            return
        name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
        if state.Keys.IsTriggerRepeat(name)
            return
        key := state.Keys.Key(name)
        if LegendChordKeys.NeedsMask(key)
            SetTimer(() => Send("{Blind}{vkE8}"), -1)   ; keep a lone Alt/Win release from opening a menu
        SetTimer(() => Legend.ChordKey(key, name), -1)
    }

    ; Critical: chord keys, the show timer and closing must not interrupt each other.
    ; Otherwise a fast second key can close the chord (destroying the measurer) while
    ; the first key is still building a submenu, or leave a half-built overlay behind.
    static ChordKey(key, name) {
        Critical
        static overlayKeys := Map("PgDn", "Next", "Ctrl+N", "Next", "PgUp", "Prev", "Ctrl+P", "Prev",
            "Tab", "Style", "=", "Density")
        state := this.ChordState
        if !state
            return
        keyId := key.Id
        if keyId == "Esc" || keyId == "Ctrl+G" || keyId == state.TriggerId
            return this.CloseChord()
        if keyId == "Backspace" {
            if this.Nav.Stack.Length = 1
                return this.CloseChord()
            this.Nav.Press("Backspace")
            return this.AfterChordStep()
        }
        if state.Shown && overlayKeys.Has(keyId) && !LegendChords.Find(this.Nav.Level.ChordItems, key) {
            action := overlayKeys[keyId]
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
                Critical "Off"   ; the action may take a while (launching an app)
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

    ; Runs fn without being interrupted by Legend's other key and timer handlers, then
    ; restores the caller's Critical setting (Critical applies to the whole thread).
    static Serialized(fn) {
        was := A_IsCritical
        Critical
        try
            return fn()
        finally
            Critical(was ? was : "Off")
    }

    static CloseChord() => this.Serialized(() => this.CloseChordNow())

    static CloseChordNow() {
        ; serialized by CloseChord
        state := this.ChordState
        if !state
            return
        this.ChordState := ""
        state.Hook.Stop()
        for name, timer in state.Timers
            SetTimer(timer, 0)
        if this.Gui
            this.Gui.Destroy(), this.Gui := ""
        if this.Measurer
            this.Measurer.Destroy(), this.Measurer := ""
    }

    ; ---- Picker mode ----

    static Picker(hotkey, title, source, options := "") {
        picker := LegendPicker(hotkey, title, source, options)
        return this.Registry.AddPicker(picker, (*) => Legend.OpenPicker(picker))
    }

    ; A picker over windows; see LegendWindowSwitcher for options.
    static WindowSwitcher(hotkey, options := "") {
        switcher := LegendWindowSwitcher(hotkey, options)
        picker := switcher.Picker
        this.Registry.AddPicker(picker, (*) => Legend.OpenPicker(picker))
        return switcher
    }

    static OpenPicker(picker) => this.Serialized(() => this.OpenPickerNow(picker))

    static OpenPickerNow(picker) {
        ; serialized by OpenPicker
        if this.PickerState
            return
        this.RunDeferred()   ; the last picker's OnPick / OnCancel before this one's source
        if this.Visible
            this.Close()
        if this.ChordState
            this.CloseChordNow()
        ; Capture keys before loading the source: a fast trigger → Enter must not
        ; reach the app while the source runs; those keys wait in Pending.
        trigger := LegendKeyName.FromHotkey(picker.Hotkey)
        triggerHeld := trigger.Name != "" && GetKeyState(trigger.Name, "P")
        state := this.PickerState := {Picker: picker, Keys: LegendChordKeys(this.HeldModifiers(), trigger.Name, triggerHeld),
            Highlighted: "", MeasuredDensity: "", Pending: [], DrawnLayout: ""}
        keyHook := state.Hook := InputHook("L0")
        keyHook.KeyOpt("{All}", "+SN")
        keyHook.KeyOpt("{LWin}{RWin}{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}", "-S")
        keyHook.OnKeyDown := (hook, vk, sc) => Legend.PickerKeyDown(vk, sc)
        keyHook.OnKeyUp := (hook, vk, sc) => Legend.PickerKeyUp(vk, sc)
        keyHook.Start()
        this.ActiveHwnd := WinExist("A")
        state.FocusTimer := () => Legend.CheckPickerFocus()
        SetTimer(state.FocusTimer, 150)
        try
            picker.Open()
        catch as err {
            this.ClosePickerNow(false)
            throw Error("picker '" picker.Title "': " err.Message, -1)
        }
        this.LoadTheme()
        try {
            this.PickerTheme()
            this.Highlight()
            this.DrawPicker()
        } catch as err {
            this.ClosePickerNow(true)
            throw err
        }
        if state.Pending.Length
            this.DrainPickerKeys()
    }

    ; OnPick / OnCancel run after the overlay is gone, outside Critical, on a timer;
    ; a picker opened before that timer fires runs it first.
    static Deferred := ""

    static Defer(callback) {
        this.RunDeferred()
        this.Deferred := callback
        SetTimer(() => Legend.RunDeferred(), -1)
    }

    static RunDeferred() {
        if !IsObject(callback := this.Deferred)
            return
        this.Deferred := ""
        was := A_IsCritical
        Critical("Off")
        try
            callback()
        finally
            Critical(was ? was : "Off")
    }

    static HeldModifiers() {
        held := []
        for modVk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
            if GetKeyState(Format("vk{:X}", modVk), "P")
                held.Push(modVk)
        return held
    }

    ; The session density toggle wins, then the picker's Density, then the theme's.
    static PickerTheme() {
        picker := this.PickerState.Picker
        density := this.DensityOverride != "" ? this.DensityOverride : picker.Density
        theme := LegendTheme.Resolve(this.BaseTheme, density, "")
        theme["legend"] := "off"   ; pickers have no modifier legend line to make room for
        return this.Theme := theme
    }

    static DrawPicker() {
        state := this.PickerState, picker := state.Picker
        theme := this.PickerTheme()
        if !this.Measurer || state.MeasuredDensity != theme["density"] {
            if this.Measurer
                this.Measurer.Destroy()
            this.Measurer := LegendMeasurer(theme)
            state.MeasuredDensity := theme["density"]
        }
        measurer := this.Measurer
        area := LegendOverlay.WorkArea()
        maxHeight := (area.Bottom - area.Top) * theme["maxHeightPercent"] // 100 - LegendOverlay.Chrome(theme, measurer)
        maxWidth := (area.Right - area.Left) * Min(theme["pickerWidthPercent"], theme["maxWidthPercent"]) // 100 - theme["padding"] * 2
        picker.PageSize := Max(1, maxHeight // LegendOverlay.PickerRowHeight(theme, measurer))
        layout := picker.LayoutKey "|" theme["density"]
        if this.Gui && state.DrawnLayout == layout {   ; only the cursor moved: no rebuild
            LegendOverlay.SelectPickerRow(this.Gui, theme, picker.Cursor ? picker.Cursor - (picker.ScreenIndex - 1) * picker.PageSize : 0)
            return
        }
        state.DrawnLayout := layout
        view := {Title: picker.TitleLine, Rows: picker.ScreenRows(), Empty: picker.EmptyText}
        old := this.Gui
        this.Gui := LegendOverlay.ShowPicker(view, theme, measurer, picker.Footer(theme["density"]), maxWidth)
        if old
            old.Destroy()
    }

    ; Calls OnHighlight when the selected item changed; with "" when nothing is
    ; selected any more (a filter with no match).
    static Highlight() {
        state := this.PickerState
        item := state.Picker.Selected
        if IsObject(item) ? IsObject(state.Highlighted) && item == state.Highlighted : !IsObject(state.Highlighted)
            return
        state.Highlighted := item
        onHighlight := state.Picker.OnHighlight
        if IsObject(onHighlight)
            onHighlight(item)
    }

    ; The character the active keyboard layout produces for vk/sc with the modifiers
    ; held now (Shift, AltGr, CapsLock), or "" (dead keys, non-printing keys).
    static TypedChar(vk, sc) {
        static modVks := [0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5]
        keyState := Buffer(256, 0)
        for modVk in modVks
            if GetKeyState(Format("vk{:X}", modVk), "P")
                NumPut("UChar", 0x80, keyState, modVk)
        if GetKeyState("CapsLock", "T")
            NumPut("UChar", 1, keyState, 0x14)
        threadId := DllCall("GetWindowThreadProcessId", "Ptr", WinExist("A"), "Ptr", 0, "UInt")
        layout := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
        chars := Buffer(16, 0)
        ; flag 4: leave the keyboard's dead-key state alone
        count := DllCall("ToUnicodeEx", "UInt", vk, "UInt", sc, "Ptr", keyState, "Ptr", chars, "Int", 8, "UInt", 4, "Ptr", layout)
        return count = 1 ? StrGet(chars, 1, "UTF-16") : ""
    }

    static PickerKeyUp(vk, sc) {
        if this.PickerState
            this.PickerState.Keys.Up(vk, GetKeyName(Format("vk{:X}sc{:X}", vk, sc)))
    }

    ; Hook callback: track modifiers here, handle keys on the script thread. The trigger
    ; pressed again while its modifiers are still held keeps those modifiers.
    static PickerKeyDown(vk, sc) {
        state := this.PickerState
        if !state || LegendKeyWatch.IgnoredVks.Has(vk) || state.Keys.Down(vk)
            return
        name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
        if state.Keys.IsTriggerRepeat(name)
            return
        key := state.Keys.Key(name)
        full := state.Keys.Key(name, true)
        if full.Id == state.Picker.TriggerId || full.Id == state.Picker.ShiftTriggerId
            key := full
        key.Char := this.TypedChar(vk, sc)
        if GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
            SetTimer(() => Send("{Blind}{vkE8}"), -1)   ; keep a lone Alt/Win release from opening a menu
        ; Keys that arrive while a redraw runs pile up here and are applied together,
        ; so a held key never builds a backlog that keeps scrolling after release.
        state.Pending.Push(key)
        if state.Pending.Length = 1
            SetTimer(() => Legend.DrainPickerKeys(), -1)
    }

    ; Test hook and single-key entry: queue key and drain.
    static PickerKey(key) {
        if this.PickerState {
            this.PickerState.Pending.Push(key)
            this.DrainPickerKeys()
        }
    }

    static DrainPickerKeys() {
        Critical
        state := this.PickerState
        if !state || !state.Pending.Length
            return
        keys := state.Pending, state.Pending := []
        picker := state.Picker
        batch := picker.KeyBatch(keys)
        loop batch.Density
            this.DensityOverride := (this.DensityOverride != "" ? this.DensityOverride : this.Theme["density"]) = "compact" ? "comfortable" : "compact"
        switch batch.Action {
            case "redraw":
                this.Highlight()
                this.DrawPicker()
            case "pick":
                item := picker.Selected
                this.ClosePickerNow(false)
                onPick := picker.OnPick
                this.Defer(() => onPick(item))
            case "cancel":
                this.ClosePickerNow(true)
        }
    }

    static CheckPickerFocus() {
        Critical
        if this.PickerState && WinExist("A") != this.ActiveHwnd
            this.ClosePickerNow(true)
    }

    static ClosePicker(cancelled := true) => this.Serialized(() => this.ClosePickerNow(cancelled))

    static ClosePickerNow(cancelled) {
        state := this.PickerState
        if !state
            return
        this.PickerState := ""
        state.Hook.Stop()
        SetTimer(state.FocusTimer, 0)
        if this.Gui
            this.Gui.Destroy(), this.Gui := ""
        if this.Measurer
            this.Measurer.Destroy(), this.Measurer := ""
        onCancel := state.Picker.OnCancel
        if cancelled && IsObject(onCancel)
            this.Defer(onCancel)
    }
}
