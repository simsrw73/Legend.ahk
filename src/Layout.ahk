#Requires AutoHotkey v2.0

; Packs rows into columns no taller than maxHeight, and columns into screens of at
; most maxColumns and (when maxWidth > 0) no wider than maxWidth, counting
; columnGap between columns. measure(row) returns {KeyW, TextW, H} (KeyW 0 for rows
; without a key). Returns at least one screen; each screen is an array of columns
; {Rows, KeyWidth, Width, Height}. A heading or group row never ends a column. A
; column wider than maxWidth on its own still gets a screen.
class LegendLayout {
    ; Vertical growth: fill each column to maxHeight, then start the next.
    static Paginate(rows, measure, maxHeight, maxColumns, gap := 16, maxWidth := 0, columnGap := 0) {
        local items, pages
        pages := {Screens: [], Columns: [], Width: 0}
        for items in this.Pack(this.Measured(rows, measure), maxHeight)
            this.AddColumn(pages, this.Finish(items, gap), maxColumns, maxWidth, columnGap)
        if pages.Columns.Length || !pages.Screens.Length
            pages.Screens.Push(pages.Columns)
        return pages.Screens
    }

    ; Proportional growth: balanced columns, as many as bring the overlay's width /
    ; height closest to aspect (the screen's), so it keeps roughly the screen's shape
    ; as it grows. A list no taller than half of maxHeight stays one column. maxHeight,
    ; maxWidth and maxColumns stay hard limits; content that can't fit one screen
    ; within them pages like Paginate.
    static Proportional(rows, measure, maxHeight, maxColumns, gap := 16, maxWidth := 0, columnGap := 0, aspect := 16 / 9) {
        local best, bestDistance, col, columns, distance, height, item, items, least, packed, total, width
        items := this.Measured(rows, measure)
        least := this.Pack(items, maxHeight).Length   ; columns the height cap needs
        total := 0
        for item in items
            total += item.Size.H
        if !items.Length || least > maxColumns || least = 1 && total <= maxHeight / 2
            return this.Paginate(rows, measure, maxHeight, maxColumns, gap, maxWidth, columnGap)
        best := "", bestDistance := ""
        loop maxColumns - least + 1 {
            columns := []
            for packed in this.Balanced(items, least + A_Index - 1, maxHeight)
                columns.Push(this.Finish(packed, gap))
            width := 0, height := 0
            for col in columns
                width += (A_Index > 1 ? columnGap : 0) + col.Width, height := Max(height, col.Height)
            if maxWidth > 0 && width > maxWidth
                break   ; more columns only get wider
            distance := Abs(Ln(width / Max(1, height) / aspect))
            if best = "" || distance < bestDistance
                best := columns, bestDistance := distance
        }
        return best != "" ? [best] : this.Paginate(rows, measure, maxHeight, maxColumns, gap, maxWidth, columnGap)
    }

    static Measured(rows, measure) {
        local items, row
        items := []
        for row in rows
            items.Push({Row: row, Size: measure(row)})
        return items
    }

    ; Splits items into at most count columns, as even in height as packing allows:
    ; the smallest column limit (up to maxHeight) that still needs no more columns.
    ; A limit up to 20% taller wins if more columns then start at a category heading.
    static Balanced(items, count, maxHeight) {
        local best, bestScore, high, item, limit, low, mid, packed, score, step
        low := 0, step := ""
        for item in items
            low := Max(low, item.Size.H), step := step = "" ? item.Size.H : Min(step, item.Size.H)
        high := maxHeight
        while low < high {
            mid := (low + high) // 2
            if this.Pack(items, mid).Length <= count
                high := mid
            else
                low := mid + 1
        }
        best := this.Pack(items, high), bestScore := this.CategoryStarts(best)
        limit := high
        while (limit += Max(1, step)) <= Min(maxHeight, high * 6 // 5) {
            packed := this.Pack(items, limit)
            if packed.Length <= count && (score := this.CategoryStarts(packed)) > bestScore
                best := packed, bestScore := score
        }
        return best
    }

    ; Columns after the first that open with a category heading.
    static CategoryStarts(columns) {
        local col, starts
        starts := 0
        for col in columns
            if A_Index > 1 && col[1].Row.Kind = "heading"
                starts += 1
        return starts
    }

    ; Packs items into columns no taller than limit. A heading or group row never ends
    ; a column: it moves to the next one with the rows it introduces.
    static Pack(items, limit) {
        local carry, col, columns, height, item, moved
        columns := [], col := [], height := 0
        for item in items {
            if col.Length && height + item.Size.H > limit {
                carry := []
                while col.Length > 1 && col[col.Length].Row.Kind != "entry" {
                    moved := col.Pop()
                    height -= moved.Size.H
                    carry.InsertAt(1, moved)
                }
                columns.Push(col)
                col := carry, height := 0
                for moved in carry
                    height += moved.Size.H
            }
            col.Push(item)
            height += item.Size.H
        }
        if col.Length
            columns.Push(col)
        return columns
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

    ; A column record from measured items: {Rows, KeyWidth, Width, Height}.
    static Finish(items, gap) {
        local height, item, keyWidth, rows, width
        keyWidth := 0, height := 0
        for item in items
            keyWidth := Max(keyWidth, item.Size.KeyW), height += item.Size.H
        width := 0, rows := []
        for item in items {
            width := Max(width, item.Size.KeyW ? keyWidth + gap + item.Size.TextW : item.Size.TextW)
            rows.Push(item.Row)
        }
        return {Rows: rows, KeyWidth: keyWidth, Width: width, Height: height}
    }
}
