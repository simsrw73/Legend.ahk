#Requires AutoHotkey v2.0

class LegendReferenceSession {
    __New(renderer) {
        this.Renderer := renderer
        this.Nav := "", this.Watcher := "", this.Keys := ""
        this.FocusTimer := "", this.ComboTimer := "", this.ActiveHwnd := 0
        this.TipShown := false, this.Ready := false, this.Closed := false
    }

    Active => !this.Closed && Legend.Session == this

    Open() {
        local matches, page, pages, paginate, sticky, warnings
        this.Renderer.LoadTheme()
        paginate := this.Renderer.ApplyDisplay(Legend.DensityOverride, Legend.StyleOverride)
        Legend.Registry.CheckPageKeys()
        pages := Legend.Registry.SortedPages()
        sticky := LegendLetterStore.Assign(pages, Legend.Opt("LetterFile"))
        matches := []
        for page in pages
            if page.Match != "" && WinActive(page.Match)
                matches.Push(page)
        if (warnings := Legend.AllWarnings(this.Renderer)).Length
            pages.Push(LegendRegistry.WarningsPage(warnings))
        this.Nav := LegendNavigator(pages, paginate, this.Renderer.Theme["keyStyle"])
        this.Nav.LetterOf := page => sticky.Has(StrLower(page.Title)) ? sticky[StrLower(page.Title)] : ""
        this.Nav.Open(matches)
        this.ActiveHwnd := WinExist("A")
        this.Draw()   ; claim keys only after there is an overlay to show
        this.Ready := true
        this.StartWatching()
    }

    Draw() {
        if this.Active
            this.Renderer.DrawNavigator(this.Nav, Legend.AllWarnings(this.Renderer).Length)
    }

    ChangeDisplay(action) {
        local paginate
        Legend.ChangeDisplay(action, this.Renderer.Theme)
        paginate := this.Renderer.ApplyDisplay(Legend.DensityOverride, Legend.StyleOverride)
        this.Nav.Relayout(paginate, this.Renderer.Theme["keyStyle"])
        this.Draw()
    }

    Handle(action) => Legend.Serialized(() => this.HandleNow(action))

    HandleNow(action) {
        if !this.Active || !this.Ready
            return
        if action = "Style" || action = "Density"
            return this.ChangeDisplay(action)
        switch this.Nav.Press(action) {
            case "redraw": this.Draw()
            case "close": this.Close()
        }
    }

    ; The warning tooltip belongs to the reference interaction.
    OnMouseMove(hwnd) {
        local overlay
        if !this.Active
            return
        overlay := this.Renderer.Gui
        overlay := IsObject(overlay) && overlay.HasOwnProp("WarningBadge") ? overlay : ""
        if overlay && hwnd = overlay.WarningBadge.Hwnd {
            if !this.TipShown
                ToolTip(Legend.WarningTip(Legend.AllWarnings(this.Renderer))), this.TipShown := true
        } else if this.TipShown
            ToolTip(), this.TipShown := false
    }

    StartWatching() {
        local keyHook
        this.Keys := LegendKeyWatch(Legend.HelpId, Legend.WatchClaims)
        this.Keys.Seed(Legend.HeldModifiers())
        keyHook := this.Watcher := InputHook("V L0")
        keyHook.KeyOpt("{All}", "N")
        keyHook.OnKeyDown := (hook, vk, sc) => this.OnKeyDown(vk)
        keyHook.OnKeyUp := (hook, vk, sc) => this.OnKeyUp(vk)
        keyHook.Start()
        this.FocusTimer := () => this.CheckFocus()
        this.ComboTimer := () => this.Handle("Combo")
        SetTimer(this.FocusTimer, 150)
    }

    OnKeyUp(vk) {
        if this.Active
            this.Keys.Up(vk)
    }

    OnKeyDown(vk) {
        local kind
        if !this.Active
            return
        kind := this.Keys.Down(vk, GetKeyName(Format("vk{:X}", vk)))
        if kind = "combo" || (kind = "letter" && !this.Nav.ClaimsLetters)
            SetTimer(this.ComboTimer, -1)
    }

    CheckFocus() {
        if !this.Active
            return
        if this.Nav.Pinned {
            this.ActiveHwnd := WinExist("A")
            return
        }
        if WinExist("A") != this.ActiveHwnd
            this.Handle("FocusLost")
    }

    Close(cancelled := true) => Legend.Serialized(() => this.CloseNow())

    CloseNow() {
        local watcher
        if this.Closed
            return
        Legend.DetachSession(this)
        this.Closed := true, this.Ready := false
        if this.TipShown
            ToolTip(), this.TipShown := false
        watcher := this.Watcher, this.Watcher := ""
        if this.FocusTimer
            SetTimer(this.FocusTimer, 0), this.FocusTimer := ""
        if this.ComboTimer
            SetTimer(this.ComboTimer, 0), this.ComboTimer := ""
        this.Keys := "", this.Nav := ""
        try {
            if watcher {
                watcher.OnKeyDown := "", watcher.OnKeyUp := ""
                watcher.Stop()
            }
        } finally
            this.Renderer.Close()
    }
}
