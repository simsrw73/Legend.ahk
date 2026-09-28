#Requires AutoHotkey v2.0

; One chord menu item: a run (Action) or a submenu (Items).
class LegendChordItem {
    __New(key, label, action := "", items := "", options := "") {
        this.Key := key
        this.Label := label
        this.Action := action
        this.Items := items
        this.Pattern := LegendChordMatch.Parse(key)
        opt := name => IsObject(options) && options.HasOwnProp(name) ? options.%name% : ""
        this.If := opt("If"), this.Status := opt("Status"), this.Hint := opt("Hint")
    }

    IsMenu => IsObject(this.Items)

    Enabled() {
        if !IsObject(this.If)
            return true
        fn := this.If
        return fn()
    }

    ; true / false for items with a Status function, otherwise "".
    StatusNow() {
        if !IsObject(this.Status)
            return ""
        fn := this.Status
        return fn() ? true : false
    }

    ; Strings are sent; functions get the pressed key if they take a parameter.
    Run(keyName) {
        action := this.Action
        if !IsObject(action)
            return Send(action)
        if HasProp(action, "MaxParams") && (action.MaxParams >= 1 || action.IsVariadic)
            return action(keyName)
        return action()
    }
}

class LegendChord {
    __New(hotkey, title, items, options := "") {
        this.Hotkey := hotkey
        this.Title := title
        this.Items := items
        this.Match := IsObject(options) && options.HasOwnProp("Match") ? options.Match : ""
        this.Reference := IsObject(options) && options.HasOwnProp("Reference") ? options.Reference : true
    }
}

class LegendChords {
    ; The first item whose pattern matches key and whose If holds, or "".
    static Find(items, key) {
        for item in items
            if LegendChordMatch.Matches(item.Pattern, key) && item.Enabled()
                return item
        return ""
    }

    ; Items to show: If holds, and only the first such item per key pattern.
    static Visible(items) {
        seen := Map(), out := []
        for item in items {
            if !item.Enabled()
                continue
            id := item.Pattern.Display("text")
            if seen.Has(id)
                continue
            seen[id] := true
            out.Push(item)
        }
        return out
    }
}

; Tracks modifiers during a chord. Modifiers already down when the chord opened
; (the trigger's) are ignored until released, so Win+Space then z is plain z.
class LegendChordKeys {
    __New(heldVks := []) {
        this.Held := Map(), this.Stale := Map()
        for vk in heldVks
            if LegendKeyWatch.ModVks.Has(vk)
                this.Held[vk] := LegendKeyWatch.ModVks[vk], this.Stale[vk] := true
    }

    ; Returns true when vk is a modifier (tracked here, never a chord key).
    Down(vk) {
        if !LegendKeyWatch.ModVks.Has(vk)
            return false
        this.Held[vk] := LegendKeyWatch.ModVks[vk]
        return true
    }

    Up(vk) {
        if this.Held.Has(vk)
            this.Held.Delete(vk)
        if this.Stale.Has(vk)
            this.Stale.Delete(vk)
    }

    ; The pressed key with the modifiers pressed since the chord opened.
    Key(keyName) {
        mods := []
        for vk, name in this.Held
            if !this.Stale.Has(vk)
                mods.Push(name)
        return LegendKeyName.FromParts(mods, keyName)
    }
}
