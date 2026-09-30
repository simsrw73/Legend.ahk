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

        this.Place(overlay, theme)
        return overlay
    }

    ; Rounds the overlay, centers it on the active monitor and shows it without focus.
    static Place(overlay, theme) {
        this.Round(overlay.Hwnd, theme)
        overlay.Show("NA Hide AutoSize")
        WinSetTransparent(theme["opacity"], overlay)   ; before it's visible: no opaque flash
        WinGetPos(, , &width, &height, overlay)
        area := this.WorkArea()
        overlay.Show("NA x" (area.Left + (area.Right - area.Left - width) // 2) " y" (area.Top + (area.Bottom - area.Top - height) // 2))
    }

    ; Moves the selection to row index (1-based on this screen; 0 = none) of an overlay
    ; drawn by ShowPicker, recoloring only the rows that change.
    static SelectPickerRow(overlay, theme, index) {
        static WM_SETREDRAW := 0x0B, RDW_REPAINT := 0x185   ; INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW
        changed := []
        ; batch the recolors and the bar move into one paint of just the changed rows
        DllCall("SendMessageW", "Ptr", overlay.Hwnd, "UInt", WM_SETREDRAW, "Ptr", 0, "Ptr", 0)
        try {
            for rowIndex, row in overlay.PickerRows {
                selected := rowIndex = index
                if selected = row.Selected
                    continue
                row.Selected := selected
                row.Text.SetFont("c" (selected ? theme["selectionText"] : theme["description"]))
                row.Detail.SetFont("c" (selected ? theme["selectionText"] : theme["footer"]))
                changed.Push(row.Y)
            }
            bar := overlay.PickerBar
            if index {
                bar.Move(, overlay.PickerRows[index].Y)
                bar.Visible := true
            } else
                bar.Visible := false
        } finally
            DllCall("SendMessageW", "Ptr", overlay.Hwnd, "UInt", WM_SETREDRAW, "Ptr", 1, "Ptr", 0)
        bar.GetPos(&barX, , &barW, &barH)
        rect := Buffer(16)
        for rowY in changed {
            NumPut("Int", barX, "Int", rowY, "Int", barX + barW, "Int", rowY + barH, rect)
            DllCall("RedrawWindow", "Ptr", overlay.Hwnd, "Ptr", rect, "Ptr", 0, "UInt", RDW_REPAINT)
        }
    }

    static IconSize(theme) => theme["density"] = "compact" ? 16 : 20

    static PickerRowHeight(theme, measurer) => Max(this.IconSize(theme), measurer.Size("X", "body").H) + theme["rowSpacing"]

    ; Draws a picker. view: {Title, Rows: [{Text, Detail, Icon, Letter, Selected}], Empty}.
    ; A row is letter · icon · text · detail; the selected row sits on a selection-colored
    ; bar (a Progress control added first, so the transparent cells draw over it).
    static ShowPicker(view, theme, measurer, footer, maxWidth) {
        gutter := theme["padding"], gap := theme["rowSpacing"]
        overlay := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
        overlay.BackColor := theme["background"]
        overlay.MarginX := gutter, overlay.MarginY := gutter
        title := this.AddText(overlay, theme, "title", theme["title"], "xm ym", view.Title)
        title.GetPos(, &titleY, , &titleHeight)
        rowY := titleY + titleHeight + gap * 2

        rowH := this.PickerRowHeight(theme, measurer), iconW := this.IconSize(theme)
        letterW := measurer.Size("W", "key").W
        textW := 0, detailW := 0
        for row in view.Rows {
            textW := Max(textW, measurer.Size(row.Text, "body").W)
            detailW := Max(detailW, measurer.Size(row.Detail, "body").W)
        }
        textW := Max(60, Min(textW, maxWidth - (gap * 5 + iconW + letterW + detailW)))
        rowW := gap * 5 + iconW + letterW + textW + detailW
        rowX := gutter - gap   ; content lines up with the title

        if !view.Rows.Length {
            this.AddText(overlay, theme, "body", theme["footer"], "xm y" rowY, view.Empty)
            rowY += rowH
        }
        ; the selection bar comes first so the transparent cells draw over it; moving the
        ; cursor later just moves it (SelectPickerRow)
        bar := overlay.AddProgress("x" rowX " y" rowY " w" rowW " h" rowH " Background" theme["selection"] " Disabled")
        bar.Visible := false
        drawn := []
        for row in view.Rows {
            textColor := row.Selected ? theme["selectionText"] : theme["description"]
            detailColor := row.Selected ? theme["selectionText"] : theme["footer"]
            if row.Selected {
                bar.Move(, rowY)
                bar.Visible := true
            }
            cellX := rowX + gap
            this.AddText(overlay, theme, "key", theme["keyBound"], "x" cellX " y" rowY " w" letterW " h" rowH " BackgroundTrans +0x200", row.Letter)
            cellX += letterW + gap
            if row.Icon
                overlay.AddPicture("x" cellX " y" (rowY + (rowH - iconW) // 2) " w" iconW " h" iconW " BackgroundTrans", "HICON:*" row.Icon)
            cellX += iconW + gap
            textCtrl := this.AddText(overlay, theme, "body", textColor, "x" cellX " y" rowY " w" textW " h" rowH " BackgroundTrans +0x4200", row.Text)
            cellX += textW + gap
            detailCtrl := this.AddText(overlay, theme, "body", detailColor, "x" cellX " y" rowY " w" detailW " h" rowH " BackgroundTrans +0x202", row.Detail)
            drawn.Push({Text: textCtrl, Detail: detailCtrl, Y: rowY, Selected: row.Selected})
            rowY += rowH
        }
        overlay.PickerBar := bar, overlay.PickerRows := drawn
        this.AddText(overlay, theme, "footer", theme["footer"], "xm y" (rowY + gap), footer)
        this.Place(overlay, theme)
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
