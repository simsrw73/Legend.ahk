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
            textW := text.W + (row.Status != "" ? this.Size("● ", "body").W : 0)
            return {KeyW: key.W, TextW: textW, H: Max(key.H, text.H) + spacing}
        }
        size := this.Size(row.Text, row.Kind)
        return {KeyW: 0, TextW: size.W, H: size.H + spacing * (row.Kind = "heading" ? 2 : 1)}
    }

    Size(text, kind) {
        cacheId := kind "`n" text
        if !this.Cache.Has(cacheId) {
            font := LegendOverlay.Font(this.Theme, kind)
            this.Gui.SetFont("norm " font[1], font[2])
            ctrl := this.Gui.AddText("+0x80", text = "" ? " " : text)
            ctrl.GetPos(, , &width, &height)
            this.Cache[cacheId] := {W: width, H: height}
        }
        return this.Cache[cacheId]
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
        gutter := theme["padding"], spacing := theme["rowSpacing"]
        ; WS_EX_NOACTIVATE; -DPIScale keeps coordinates in the measurer's physical pixels
        overlay := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
        overlay.BackColor := theme["background"]
        overlay.MarginX := gutter, overlay.MarginY := gutter

        title := this.AddText(overlay, theme, "title", theme["title"], "xm ym", StrUpper(view.Title))
        title.GetPos(, &titleY, , &titleHeight)
        top := titleY + titleHeight + spacing * 2
        if legendLine != "" && theme["legend"] = "top" {
            line := this.AddText(overlay, theme, "body", theme["footer"], "xm y" top, legendLine)
            line.GetPos(, , , &lineHeight)
            top += lineHeight + spacing * 2
        }

        colX := gutter, bottom := top
        for col in view.Columns {
            rowY := top
            for row in col.Rows {
                size := measurer(row)
                switch row.Kind {
                    case "heading":
                        this.AddText(overlay, theme, "heading", theme["category"], "x" colX " y" (rowY + spacing), row.Text)
                    case "group":
                        this.AddText(overlay, theme, "group", theme["group"], "x" colX " y" rowY, row.Text)
                    default:
                        keyColor := row.Style = "doc" ? theme["keyDoc"] : theme["keyBound"]
                        ; center the key font's line on the description's
                        keyY := rowY + (measurer.Size(row.Text, "body").H - measurer.Size(row.Key, "key").H) // 2
                        this.AddText(overlay, theme, "key", keyColor, "x" colX " y" keyY " w" col.KeyWidth, row.Key)
                        textX := colX + col.KeyWidth + gutter
                        if row.Status != "" {
                            this.AddText(overlay, theme, "body", row.Status ? theme["indicatorOn"] : theme["indicatorOff"], "x" textX " y" rowY, "●")
                            textX += measurer.Size("● ", "body").W
                        }
                        this.AddText(overlay, theme, "body", theme["description"], "x" textX " y" rowY, row.Text)
                }
                rowY += size.H
            }
            bottom := Max(bottom, rowY)
            colX += col.Width + theme["columnGap"]
        }

        rowY := bottom + spacing
        if legendLine != "" && theme["legend"] = "bottom" {
            line := this.AddText(overlay, theme, "body", theme["footer"], "xm y" rowY, legendLine)
            line.GetPos(, , , &lineHeight)
            rowY += lineHeight + spacing
        }
        this.AddText(overlay, theme, "footer", theme["footer"], "xm y" rowY, footer)
        if pinned
            this.AddText(overlay, theme, "footer", theme["pinned"], "x+24 yp", "📌 pinned")
        if warningCount
            this.AddText(overlay, theme, "footer", theme["warning"], "x+24 yp", "⚠ " warningCount " warning" (warningCount = 1 ? "" : "s"))

        this.Round(overlay.Hwnd, theme)
        overlay.Show("NA Hide AutoSize")
        WinGetPos(, , &width, &height, overlay)
        area := this.WorkArea()
        overlay.Show("NA x" (area.Left + (area.Right - area.Left - width) // 2) " y" (area.Top + (area.Bottom - area.Top - height) // 2))
        WinSetTransparent(theme["opacity"], overlay)
        return overlay
    }

    ; Height Show adds around the columns: padding, title, legend line (when the
    ; theme shows one) and footer, measured with the theme's fonts.
    static Chrome(theme, measurer) {
        spacing := theme["rowSpacing"]
        height := theme["padding"] * 2 + measurer.Size("X", "title").H + spacing * 2
            + spacing + measurer.Size("X", "footer").H
        if theme["legend"] != "off"
            height += measurer.Size("X", "body").H + spacing * 2
        return height
    }

    static AddText(g, theme, kind, color, options, text) {
        font := this.Font(theme, kind)
        g.SetFont("norm " font[1] " c" color, font[2])
        return g.AddText(options " +0x80", text)
    }

    ; Work area of the monitor containing the active window's center (primary if none).
    static WorkArea() {
        try {
            WinGetPos(&winX, &winY, &winW, &winH, "A")
            centerX := winX + winW // 2, centerY := winY + winH // 2
            loop MonitorGetCount() {
                MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
                if centerX >= left && centerX < right && centerY >= top && centerY < bottom
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
        colorRgb := Integer("0x" theme["border"])
        colorBgr := ((colorRgb & 0xFF) << 16) | (colorRgb & 0xFF00) | ((colorRgb >> 16) & 0xFF)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_BORDER_COLOR, "UInt*", colorBgr, "UInt", 4)
    }
}
