#Requires AutoHotkey v2.0

class LegendChordSession {
    __New(chord, renderer) {
        this.Chord := chord, this.Renderer := renderer
        this.Nav := "", this.Keys := "", this.Hook := "", this.Timers := Map()
        this.Pending := [], this.ActiveHwnd := 0, this.TriggerId := ""
        this.Shown := false, this.Capturing := false, this.TipShown := false, this.Closed := false
    }

    Active => !this.Closed && Legend.Session == this

    Open() {
        local delay, keyHook, paginate, trigger, triggerHeld
        this.Renderer.LoadTheme()
        paginate := this.Renderer.ApplyDisplay(Legend.DensityOverride, Legend.StyleOverride)
        this.Nav := LegendNavigator([], paginate, this.Renderer.Theme["keyStyle"])
        this.Nav.OpenChord(this.Chord)
        trigger := LegendKeyName.FromHotkey(this.Chord.Hotkey)
        triggerHeld := trigger.Name != "" && GetKeyState(trigger.Name, "P")
        this.Keys := LegendChordKeys(Legend.HeldModifiers(), trigger.Name, triggerHeld)
        this.TriggerId := trigger.Id
        keyHook := this.Hook := InputHook("L0")
        keyHook.KeyOpt("{All}", "+SN")
        keyHook.KeyOpt("{LWin}{RWin}{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}", "-S")
        keyHook.OnKeyDown := (hook, vk, sc) => this.OnKeyDown(vk, sc)
        keyHook.OnKeyUp := (hook, vk, sc) => this.OnKeyUp(vk, sc)
        this.Capturing := true
        keyHook.Start()
        this.ActiveHwnd := WinExist("A")
        this.Timer("Focus", () => this.CheckFocus(), 150)
        delay := Legend.Opt("ChordOverlay")
        if delay = "always"
            this.Show()
        else if IsNumber(delay)
            this.Timer("Show", () => this.Show(), -Max(1, Integer(delay)))
        this.RestartTimeout()
    }

    Timer(name, callback, period) {
        if this.Timers.Has(name)
            SetTimer(this.Timers[name], 0)
        this.Timers[name] := callback
        SetTimer(callback, period)
    }

    RestartTimeout() {
        local seconds
        seconds := Legend.Opt("ChordTimeout")
        if this.Active && this.Capturing && IsNumber(seconds) && seconds > 0
            this.Timer("Timeout", () => this.Close(), -Integer(seconds * 1000))
    }

    Show() => Legend.Serialized(() => this.ShowNow())

    ShowNow() {
        if !this.Active || !this.Capturing || this.Shown
            return
        this.Shown := true
        this.Draw()
    }

    Draw() {
        if this.Active && this.Capturing
            this.Renderer.DrawNavigator(this.Nav, Legend.AllWarnings(this.Renderer).Length)
    }

    ; Warning hover belongs to the capturing chord. Once capture ends, mouse
    ; movement must leave the session's unmatched-key notification alone.
    OnMouseMove(hwnd) {
        local overlay
        if !this.Active || !this.Capturing
            return
        overlay := this.Renderer.Gui
        overlay := IsObject(overlay) && overlay.HasOwnProp("WarningBadge") ? overlay : ""
        if overlay && hwnd = overlay.WarningBadge.Hwnd {
            if !this.TipShown
                ToolTip(Legend.WarningTip(Legend.AllWarnings(this.Renderer))), this.TipShown := true
        } else if this.TipShown
            ToolTip(), this.TipShown := false
    }

    ChangeDisplay(action) {
        local paginate
        Legend.ChangeDisplay(action, this.Renderer.Theme)
        paginate := this.Renderer.ApplyDisplay(Legend.DensityOverride, Legend.StyleOverride)
        this.Nav.Relayout(paginate, this.Renderer.Theme["keyStyle"])
        this.Draw()
    }

    CheckFocus() => Legend.Serialized(() => this.CheckFocusNow())

    CheckFocusNow() {
        if this.Active && this.Capturing && WinExist("A") != this.ActiveHwnd
            this.Close()
    }

