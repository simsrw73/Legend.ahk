#Requires AutoHotkey v2.0

ContinuedArrow(input, &output) =>
    (input := 1, output := input)

DelimitedArrow(input) => (
    input := 1
)

OperatorArrow(input) => input
    + (input := 1)

TrailingOperatorArrow(input) => input +
    (input := 1)

FlagsArrow(input) => input
    & A_TickCount

StringArrow() => "ignored := 1 {"

class ArrowAccessor {
    Shorthand => this.Stored := 1

    ContinuedShorthand =>
        this.Stored := 1

    Value {
        get => this.Stored
        set => value := 1
    }
}
