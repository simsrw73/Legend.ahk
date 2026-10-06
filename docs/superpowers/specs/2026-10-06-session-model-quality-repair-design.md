# Session-model quality repair design

## Purpose

Replace Legend's implicit multi-mode controller state with explicit session
objects, while also completing the outstanding quality-boundary, local-scope,
and durable-write repairs. The public Legend API keeps its behavior; internal
controller fields and tests may change freely.

## Goals

1. `Legend` owns at most one current interaction session.
2. Each session owns and closes every resource it creates: input hook, focus
   timer, GUI, measurer, navigation or picker state, and deferred callbacks.
3. Reference overlay, chord, and picker behavior remain unchanged.
4. Window peeking receives rendering context explicitly, rather than reading
   controller globals.
5. Every local introduced in an AHK function is explicitly declared and a
   source-level test enforces that convention.
6. Sticky letter persistence never truncates the live file before a complete
   replacement is available.

## Architecture

### Public facade

`Legend` remains the static public entry point for registration (`Page`,
`Bind`, `Chord`, `Picker`, and `WindowSwitcher`) and startup. It has one
`Session` property. Opening an interaction closes the current session before
constructing and opening the requested one. Public handlers delegate to the
current session when its mode accepts them.

The facade owns configuration, registry data, and the one deferred callback
slot. It does not own session GUI, measurement, hooks, timers, or transient
navigation state.

### Sessions

Three focused internal classes own their respective flows:

- `LegendReferenceSession`: page selection, navigation, hotkey-visible
  watching, warning tooltip, and reference-overlay rendering.
- `LegendChordSession`: chord navigation, delayed display, chord timeout,
  keyboard hook, and focus timer.
- `LegendPickerSession`: picker source loading, queued keys, highlighting,
  keyboard hook, focus timer, and deferred pick/cancel callbacks.

Each session exposes `Open()`, `Close()`, and only the event methods its
controller path needs. `Close()` is idempotent and clears every resource it
owns. A small session rendering helper owns the GUI/measurer pair and provides
the existing layout-key rendering optimization. It is passed explicitly to
sessions rather than stored as global controller state.

No generic session framework or inheritance hierarchy is introduced. The
three modes have distinct interaction rules; direct classes avoid moving their
branching into a new abstraction.

### Explicit render context

The `Legend.WindowSwitcher` facade supplies the window switcher with a
zero-argument render-context callback. It returns the current outline color
and overlay HWND. `LegendWindowSwitcher` forwards those values to
`LegendPeek.Show(win, color, below)`. `LegendPeek` then depends only on its
arguments and `LegendWindows`.

### Atomic sticky-letter writes

`LegendLetterStore.Write` writes the complete text to a uniquely named
temporary file next to the destination, closes it, then replaces the
destination. On a write or replacement error it cleans up the temporary file
and leaves the existing mapping unchanged. A failed first write may leave no
mapping file, which is the same safe behavior as before.

### Explicit-local enforcement

`tests/Check-Locals.ps1` parses AHK function bodies conservatively. For each
function it collects names introduced by assignments, loop variables, `catch
as`, and ByRef/output parameters, then verifies they appear in that function's
`local` declaration. It reports file, function, and missing names and exits
nonzero. `Run-Tests.ps1` invokes it before the generated-host compile check.

Production files declare the remaining locals the checker identifies. The
test suite contains a deliberately invalid AHK fixture to prove the checker
fails for the intended reason.

## Data and control flow

`Legend.Open`, `Legend.OpenChord`, and `Legend.OpenPicker` call a single
replacement operation: close the current session, construct the new session,
store it, and open it. A session closes itself through a facade callback that
first clears `Legend.Session` and then releases its own resources, preventing
old timers or hook callbacks from operating on a replacement session.

Render context flows outward from the active session's renderer to the window
switcher, never inward from `LegendPeek` to the controller.

## Error handling

- Failure while opening a session closes that partially opened session and
  restores `Legend.Session` to empty before rethrowing.
- Deferred picker callbacks run only after their picker session has closed and
  outside `Critical`, preserving the existing timing guarantee.
- Atomic-write failures are contained: they preserve the old letter file and
  do not make opening the overlay fail.

## Tests and validation

Add focused tests for session replacement and idempotent teardown, render
context forwarding, atomic-write failure preservation, and the explicit-local
checker fixture. Retain existing controller, picker, chord, race, syntax,
documentation-code-block, and link checks. The full validation command is:

```powershell
pwsh -NoProfile -File tests/Run-Tests.ps1
```

## Non-goals

- No user-visible shortcut, layout, picker, or theme changes.
- No backward-compatibility layer for direct reads of prior controller internals.
- No general dependency-injection container or session base class.
