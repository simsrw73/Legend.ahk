#Requires AutoHotkey v2.0

ContinuedArrow(input) =>
    (missing := input)

DelimitedArrow(input) => (
    missing := input
)

OperatorArrow(input) => input
    + (missing := 1)

TrailingOperatorArrow(input) => input +
    (missing := 1)

TrailingMinusArrow(input) => input -
    (missing := 1)

ContinuedBump(input) => input++
    + (missing := 1)

ContinuedLower(input) => input--
    - (missing := 1)

class ArrowAccessor {
    Shorthand => (shorthandMissing := 1)

    ContinuedShorthand =>
        (continuedMissing := 1)

    Value {
        get => (getterMissing := 1)
        set => (setterMissing := value)
    }
}
