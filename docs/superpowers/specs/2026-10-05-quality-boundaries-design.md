# Quality-boundary repair design

## Purpose

Repair two review findings without changing Legend's user-visible behavior:

1. make the repository's explicit-local convention mechanically enforceable;
2. remove `LegendPeek`'s direct dependency on the global `Legend` controller.

## Explicit-local enforcement

`tests/Run-Tests.ps1` will retain its generated `#Warn` host test as a compile
and compatibility check. A separate source-level check will inspect each AHK
function, collect names introduced by assignments, loop variables, `catch as`,
and output parameters, and require every collected name to be present in that
function's `local` declaration. It will report the source file, function, and
undeclared names, and exit nonzero.

The check is intentionally conservative and uses the same set of assignment
patterns as the existing generated-host test. Existing production functions
will be updated to declare the names it identifies.

## Peek rendering boundary

`LegendPeek.Show` will take all rendering state it needs as arguments:
the candidate window, outline color, and HWND the outline must sit below.
`LegendWindowSwitcher` will accept a render-context callback supplied by the
`Legend.WindowSwitcher` facade. Its highlight callback will call that callback
and pass the returned color and HWND to `LegendPeek.Show`.

This leaves `LegendPeek` dependent only on its explicit parameters and
`LegendWindows`; it no longer reads `Legend.Theme` or `Legend.Gui`. The facade
remains the canonical owner of current overlay state.

## Tests and validation

Add a failing fixture that omits a required explicit local and assert the
source check rejects it. Add a focused test for the render-context callback and
for `LegendPeek.Show`'s explicit parameter contract. Then run the full
`tests/Run-Tests.ps1` suite, including documentation and link validation.

## Non-goals

This does not change picker navigation, window selection, theme resolution,
or outline placement behavior. It does not introduce a general dependency
injection framework.
