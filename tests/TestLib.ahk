#Requires AutoHotkey v2.0

; Minimal test helper. T.Test runs one test; T.Eq / T.True / T.Throws assert.
class T {
    static Passed := 0
    static Failed := 0

    static Test(name, fn) {
        try {
            fn()
            T.Passed += 1
            T.Out("ok   " name)
        } catch Error as e {
            T.Failed += 1
            T.Out("FAIL " name "`n     " e.Message " (line " e.Line ")")
        }
    }

    static Eq(actual, expected, label := "") {
        if !(actual == expected)
            throw Error((label != "" ? label ": " : "") "expected <" T.Show(expected) "> got <" T.Show(actual) ">", -1)
    }

    static True(value, label := "") {
        if !value
            throw Error("expected true" (label != "" ? ": " label : ""), -1)
    }

    static Throws(fn, label := "") {
        try
            fn()
        catch
            return
        throw Error("expected an error" (label != "" ? ": " label : ""), -1)
    }

    static Show(v) => IsObject(v) ? "<" Type(v) ">" : v
    static Out(line) => FileAppend(line "`n", "*", "UTF-8")

    static Finish() {
        T.Out(T.Passed " passed, " T.Failed " failed")
        ExitApp(T.Failed)
    }
}

Noop(*) => ""

; Deterministic stand-in for LegendMeasurer: 10 px per character, 20 px per row.
FakeMeasure(row) => {KeyW: row.Kind = "entry" ? StrLen(row.Key) * 10 : 0, TextW: StrLen(row.Text) * 10, H: 20}
