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
        callback := this.If
        return callback()
    }

    ; true / false for items with a Status function, otherwise "".
    StatusNow() {
        if !IsObject(this.Status)
            return ""
        callback := this.Status
        return callback() ? true : false
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
        seen := Map(), result := []
        for item in items {
            if !item.Enabled()
                continue
            patternId := item.Pattern.Display("text")
            if seen.Has(patternId)
                continue
            seen[patternId] := true
            result.Push(item)
        }
        return result
    }
}

; Tracks modifiers during a chord. Modifiers already down when the chord opened
; (the trigger's) are ignored until released, so Win+Space then z is plain z.
; The trigger's own key, if still held when the chord opened, is ignored until it
; is released (so its auto-repeat doesn't count as a chord key).
class LegendChordKeys {
    __New(heldVks := [], triggerName := "", triggerHeld := false) {
        this.Held := Map(), this.Stale := Map()
        for heldVk in heldVks
            if LegendKeyWatch.ModVks.Has(heldVk)
                this.Held[heldVk] := LegendKeyWatch.ModVks[heldVk], this.Stale[heldVk] := true
        this.TriggerName := triggerName != "" ? LegendKeyName.NormalizeName(triggerName) : ""
        this.TriggerHeld := triggerHeld && this.TriggerName != ""
    }

    IsTriggerRepeat(keyName) => this.TriggerHeld && LegendKeyName.NormalizeName(keyName) == this.TriggerName

    ; Alt or Win held around a swallowed key: releasing it alone would open the
    ; Start menu or a menu bar, so the controller sends a mask key first.
    static NeedsMask(key) {
        for modName in key.Mods
            if modName = "Win" || modName = "Alt"
                return true
        return false
    }

    ; Returns true when vk is a modifier (tracked here, never a chord key).
    Down(vk) {
        if !LegendKeyWatch.ModVks.Has(vk)
            return false
        this.Held[vk] := LegendKeyWatch.ModVks[vk]
        return true
    }

    Up(vk, keyName := "") {
        if this.Held.Has(vk)
            this.Held.Delete(vk)
        if this.Stale.Has(vk)
            this.Stale.Delete(vk)
        if keyName != "" && LegendKeyName.NormalizeName(keyName) == this.TriggerName
            this.TriggerHeld := false
    }

    ; The pressed key with the modifiers pressed since the chord opened, or with every
    ; held modifier when withStale is true.
    Key(keyName, withStale := false) {
        mods := []
        for heldVk, name in this.Held
            if withStale || !this.Stale.Has(heldVk)
                mods.Push(name)
        return LegendKeyName.FromParts(mods, keyName)
    }
}
