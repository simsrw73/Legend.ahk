#Requires AutoHotkey v2.0

; Packs rows into columns no taller than maxHeight, and columns into screens of at
; most maxColumns. measure(row) returns {KeyW, TextW, H} (KeyW 0 for rows without a
; key). Returns at least one screen; each screen is an array of columns
; {Rows, KeyWidth, Width, Height}. A heading or group row never ends a column.
class LegendLayout {
    static Paginate(rows, measure, maxHeight, maxColumns, gap := 16) {
        screens := [], columns := []
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
                columns.Push(this.Finish(col, gap))
                if columns.Length = maxColumns
                    screens.Push(columns), columns := []
                col := {Items: carry, Height: 0}
                for item in carry
                    col.Height += item.Size.H
            }
            col.Items.Push({Row: row, Size: size})
            col.Height += size.H
        }
        if col.Items.Length
            columns.Push(this.Finish(col, gap))
        if columns.Length || !screens.Length
            screens.Push(columns)
        return screens
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
