#Requires AutoHotkey v2.0
#Include %A_LineFile%\..\src\KeyName.ahk
#Include %A_LineFile%\..\src\PageFile.ahk
#Include %A_LineFile%\..\src\Registry.ahk
#Include %A_LineFile%\..\src\Rows.ahk
#Include %A_LineFile%\..\src\Layout.ahk
#Include %A_LineFile%\..\src\Navigator.ahk
#Include %A_LineFile%\..\src\Letters.ahk
#Include %A_LineFile%\..\src\Theme.ahk
#Include %A_LineFile%\..\src\Overlay.ahk
#Include %A_LineFile%\..\src\Selection.ahk
#Include %A_LineFile%\..\src\KeyWatch.ahk
#Include %A_LineFile%\..\src\ChordMatch.ahk
#Include %A_LineFile%\..\src\Chord.ahk
#Include %A_LineFile%\..\src\Picker.ahk
#Include %A_LineFile%\..\src\Windows.ahk
#Include %A_LineFile%\..\src\WindowSwitcher.ahk
#Include %A_LineFile%\..\src\Session.ahk
#Include %A_LineFile%\..\src\ReferenceSession.ahk
#Include %A_LineFile%\..\src\ChordSession.ahk
#Include %A_LineFile%\..\src\PickerSession.ahk

; Registration and configuration live here. An interaction owns its transient state.
class Legend {
    static Registry := LegendRegistry()
    static Options := "", Session := "", HelpId := ""
    static StyleOverride := "", DensityOverride := ""   ; display toggles last until reload
    static Styles := ["text", "symbols", "ahk"]
    static DefaultOptions := {HelpKey: "!/", Pages: [], PageKeys: Map(), LetterFile: A_AppData "\Legend\page-letters.txt",
        Themes: [], Theme: "auto", ChordTimeout: 0, ChordOverlay: 400, ChordReference: true}
    static OverlayKeys := Map("Esc", "Close", "Backspace", "Backspace", "Space", "Next",
        "PgDn", "Next", "PgUp", "Prev", "``", "Pin", "Tab", "Style", "=", "Density")
    static CtrlKeys := Map("^n", "Down", "^p", "Up", "^f", "Next", "^b", "Prev", "^g", "Close")
    static MenuKeys := Map("Down", "Down", "Up", "Up", "Enter", "Enter")
    static WatchClaims := ["``", "=", "Ctrl+N", "Ctrl+P", "Ctrl+F", "Ctrl+B", "Ctrl+G"]
    static ChordOverlayKeys := Map("PgDn", "Next", "Ctrl+F", "Next", "PgUp", "Prev", "Ctrl+B", "Prev",
        "Tab", "Style", "=", "Density")

    static Page(title, match := "", options := "") => this.Registry.Page(title, match, options)
    static Binder {
        get => this.Registry.Binder
        set => this.Registry.Binder := value
    }
    static Bind(path, hotkey, description, fn, options := "") => this.Registry.Bind(path, hotkey, description, fn, options)
    static Doc(path, keyText, description) => this.Registry.Doc(path, keyText, description)
    static Run(key, label, action, options := "") => LegendChordItem(key, label, action, "", options)
    static Menu(key, label, items) => LegendChordItem(key, label, "", items)

    static Chord(hotkey, title, items, options := "") {
        local chord
        chord := LegendChord(hotkey, title, items, options)
        return this.Registry.AddChord(chord, (*) => Legend.OpenChord(chord))
    }

    static Picker(hotkey, title, source, options := "") {
        local picker
        picker := LegendPicker(hotkey, title, source, options)
        return this.Registry.AddPicker(picker, (*) => Legend.OpenPicker(picker))
    }

    static WindowSwitcher(hotkey, options := "") {
        local picker, switcher
        options := IsObject(options) ? options.Clone() : {}
        options.RenderContext := () => Legend.RenderContext()
        switcher := LegendWindowSwitcher(hotkey, options)
        picker := switcher.Picker
        this.Registry.AddPicker(picker, (*) => Legend.OpenPicker(picker))
        return switcher
    }

    static RenderContext() {
        local renderer
        renderer := IsObject(this.Session) ? this.Session.Renderer : ""
        return {Outline: IsObject(renderer) && IsObject(renderer.Theme) ? renderer.Theme["outline"] : "89B4FA",
            Below: IsObject(renderer) && IsObject(renderer.Gui) ? renderer.Gui.Hwnd : 0}
    }

    static Opt(name) => IsObject(this.Options) ? this.Options.%name% : this.DefaultOptions.%name%
    static Warnings => this.Registry.Warnings
    static ReferenceActive() => this.Session is LegendReferenceSession && this.Session.Ready
    static ClaimsLetters => this.ReferenceActive() && this.Session.Nav.ClaimsLetters
    static CtrlKeysActive() => this.ReferenceActive() && !this.Session.Nav.Pinned
    static MenuKeysActive() => this.ClaimsLetters && !this.Session.Nav.Pinned

