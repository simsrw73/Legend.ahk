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
