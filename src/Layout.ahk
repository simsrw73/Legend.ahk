#Requires AutoHotkey v2.0

; Packs rows into columns no taller than maxHeight, and columns into screens of at
; most maxColumns and (when maxWidth > 0) no wider than maxWidth, counting
; columnGap between columns. measure(row) returns {KeyW, TextW, H} (KeyW 0 for rows
; without a key). Returns at least one screen; each screen is an array of columns
; {Rows, KeyWidth, Width, Height}. A heading or group row never ends a column. A
; column wider than maxWidth on its own still gets a screen.
class LegendLayout {
    static Paginate(rows, measure, maxHeight, maxColumns, gap := 16, maxWidth := 0, columnGap := 0) {
        pages := {Screens: [], Columns: [], Width: 0}
        col := {Items: [], Height: 0}
        for row in rows {
            size := measure(row)
            if col.Items.Length && col.Height + size.H > maxHeight {
                carry := []
                while col.Items.Length > 1 && col.Items[col.Items.Length].Row.Kind != "entry" {
                    item := col.Items.Pop()
                    col.Height -= item.Size.H
                    carry.InsertAt(1, item)
                }
                this.AddColumn(pages, this.Finish(col, gap), maxColumns, maxWidth, columnGap)
                col := {Items: carry, Height: 0}
                for item in carry
                    col.Height += item.Size.H
            }
            col.Items.Push({Row: row, Size: size})
            col.Height += size.H
        }
        if col.Items.Length
            this.AddColumn(pages, this.Finish(col, gap), maxColumns, maxWidth, columnGap)
        if pages.Columns.Length || !pages.Screens.Length
            pages.Screens.Push(pages.Columns)
        return pages.Screens
    }

    ; Adds a finished column to the current screen, first starting a new screen if
    ; the column would make it too wide; ends the screen once it has maxColumns.
    static AddColumn(pages, column, maxColumns, maxWidth, columnGap) {
        if maxWidth > 0 && pages.Columns.Length && pages.Width + columnGap + column.Width > maxWidth
            pages.Screens.Push(pages.Columns), pages.Columns := [], pages.Width := 0
        pages.Width += (pages.Columns.Length ? columnGap : 0) + column.Width
        pages.Columns.Push(column)
        if pages.Columns.Length = maxColumns
            pages.Screens.Push(pages.Columns), pages.Columns := [], pages.Width := 0
    }

    static Finish(col, gap) {
        keyWidth := 0
        for item in col.Items
            keyWidth := Max(keyWidth, item.Size.KeyW)
        width := 0, rows := []
        for item in col.Items {
            width := Max(width, item.Size.KeyW ? keyWidth + gap + item.Size.TextW : item.Size.TextW)
            rows.Push(item.Row)
        }
        return {Rows: rows, KeyWidth: keyWidth, Width: width, Height: col.Height}
    }
}
