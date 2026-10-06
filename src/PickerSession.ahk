#Requires AutoHotkey v2.0

class LegendPickerSession {
    __New(picker, renderer) {
        this.Picker := picker, this.Renderer := renderer
        this.Keys := "", this.Hook := "", this.FocusTimer := "", this.DrainTimer := "", this.MaskTimer := ""
        this.ActiveHwnd := 0, this.Highlighted := "", this.MeasuredDensity := "", this.Pending := []
        this.Ready := false, this.CancelOnClose := false, this.Closed := false
    }

    Active => !this.Closed && Legend.Session == this

    Open() {
        local err, keyHook, trigger, triggerHeld
        ; Capture before the source loads: fast keys wait here instead of reaching
        ; the app while a slow source is running.
        trigger := LegendKeyName.FromHotkey(this.Picker.Hotkey)
        triggerHeld := trigger.Name != "" && GetKeyState(trigger.Name, "P")
        this.Keys := LegendChordKeys(Legend.HeldModifiers(), trigger.Name, triggerHeld)
        keyHook := this.Hook := InputHook("L0")
        keyHook.KeyOpt("{All}", "+SN")
        keyHook.KeyOpt("{LWin}{RWin}{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}", "-S")
        keyHook.OnKeyDown := (hook, vk, sc) => this.OnKeyDown(vk, sc)
        keyHook.OnKeyUp := (hook, vk, sc) => this.OnKeyUp(vk, sc)
        keyHook.Start()
        this.ActiveHwnd := WinExist("A")
        this.FocusTimer := () => this.CheckFocus()
        this.DrainTimer := () => this.DrainKeys()
        this.MaskTimer := () => this.MaskModifiers()
        SetTimer(this.FocusTimer, 150)
        try
            this.Picker.Open()
        catch as err
            throw Error("picker '" this.Picker.Title "': " err.Message, -1)
        if !this.Active
            return
        this.CancelOnClose := true
        this.Renderer.LoadTheme()
        this.PickerTheme()
        this.Highlight()
        if !this.Active
            return
        this.Draw()
        this.Ready := true
        if this.Pending.Length
            this.DrainKeys()
    }

    ; A density toggle wins, then the picker's option, then the base theme.
    PickerTheme() {
        local density, theme
        density := Legend.DensityOverride != "" ? Legend.DensityOverride : this.Picker.Density
        theme := LegendTheme.Resolve(this.Renderer.BaseTheme, density, "")
        theme["legend"] := "off"
        return this.Renderer.Theme := theme
    }