    static Start(options := {}) {
        local action, char, fallback, key, name
        if this.Options
            throw Error("Legend.Start was already called", -1)
        this.Options := {}
        for name, fallback in this.DefaultOptions.OwnProps()
            this.Options.%name% := options.HasOwnProp(name) ? options.%name% : fallback
        this.Registry.SetPageKeys(this.Options.PageKeys)
        this.Registry.LoadPages(this.Options.Pages)
        this.Registry.EnableChordReference(this.Options.ChordReference)
        OnMessage(0x200, (wParam, lParam, msg, hwnd) => Legend.OnMouseMove(hwnd))
        this.HelpId := LegendKeyName.FromHotkey(this.Options.HelpKey).Id
        HotIf()
        Hotkey(this.Options.HelpKey, (*) => Legend.Toggle())
        HotIf((*) => Legend.ReferenceActive())
        for key, action in this.OverlayKeys
            Hotkey(key, this.Handler(action))
        HotIf((*) => Legend.ClaimsLetters)
        for char in StrSplit("abcdefghijklmnopqrstuvwxyz0123456789")
            Hotkey(char, this.Handler(char))
        HotIf((*) => Legend.CtrlKeysActive())
        for key, action in this.CtrlKeys
            Hotkey(key, this.Handler(action))
        HotIf((*) => Legend.MenuKeysActive())
        for key, action in this.MenuKeys
            Hotkey(key, this.Handler(action))
        HotIf()
    }

    static Handler(action) => (*) => Legend.Handle(action)
    static Toggle() => this.ReferenceActive() ? this.Close() : this.Open()
    static Open() => this.ReplaceSession(() => LegendReferenceSession(LegendSessionRenderer()))

    static OpenChord(chord) => this.Serialized(() => this.Session is LegendChordSession && this.Session.Capturing
        ? this.Close() : this.ReplaceSession(() => LegendChordSession(chord, LegendSessionRenderer())))

    static OpenPicker(picker) => this.Serialized(() => this.OpenPickerNow(picker))

    static OpenPickerNow(picker) {
        if this.Session is LegendPickerSession
            return
        this.RunDeferred()
        return this.ReplaceSession(() => LegendPickerSession(picker, LegendSessionRenderer()))
    }

    ; The factory runs after teardown, so constructing/opening never overlaps the old
    ; interaction's resources. Every open failure disposes the partial session.
    static ReplaceSession(createSession) => this.Serialized(() => this.ReplaceSessionNow(createSession))

    static ReplaceSessionNow(createSession) {
        local err, session
        this.Close()
        session := createSession()
        this.Session := session
        try
            session.Open()
        catch as err {
            this.DetachSession(session)
            try session.Close()
            throw err
        }
        return session
    }

    ; Called by a session before releasing its resources. A stale close cannot detach
    ; a replacement that is already active.
    static DetachSession(session) {
        if this.Session == session
            this.Session := ""
    }

    static Close(cancelled := true) => this.Serialized(() => this.CloseNow(cancelled))

    static CloseNow(cancelled) {
        local session
        if IsObject(session := this.Session) {
            this.DetachSession(session)
            session.Close(cancelled)
        }
    }

    static Handle(action) {
        if this.ReferenceActive()
            this.Session.Handle(action)
    }

    static OnMouseMove(hwnd) {
        if this.ReferenceActive() || this.Session is LegendChordSession
            this.Session.OnMouseMove(hwnd)
    }

    static ChangeDisplay(action, theme) {
        local index, style
        if action = "Style" {
            for index, style in this.Styles
                if style = theme["keyStyle"] {
                    this.StyleOverride := this.Styles[Mod(index, this.Styles.Length) + 1]
                    break
                }
        } else
            this.DensityOverride := theme["density"] = "compact" ? "comfortable" : "compact"
    }

    static AllWarnings(renderer) {
        local all
        all := this.Registry.Warnings.Clone()
        all.Push(renderer.ThemeWarnings*)
        return all
    }

    static WarningTip(messages) {
        local message, text
        text := ""
        for message in messages
            text .= (A_Index > 1 ? "`n" : "") A_Index ". " message
        return text
    }

    static HeldModifiers() {
        local held, modVk
        held := []
        for modVk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]
            if GetKeyState(Format("vk{:X}", modVk), "P")
                held.Push(modVk)
        return held
    }

    ; Critical belongs to the calling AHK thread; always restore its original value.
    static Serialized(fn) {
        local previousCritical
        previousCritical := A_IsCritical
        Critical
        try
            return fn()
        finally
            Critical(previousCritical ? previousCritical : "Off")
    }

    ; OnPick / OnCancel run after teardown, outside Critical. This sole facade-owned
    ; deferred slot is flushed before opening the next picker.
    static Deferred := "", DeferredTimer := () => Legend.RunDeferred()

    static Defer(callback) {
        this.RunDeferred()
        this.Deferred := callback
        SetTimer(this.DeferredTimer, -1)
    }

    static RunDeferred() {
        local callback, previousCritical
        if !IsObject(callback := this.Deferred)
            return
        this.Deferred := ""
        SetTimer(this.DeferredTimer, 0)
        previousCritical := A_IsCritical
        Critical("Off")
        try
            callback()
        finally
            Critical(previousCritical ? previousCritical : "Off")
    }
}
