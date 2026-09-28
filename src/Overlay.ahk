#Requires AutoHotkey v2.0

; Measures rows with the theme's fonts, for LegendLayout. Callable: measurer(row).
class LegendMeasurer {
    __New(theme) {
        this.Theme := theme
        this.Gui := Gui("-Caption +ToolWindow -DPIScale")  ; physical pixels, like the work area
        this.Cache := Map()
    }

    Call(row) {
        spacing := this.Theme["rowSpacing"]
        if row.Kind = "entry" {
            key := this.Size(row.Key, "key"), text := this.Size(row.Text, "body")
            return {KeyW: key.W, TextW: text.W, H: Max(key.H, text.H) + spacing}
        }
        size := this.Size(row.Text, row.Kind)
        return {KeyW: 0, TextW: size.W, H: size.H + spacing * (row.Kind = "heading" ? 2 : 1)}
    }

    Size(text, kind) {
        id := kind "`n" text
        if !this.Cache.Has(id) {
            font := LegendOverlay.Font(this.Theme, kind)
            this.Gui.SetFont("norm " font[1], font[2])
            ctrl := this.Gui.AddText("+0x80", text = "" ? " " : text)
            ctrl.GetPos(, , &w, &h)
            this.Cache[id] := {W: w, H: h}
        }
        return this.Cache[id]
    }

    Destroy() => this.Gui.Destroy()
}

; Draws one navigator view as an always-on-top panel that never takes focus,
; centered on the monitor of the active window.
class LegendOverlay {
    static Font(theme, kind) {
        switch kind {
            case "title":   return ["s" theme["titleSize"] " w600", theme["uiFont"]]
            case "heading": return ["s" theme["headingSize"] " w700", theme["uiFont"]]
            case "group":   return ["s" (theme["bodySize"] - 1) " w600", theme["uiFont"]]
            case "key":     return ["s" theme["bodySize"] " w700", theme["keyFont"]]
            default:        return ["s" theme["bodySize"] " w400", theme["uiFont"]]
        }
    }

    static Show(view, theme, measurer, footer, legendLine, pinned, warningCount) {
        pad := theme["padding"], spacing := theme["rowSpacing"]
        ; WS_EX_NOACTIVATE; -DPIScale keeps coordinates in the measurer's physical pixels
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
        g.BackColor := theme["background"]
        g.MarginX := pad, g.MarginY := pad

        title := this.AddText(g, theme, "title", theme["title"], "xm ym", StrUpper(view.Title))
        title.GetPos(, &ty, , &th)
        top := ty + th + spacing * 2
        if legendLine != "" && theme["legend"] = "top" {
            line := this.AddText(g, theme, "body", theme["footer"], "xm y" top, legendLine)
            line.GetPos(, , , &lh)
            top += lh + spacing * 2
        }

        x := pad, bottom := top
        for col in view.Columns {
            y := top
            for row in col.Rows {
                size := measurer(row)
                switch row.Kind {
                    case "heading":
                        this.AddText(g, theme, "heading", theme["category"], "x" x " y" (y + spacing), row.Text)
                    case "group":
                        this.AddText(g, theme, "group", theme["group"], "x" x " y" y, row.Text)
                    default:
                        keyColor := row.Style = "doc" ? theme["keyDoc"] : theme["keyBound"]
                        ; center the key font's line on the description's
                        keyY := y + (measurer.Size(row.Text, "body").H - measurer.Size(row.Key, "key").H) // 2
                        this.AddText(g, theme, "key", keyColor, "x" x " y" keyY " w" col.KeyWidth, row.Key)
                        this.AddText(g, theme, "body", theme["description"], "x" (x + col.KeyWidth + pad) " y" y, row.Text)
                }
                y += size.H
            }
            bottom := Max(bottom, y)
            x += col.Width + pad * 2
        }

        y := bottom + spacing
        if legendLine != "" && theme["legend"] = "bottom" {
            line := this.AddText(g, theme, "body", theme["footer"], "xm y" y, legendLine)
            line.GetPos(, , , &lh)
            y += lh + spacing
        }
        this.AddText(g, theme, "footer", theme["footer"], "xm y" y, footer)
        if pinned
            this.AddText(g, theme, "footer", theme["pinned"], "x+24 yp", "📌 pinned")
        if warningCount
            this.AddText(g, theme, "footer", theme["warning"], "x+24 yp", "⚠ " warningCount " warning" (warningCount = 1 ? "" : "s"))

        this.Round(g.Hwnd, theme)
        g.Show("NA Hide AutoSize")
        WinGetPos(, , &w, &h, g)
        area := this.WorkArea()
        g.Show("NA x" (area.Left + (area.Right - area.Left - w) // 2) " y" (area.Top + (area.Bottom - area.Top - h) // 2))
        WinSetTransparent(theme["opacity"], g)
        return g
    }

    static AddText(g, theme, kind, color, options, text) {
        font := this.Font(theme, kind)
        g.SetFont("norm " font[1] " c" color, font[2])
        return g.AddText(options " +0x80", text)
    }

    ; Work area of the monitor containing the active window's center (primary if none).
    static WorkArea() {
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "A")
            cx := wx + ww // 2, cy := wy + wh // 2
            loop MonitorGetCount() {
                MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
                if cx >= left && cx < right && cy >= top && cy < bottom
                    return {Left: left, Top: top, Right: right, Bottom: bottom}
            }
        }
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
        return {Left: left, Top: top, Right: right, Bottom: bottom}
    }

    static Round(hwnd, theme) {
        static DWMWA_WINDOW_CORNER_PREFERENCE := 33, DWMWA_BORDER_COLOR := 34
        preference := theme["rounded"] ? 2 : 1  ; DWMWCP_ROUND : DWMWCP_DONOTROUND
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_WINDOW_CORNER_PREFERENCE, "Int*", preference, "UInt", 4)
        rgb := Integer("0x" theme["border"])
        bgr := ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_BORDER_COLOR, "UInt*", bgr, "UInt", 4)
    }
}
