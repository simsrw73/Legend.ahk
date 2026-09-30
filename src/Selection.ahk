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
        this.Spacer := ""
    }

    ; rect: {X, Y, W, H} of the bar on this row; recolors: [{Ctrl, Normal, Selected}].
    Add(rect, recolors) {
        this.Rows.Push({Rect: rect, Recolors: recolors})
        return this.Rows.Length
    }

    ; A 1x1 spacer at the right-most edge any bar reaches, so AutoSize always makes
    ; room for it and moving the selection never resizes the window. It sits at the
    ; top of the window, where no bar reaches (it would cut a notch into one).
    Reserve() {
        if !this.Rows.Length
            return
        right := 0
        for row in this.Rows
            right := Max(right, row.Rect.X + row.Rect.W)
        this.Spacer := this.Gui.AddText("x" (right - 1) " y0 w1 h1")
    }

    ; index: 1-based over the registered rows; 0 hides the bar. Recolors and the bar
    ; move only invalidate; nothing paints until the one RedrawWindow of the changed
    ; rows at the end, so the screen goes straight from the old picture to the new.
    ; (No WM_SETREDRAW: on a top-level window it clears WS_VISIBLE, and DWM can drop
    ; the whole overlay for a frame.)
    Select(index) {
        static RDW_REPAINT := 0x185   ; INVALIDATE | ERASE | ALLCHILDREN | UPDATENOW
        if !IsInteger(index) || index < 0 || index > this.Rows.Length
            throw ValueError("selection index " index " is not 0–" this.Rows.Length, -1)
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
        this.Index := index
        hwnd := this.Gui.Hwnd
        if !DllCall("IsWindowVisible", "Ptr", hwnd)
            return
        area := Buffer(16)
        for rowIndex in changed {
            rect := this.Rows[rowIndex].Rect
            NumPut("Int", rect.X, "Int", rect.Y, "Int", rect.X + rect.W, "Int", rect.Y + rect.H, area)
            DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", area, "Ptr", 0, "UInt", RDW_REPAINT)
        }
    }
}
