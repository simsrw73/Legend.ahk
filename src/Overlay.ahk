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

    ; A window with background, margins, a selection bar and the title. Returns
    ; {Gui, Top, Bottom}: bodies draw from Top and set Bottom.
    static Frame(theme, title) {
        overlay := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")   ; WS_EX_NOACTIVATE
        overlay.BackColor := theme["background"]
        overlay.MarginX := overlay.MarginY := theme["padding"]
        overlay.Selection := LegendSelection(overlay, theme["selection"])
        titleCtrl := this.AddText(overlay, theme, "title", theme["title"], "xm ym", title)
        titleCtrl.GetPos(, &titleY, , &titleHeight)
        return {Gui: overlay, Top: titleY + titleHeight + theme["rowSpacing"] * 2, Bottom: 0}
    }

    ; The footer (and Alt+/'s pinned and warning badges), then placement.
    static Finish(frame, theme, footer, pinned := false, warningCount := 0) {
        overlay := frame.Gui
        this.AddText(overlay, theme, "footer", theme["footer"], "xm y" (frame.Bottom + theme["rowSpacing"]), footer)
        if pinned
            this.AddText(overlay, theme, "footer", theme["pinned"], "x+24 yp", "📌 pinned")
        if warningCount
            overlay.WarningBadge := this.AddText(overlay, theme, "footer", theme["warning"], "x+24 yp +0x100", this.WarningBadgeText(warningCount))   ; SS_NOTIFY: hover
        this.Place(overlay, theme)
        return overlay
    }

    static WarningBadgeText(count) => "⚠ " count " warning" (count = 1 ? "" : "s") " · see Warnings"

    static Show(view, theme, measurer, footer, legendLine, pinned, warningCount) {
        frame := this.Frame(theme, StrUpper(view.Title))
        LegendTableBody.Draw(frame, view, theme, measurer, legendLine)
        return this.Finish(frame, theme, footer, pinned, warningCount)
    }

    ; view: {Title, Rows: [{Text, Detail, Icon, Letter}], Empty, SelectedIndex}.
    static ShowPicker(view, theme, measurer, footer, maxWidth) {
        frame := this.Frame(theme, view.Title)
        LegendListBody.Draw(frame, view, theme, measurer, maxWidth)
        return this.Finish(frame, theme, footer)
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

    static IconSize(theme) => theme["density"] = "compact" ? 16 : 20

    static PickerRowHeight(theme, measurer) => Max(this.IconSize(theme), measurer.Size("X", "body").H) + theme["rowSpacing"]

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

; Alt+/ and chord bodies: columns of headings, groups and key/description entries.
; Menu levels (view.SelectedIndex > 0) register their entries with the selection.
class LegendTableBody {
    static Draw(frame, view, theme, measurer, legendLine) {
        overlay := frame.Gui, gutter := theme["padding"], spacing := theme["rowSpacing"]
        top := frame.Top
        if legendLine != "" && theme["legend"] = "top" {
            line := LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "xm y" top, legendLine)
            line.GetPos(, , , &lineHeight)
            top += lineHeight + spacing * 2
        }
        selection := overlay.Selection
        selectable := view.HasOwnProp("SelectedIndex") && view.SelectedIndex > 0
        colX := gutter, bottom := top
        for col in view.Columns {
            rowY := top
            for row in col.Rows {
                size := measurer(row)
                switch row.Kind {
                    case "heading":
                        LegendOverlay.AddText(overlay, theme, "heading", theme["category"], "x" colX " y" (rowY + spacing), row.Text)
                    case "group":
                        LegendOverlay.AddText(overlay, theme, "group", theme["group"], "x" colX " y" rowY, row.Text)
                    default:
                        keyColor := row.Style = "doc" ? theme["keyDoc"] : theme["keyBound"]
                        ; center the key font's line on the description's
                        keyY := rowY + (measurer.Size(row.Text, "body").H - measurer.Size(row.Key, "key").H) // 2
                        LegendOverlay.AddText(overlay, theme, "key", keyColor, "x" colX " y" keyY " w" col.KeyWidth " BackgroundTrans", row.Key)
                        textX := colX + col.KeyWidth + gutter
                        if row.Status != "" {
                            LegendOverlay.AddText(overlay, theme, "body", row.Status ? theme["indicatorOn"] : theme["indicatorOff"], "x" textX " y" rowY " BackgroundTrans", "●")
                            textX += measurer.Size("● ", "body").W
                        }
                        textCtrl := LegendOverlay.AddText(overlay, theme, "body", theme["description"], "x" textX " y" rowY " BackgroundTrans", row.Text)
                        if selectable
                            selection.Add({X: colX - spacing, Y: rowY, W: col.Width + spacing * 2, H: size.H},
                                [{Ctrl: textCtrl, Normal: theme["description"], Selected: theme["selectionText"]}])
                }
                rowY += size.H
            }
            bottom := Max(bottom, rowY)
            colX += col.Width + theme["columnGap"]
        }
        if legendLine != "" && theme["legend"] = "bottom" {
            line := LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "xm y" (bottom + spacing), legendLine)
            line.GetPos(, , , &lineHeight)
            bottom += spacing + lineHeight
        }
        frame.Bottom := bottom
        if selectable {
            selection.Reserve()
            selection.Select(view.SelectedIndex)
        }
    }
}

; Picker body: letter · icon · text · detail rows, every row selectable.
class LegendListBody {
    static Draw(frame, view, theme, measurer, maxWidth) {
        overlay := frame.Gui, gutter := theme["padding"], gap := theme["rowSpacing"]
        rowY := frame.Top
        rowH := LegendOverlay.PickerRowHeight(theme, measurer), iconW := LegendOverlay.IconSize(theme)
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
            LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "xm y" rowY, view.Empty)
            rowY += rowH
        }
        selection := overlay.Selection
        for row in view.Rows {
            cellX := rowX + gap
            LegendOverlay.AddText(overlay, theme, "key", theme["keyBound"], "x" cellX " y" rowY " w" letterW " h" rowH " BackgroundTrans +0x200", row.Letter)
            cellX += letterW + gap
            if row.Icon
                overlay.AddPicture("x" cellX " y" (rowY + (rowH - iconW) // 2) " w" iconW " h" iconW " BackgroundTrans", "HICON:*" row.Icon)
            cellX += iconW + gap
            textCtrl := LegendOverlay.AddText(overlay, theme, "body", theme["description"], "x" cellX " y" rowY " w" textW " h" rowH " BackgroundTrans +0x4200", row.Text)
            cellX += textW + gap
            detailCtrl := LegendOverlay.AddText(overlay, theme, "body", theme["footer"], "x" cellX " y" rowY " w" detailW " h" rowH " BackgroundTrans +0x202", row.Detail)
            selection.Add({X: rowX, Y: rowY, W: rowW, H: rowH},
                [{Ctrl: textCtrl, Normal: theme["description"], Selected: theme["selectionText"]},
                 {Ctrl: detailCtrl, Normal: theme["footer"], Selected: theme["selectionText"]}])
            rowY += rowH
        }
        frame.Bottom := rowY
        selection.Reserve()
        selection.Select(view.HasOwnProp("SelectedIndex") ? view.SelectedIndex : 0)
    }
}