    OnKeyUp(vk, sc) {
        if this.Active && this.Capturing
            this.Keys.Up(vk, GetKeyName(Format("vk{:X}sc{:X}", vk, sc)))
    }

    ; Track modifiers in the hook; dispatch real keys on a session-bound timer.
    OnKeyDown(vk, sc) {
        local key, name
        if !this.Active || !this.Capturing || LegendKeyWatch.IgnoredVks.Has(vk) || this.Keys.Down(vk)
            return
        name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
        if this.Keys.IsTriggerRepeat(name)
            return
        key := this.Keys.Key(name)
        if LegendChordKeys.NeedsMask(key)
            this.Timer("Mask", () => this.MaskModifiers(), -1)
        this.Pending.Push({Key: key, Name: name})
        if this.Pending.Length = 1
            this.Timer("Keys", () => this.DrainKeys(), -1)
    }

    MaskModifiers() {
        if this.Active && this.Capturing
            Send("{Blind}{vkE8}")
    }

    DrainKeys() => Legend.Serialized(() => this.DrainKeysNow())

    DrainKeysNow() {
        local pending, step
        if !this.Active || !this.Capturing
            return
        pending := this.Pending, this.Pending := []
        for step in pending {
            if !this.Active || !this.Capturing
                break
            this.KeyNow(step.Key, step.Name)
        }
    }

    ; Drawing, show timers, key steps and teardown cannot interrupt each other.
    Key(key, name) => Legend.Serialized(() => this.KeyNow(key, name))

    KeyNow(key, name) {
        local action, item, keyId, shown
        if !this.Active || !this.Capturing
            return
        keyId := key.Id
        if keyId == "Esc" || keyId == "Ctrl+G" || keyId == this.TriggerId
            return this.Close()
        if keyId == "Backspace" {
            if this.Nav.Stack.Length = 1
                return this.Close()
            this.Nav.Press("Backspace")
            return this.AfterStep()
        }
        if this.Shown && Legend.ChordOverlayKeys.Has(keyId) && !LegendChords.Find(this.Nav.Level.ChordItems, key) {
            action := Legend.ChordOverlayKeys[keyId]
            if action = "Style" || action = "Density"
                this.ChangeDisplay(action)
            else if this.Nav.Press(action) = "redraw"
                this.Draw()
            return this.RestartTimeout()
        }
        switch this.Nav.PressChord(key) {
            case "redraw": this.AfterStep()
            case "run":
                item := this.Nav.RunItem
                this.Close()
                Critical("Off")   ; actions may launch apps or otherwise take a while
                item.Run(name)
            default:
                shown := key.Verbatim != "" ? key.Verbatim
                    : !key.Mods.Length && StrLen(key.Name) = 1 ? StrLower(key.Name)
                    : LegendChordMatch.IsShiftedLetter(key.Mods, key.Name) ? StrUpper(key.Name)
                    : LegendKeyName.Format(key, this.Renderer.Theme["keyStyle"])
                this.Notify(shown)
        }
    }

    AfterStep() {
        if this.Shown
            this.Draw()
        this.RestartTimeout()
    }

    ; A miss ends capture and rendering immediately. The remaining notification
    ; still has an owner, so replacement can dismiss it and cancel its timer.
    Notify(shown) {
        this.Capturing := false
        this.ReleaseCapture()
        ToolTip("Nothing on " shown), this.TipShown := true
        this.Timer("Dismiss", () => this.Close(), -1000)
    }

    ReleaseCapture() {
        local hook, name, timer, timers
        hook := this.Hook, this.Hook := ""
        timers := this.Timers, this.Timers := Map()
        this.Pending := [], this.Nav := "", this.Keys := ""
        for name, timer in timers
            SetTimer(timer, 0)
        try {
            if hook {
                hook.OnKeyDown := "", hook.OnKeyUp := ""
                hook.Stop()
            }
        } finally
            this.Renderer.Close()
    }

    Close(cancelled := true) => Legend.Serialized(() => this.CloseNow())

    CloseNow() {
        if this.Closed
            return
        Legend.DetachSession(this)
        this.Closed := true, this.Capturing := false
        try
            this.ReleaseCapture()
        finally {
            if this.TipShown
                ToolTip(), this.TipShown := false
        }
    }
}
