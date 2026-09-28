#Requires AutoHotkey v2.0

; Classifies key presses seen by the overlay's pass-through InputHook. Modifier state is
; tracked from the hook's own down/up events (which arrive in order) rather than read
; with GetKeyState when the callback finally runs, which can be too late.
class LegendKeyWatch {
    static ModVks := Map(0x10, "Shift", 0xA0, "Shift", 0xA1, "Shift", 0x11, "Ctrl", 0xA2, "Ctrl",
        0xA3, "Ctrl", 0x12, "Alt", 0xA4, "Alt", 0xA5, "Alt", 0x5B, "Win", 0x5C, "Win")
    static IgnoredVks := Map(0xE8, 1, 0xFF, 1, 0x07, 1)  ; menu-mask and unassigned keys

    ; claimed: keys the overlay handles itself while open — single characters ("=")
    ; or combo ids ("Ctrl+N").
    __New(helpId, claimed := ["``"]) {
        this.HelpId := helpId
        this.Held := Map()
        this.Claimed := Map()
        for key in claimed
            this.Claimed[key] := true
    }

    ; vks: modifier keys already down when watching starts.
    Seed(vks) {
        for vk in vks
            if LegendKeyWatch.ModVks.Has(vk)
                this.Held[vk] := LegendKeyWatch.ModVks[vk]
    }

    ; Returns "combo" for a Ctrl/Alt/Win shortcut other than the help key, "letter" for a
    ; plain or shifted printable key the overlay never claims, otherwise "".
    Down(vk, keyName) {
        if LegendKeyWatch.ModVks.Has(vk) {
            this.Held[vk] := LegendKeyWatch.ModVks[vk]
            return ""
        }
        if LegendKeyWatch.IgnoredVks.Has(vk)
            return ""
        mods := [], combo := false
        for , held in this.Held {
            mods.Push(held)
            if held != "Shift"
                combo := true
        }
        if combo {
            id := LegendKeyName.FromParts(mods, keyName).Id
            return id == this.HelpId || this.Claimed.Has(id) ? "" : "combo"
        }
        return StrLen(keyName) = 1 && !this.Claimed.Has(keyName) ? "letter" : ""
    }

    Up(vk) {
        if this.Held.Has(vk)
            this.Held.Delete(vk)
    }
}
