#Requires AutoHotkey v2.0

Selection_Window() {
    g := Gui("-Caption +ToolWindow -DPIScale +E0x08000000")
    sel := g.Selection := LegendSelection(g, "45475A")
    loop 3 {
        rowY := 10 + (A_Index - 1) * 20
        label := g.AddText("x10 y" rowY " w50 h20 BackgroundTrans", "row " A_Index)
        sel.Add({X: 5, Y: rowY, W: 60 + A_Index * 20, H: 20}, [{Ctrl: label, Normal: "CDD6F4", Selected: "FFFFFF"}])
    }
    return g
}

Selection_Changed(sel) {
    text := ""
    for rowIndex in sel.LastChanged
        text .= (A_Index > 1 ? "," : "") rowIndex
    return text
}

T.Test("Selection: the bar follows the selected row and only changed rows recolor", Selection_Moves)
Selection_Moves() {
    g := Selection_Window()
    sel := g.Selection
    sel.Reserve()
    g.Show("NA x-3000 y-3000 AutoSize")
    try {
        sel.Select(1)
        sel.Bar.GetPos(&barX, &barY, &barW, &barH)
        T.Eq(barX " " barY " " barW " " barH, "5 10 80 20")
        T.Eq(Selection_Changed(sel), "1")
        sel.Select(3)
        T.Eq(Selection_Changed(sel), "1,3")
        sel.Bar.GetPos(, &barY, &barW)
        T.Eq(barY " " barW, "50 120")
        sel.Select(3)
        T.Eq(Selection_Changed(sel), "", "no change, nothing recolored")
        sel.Select(0)
        T.True(!sel.Bar.Visible, "0 hides the bar")
    } finally
        g.Destroy()
}

T.Test("Selection: Reserve makes room for the widest bar", Selection_Reserve)
Selection_Reserve() {
    g := Selection_Window()
    g.Selection.Reserve()
    g.Show("NA x-3000 y-3000 AutoSize")
    try {
        g.GetClientPos(, , &clientW)
        T.True(clientW >= 5 + 120, "client " clientW " fits the widest bar")
    } finally
        g.Destroy()
}

T.Test("Selection: selecting on a hidden window keeps it hidden", Selection_Hidden)
Selection_Hidden() {
    g := Selection_Window()
    try {
        g.Selection.Select(2)
        T.True(!DllCall("IsWindowVisible", "Ptr", g.Hwnd), "WM_SETREDRAW would have shown it")
        T.Eq(g.Selection.Index, 2)
    } finally
        g.Destroy()
}

T.Test("Selection: the Reserve spacer never paints over a bar", Selection_SpacerClear)
Selection_SpacerClear() {
    g := Selection_Window()
    sel := g.Selection
    sel.Reserve()
    try {
        sel.Spacer.GetPos(&spacerX, &spacerY, &spacerW, &spacerH)
        for row in sel.Rows {
            overlapsX := spacerX < row.Rect.X + row.Rect.W && spacerX + spacerW > row.Rect.X
            overlapsY := spacerY < row.Rect.Y + row.Rect.H && spacerY + spacerH > row.Rect.Y
            T.True(!(overlapsX && overlapsY), "spacer overlaps row " A_Index)
        }
        T.Eq(spacerX + spacerW, 5 + 120, "still reaches the widest bar's right edge")
    } finally
        g.Destroy()
}

T.Test("Selection: moving never pauses painting on the whole window", Selection_NoTopLevelRedrawPause)
Selection_NoTopLevelRedrawPause() {
    static WM_SETREDRAW := 0x0B
    g := Selection_Window()
    sel := g.Selection
    sel.Reserve()
    g.Show("NA x-3000 y-3000 AutoSize")
    paused := []
    watch := (wParam, lParam, msg, hwnd) => (hwnd = g.Hwnd ? paused.Push(wParam) : "")
    OnMessage(WM_SETREDRAW, watch)
    try {
        sel.Select(1), sel.Select(3), sel.Select(2)
        T.Eq(paused.Length, 0, "WM_SETREDRAW FALSE on a top-level window clears WS_VISIBLE, so DWM can drop it for a frame")
    } finally {
        OnMessage(WM_SETREDRAW, watch, 0)
        g.Destroy()
    }
}

T.Test("Selection: an out-of-range index throws before changing anything", Selection_OutOfRange)
Selection_OutOfRange() {
    g := Selection_Window()
    sel := g.Selection
    try {
        sel.Select(2)
        T.Throws(() => sel.Select(9), "past the last row")
        T.Throws(() => sel.Select(-1), "negative")
        T.Eq(sel.Index, 2)
        T.Eq(Selection_Changed(sel), "2", "nothing recolored by the failed calls")
        sel.Bar.GetPos(, &barY)
        T.Eq(barY, 30)
    } finally
        g.Destroy()
}
