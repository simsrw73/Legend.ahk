#Requires AutoHotkey v2.0

Declared(input, &output) {
    local count := 0, mask, shifted, value, err, found, text, declared, missing
    static cached := 0
    count //= 2
    mask &= 1
    shifted <<= 1
    for , value in []
        break
    try throw Error()
    catch as err
        return
    RegExMatch("", "", &found)
    declared := (missing := 1)
    input := 1
    output := 1
    cached += 1
    text := "ignored := 1 ; {"
    ; ignoredComment := 1
    /*
    ignoredBlock := 1
    }
    */
}

Inline() { local declared := 1 }
Arrow(input) => input := 1

Flags(flags) {
    return flags & A_TickCount
}

CompactFlags(flags) {
    return flags&A_TickCount
}

AssignedFlags(flags) {
    local masked
    masked := flags & A_TickCount
    return masked
}

CommandOutputs() {
    local x, y
    MouseGetPos &x, &y
}

class Accessor {
    Value {
        get {
            local declared
            declared := 1
            return declared
        }
    }
}
