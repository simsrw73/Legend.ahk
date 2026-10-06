#Requires AutoHotkey v2.0

Compound() {
    count //= 2
    mask &= 1
    shifted <<= 1
}

LoopValue() {
    for , value in []
        break
}

CatchValue() {
    try throw Error()
    catch as err
        return
}

OutputValue() {
    local reference
    RegExMatch("", "", &found)
    Output(&first)
    reference := &target
}

Initializer() {
    local declared := (missing := 1)
}

Inline() { missing := 1 }
Arrow() => (missing := 1)

class Accessor {
    Value {
        get {
            missing := 1
        }
    }
}
