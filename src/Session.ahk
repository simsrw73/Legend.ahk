#Requires AutoHotkey v2.0

; The rendering resources belong to one interaction, never to the facade.
class LegendSessionRenderer {
    __New() {
        this.Gui := "", this.Measurer := "", this.DrawnLayout := ""
        this.BaseTheme := "", this.Theme := "", this.ThemeWarnings := []
        this.Closed := false
    }

    LoadTheme() {
        local loaded
        loaded := LegendTheme.Load(Legend.Opt("Theme"), Legend.Opt("Themes"))
        this.BaseTheme := loaded.Values
        this.ThemeWarnings := loaded.Warnings
    }

    Measure(theme) {
        if this.Measurer
            this.Measurer.Destroy(), this.Measurer := ""
        this.Theme := theme
        this.Measurer := LegendMeasurer(theme)
    }

    ApplyDisplay(density, style) {
        local area, aspect, maxHeight, maxWidth, measurer, theme
        theme := LegendTheme.Resolve(this.BaseTheme, density, style)
        this.Measure(theme)
        measurer := this.Measurer
        area := LegendOverlay.WorkArea()
        maxHeight := (area.Bottom - area.Top) * theme["maxHeightPercent"] // 100 - LegendOverlay.Chrome(theme, measurer)
        maxWidth := (area.Right - area.Left) * theme["maxWidthPercent"] // 100 - theme["padding"] * 2
        aspect := theme["aspect"] = "monitor" ? (area.Right - area.Left) / Max(1, area.Bottom - area.Top) : theme["aspect"]
        return (rows, kind) => theme[kind "Growth"] = "vertical"
            ? LegendLayout.Paginate(rows, measurer, maxHeight, theme["maxColumns"], theme["padding"], maxWidth, theme["columnGap"])
            : LegendLayout.Proportional(rows, measurer, maxHeight, theme["maxColumns"], theme["padding"], maxWidth,
                theme["columnGap"], aspect)
    }

    ; A cursor-only change moves the selection without rebuilding the window.
    Render(layoutKey, build, selectedIndex) {
        local previousOverlay
        if this.Closed
            return
        if this.Gui && this.DrawnLayout == layoutKey {
            this.Gui.Selection.Select(selectedIndex)
            return
        }
        previousOverlay := this.Gui
        this.Gui := build()
        this.DrawnLayout := layoutKey
        if previousOverlay
            previousOverlay.Destroy()
    }

    DrawNavigator(nav, warnings) {
        local col, footer, legendLine, mods, row, theme, view
        theme := this.Theme, view := nav.View, mods := []
        for col in view.Columns
            for row in col.Rows
                mods.Push(row.Mods*)
        legendLine := theme["legend"] = "off" ? "" : LegendKeyName.LegendLine(mods, theme["keyStyle"])
        footer := nav.Footer("tab " theme["keyStyle"], "= " theme["density"])
        this.Render("nav|" nav.LayoutKey "|" footer "|" legendLine "|" warnings,
            () => LegendOverlay.Show(view, theme, this.Measurer, footer, legendLine, nav.Pinned, warnings), nav.SelectedIndex)
    }

    Close() {
        local overlay, measurer
        if this.Closed
            return
        this.Closed := true
        overlay := this.Gui, measurer := this.Measurer
        this.Gui := "", this.Measurer := ""
        this.DrawnLayout := ""
        try {
            if overlay
                overlay.Destroy()
        } finally {
            if measurer
                measurer.Destroy()
        }
    }
}
