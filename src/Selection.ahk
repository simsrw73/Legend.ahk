#Requires AutoHotkey v2.0

; The selection bar of one overlay window and the rows it can sit on. Bodies register
; each row's bar rectangle and the controls to recolor; Select moves the one bar and
; recolors only the rows whose state changed, repainting just those rows.
class LegendSelection {
    __New(gui, color) {
        this.Gui := gui
        ; created before any row, so the rows' transparent controls draw over it. A Text
        ; control, not a Progress: a Progress created at size 0 and moved later draws a border.
        this.Bar := gui.AddText("x0 y0 w0 h0 Background" color)
        this.Bar.Visible := false
        this.Rows := []
        this.Index := 0
        this.LastChanged := []
    }

    ; rect: {X, Y, W, H} of the bar on this row; recolors: [{Ctrl, Normal, Selected}].
    Add(rect, recolors) {
        this.Rows.Push({Rect: rect, Recolors: recolors})
        return this.Rows.Length
    }

    ; An invisible spacer at the furthest corner any bar reaches, so AutoSize always
    ; makes room for it and moving the selection never resizes the window.
    Reserve() {
        if !this.Rows.Length
            return
        right := 0, bottom := 0
        for row in this.Rows
            right := Max(right, row.Rect.X + row.Rect.W), bottom := Max(bottom, row.Rect.Y + row.Rect.H)
        this.Gui.AddText("x" (right - 1) " y" (bottom - 1) " w1 h1")
    }

    ; index: 1-based over the registered rows; 0 hides the bar.
    Select(index) {
        static WM_SETREDRAW := 0x0B, RDW_REPAINT := 0x185   ; INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW
        changed := []
        if index != this.Index {
            if this.Index
                changed.Push(this.Index)
            if index
                changed.Push(index)
        }
        this.LastChanged := changed
        if !changed.Length
            return
        hwnd := this.Gui.Hwnd
        visible := DllCall("IsWindowVisible", "Ptr", hwnd)   ; WM_SETREDRAW TRUE would show a hidden window
        if visible
            DllCall("SendMessageW", "Ptr", hwnd, "UInt", WM_SETREDRAW, "Ptr", 0, "Ptr", 0)
        try {
            for rowIndex in changed {
                selected := rowIndex = index
                for recolor in this.Rows[rowIndex].Recolors
                    recolor.Ctrl.SetFont("c" (selected ? recolor.Selected : recolor.Normal))
            }
            if index {
                rect := this.Rows[index].Rect
                this.Bar.Move(rect.X, rect.Y, rect.W, rect.H)
                this.Bar.Visible := true
            } else
                this.Bar.Visible := false
        } finally {
            if visible
                DllCall("SendMessageW", "Ptr", hwnd, "UInt", WM_SETREDRAW, "Ptr", 1, "Ptr", 0)
        }
        this.Index := index
        if !visible
            return
        area := Buffer(16)
        for rowIndex in changed {
            rect := this.Rows[rowIndex].Rect
            NumPut("Int", rect.X, "Int", rect.Y, "Int", rect.X + rect.W, "Int", rect.Y + rect.H, area)
            DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", area, "Ptr", 0, "UInt", RDW_REPAINT)
        }
    }
}