    Draw() {
        local area, index, maxHeight, maxWidth, measurer, picker, theme
        if !this.Active
            return
        picker := this.Picker, theme := this.PickerTheme()
        if !this.Renderer.Measurer || this.MeasuredDensity != theme["density"] {
            this.Renderer.Measure(theme)
            this.MeasuredDensity := theme["density"]
        }
        measurer := this.Renderer.Measurer
        area := LegendOverlay.WorkArea()
        maxHeight := (area.Bottom - area.Top) * theme["maxHeightPercent"] // 100 - LegendOverlay.Chrome(theme, measurer)
        maxWidth := (area.Right - area.Left) * Min(theme["pickerWidthPercent"], theme["maxWidthPercent"]) // 100 - theme["padding"] * 2
        picker.PageSize := Max(1, maxHeight // LegendOverlay.PickerRowHeight(theme, measurer))
        index := picker.Cursor ? picker.Cursor - (picker.ScreenIndex - 1) * picker.PageSize : 0
        this.Renderer.Render("picker|" picker.LayoutKey "|" theme["density"],
            () => LegendOverlay.ShowPicker({Title: picker.TitleLine, Rows: picker.ScreenRows(), Empty: picker.EmptyText, SelectedIndex: index},
                theme, measurer, picker.Footer(theme["density"]), maxWidth), index)
    }

    Highlight() {
        local item, onHighlight
        if !this.Active
            return
        item := this.Picker.Selected
        if IsObject(item) ? IsObject(this.Highlighted) && item == this.Highlighted : !IsObject(this.Highlighted)
            return
        this.Highlighted := item
        onHighlight := this.Picker.OnHighlight
        if IsObject(onHighlight)
            onHighlight(item)
    }

    ; Character produced by the active keyboard layout, including Shift/AltGr.
    static TypedChar(vk, sc) {
        local chars, count, keyState, layout, modVk, threadId
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
        ; flag 4 leaves the keyboard's dead-key state alone.
        count := DllCall("ToUnicodeEx", "UInt", vk, "UInt", sc, "Ptr", keyState, "Ptr", chars, "Int", 8, "UInt", 4, "Ptr", layout)
        return count = 1 ? StrGet(chars, 1, "UTF-16") : ""
    }

    OnKeyUp(vk, sc) {
        if this.Active
            this.Keys.Up(vk, GetKeyName(Format("vk{:X}sc{:X}", vk, sc)))
    }

    OnKeyDown(vk, sc) {
        local full, key, name
        if !this.Active || LegendKeyWatch.IgnoredVks.Has(vk) || this.Keys.Down(vk)
            return
        name := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))
        if this.Keys.IsTriggerRepeat(name)
            return
        key := this.Keys.Key(name), full := this.Keys.Key(name, true)
        if full.Id == this.Picker.TriggerId || full.Id == this.Picker.ShiftTriggerId
            key := full
        key.Char := LegendPickerSession.TypedChar(vk, sc)
        if GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
            SetTimer(this.MaskTimer, -1)
        ; Coalesce keys arriving during a redraw, so key repeat leaves no backlog.
        this.Pending.Push(key)
        if this.Pending.Length = 1
            SetTimer(this.DrainTimer, -1)
    }

    MaskModifiers() {
        if this.Active
            Send("{Blind}{vkE8}")
    }

    Key(key) {
        if this.Active {
            this.Pending.Push(key)
            this.DrainKeys()
        }
    }

    DrainKeys() => Legend.Serialized(() => this.DrainKeysNow())

    DrainKeysNow() {
        local batch, item, keys, onPick, picker
        if !this.Active || !this.Ready || !this.Pending.Length
            return
        keys := this.Pending, this.Pending := []
        picker := this.Picker, batch := picker.KeyBatch(keys)
        if !this.Active
            return
        loop batch.Density
            Legend.DensityOverride := (Legend.DensityOverride != "" ? Legend.DensityOverride : this.Renderer.Theme["density"]) = "compact"
                ? "comfortable" : "compact"
        switch batch.Action {
            case "redraw":
                this.Highlight()
                this.Draw()
            case "pick":
                item := picker.Selected, onPick := picker.OnPick
                this.Close(false)
                Legend.Defer(() => onPick(item))
            case "cancel": this.Close(true)
        }
    }

    CheckFocus() => Legend.Serialized(() => this.CheckFocusNow())

    CheckFocusNow() {
        if this.Active && WinExist("A") != this.ActiveHwnd
            this.Close(true)
    }

    Close(cancelled := true) => Legend.Serialized(() => this.CloseNow(cancelled))

    CloseNow(cancelled) {
        local hook, onCancel, timer
        if this.Closed
            return
        Legend.DetachSession(this)
        this.Closed := true, this.Ready := false
        hook := this.Hook, this.Hook := ""
        for timer in [this.FocusTimer, this.DrainTimer, this.MaskTimer]
            if timer
                SetTimer(timer, 0)
        this.FocusTimer := "", this.DrainTimer := "", this.MaskTimer := ""
        this.Pending := [], this.Keys := "", this.Highlighted := ""
        try {
            if hook {
                hook.OnKeyDown := "", hook.OnKeyUp := ""
                hook.Stop()
            }
        } finally {
            try
                this.Renderer.Close()
            finally {
                onCancel := this.Picker.OnCancel
                if cancelled && this.CancelOnClose && IsObject(onCancel)
                    Legend.Defer(onCancel)
            }
        }
    }
}
