# Session-Model Quality Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the implicit multi-mode controller with explicit sessions and complete the rendering-boundary, atomic-write, and local-scope repairs without changing user-visible behavior.

**Architecture:** Keep `Legend` as the public static facade and registration owner. Move each live interaction into a focused session that owns its hook, timers, renderer, and transient state; pass dependencies through explicit callbacks. Keep shared rendering as a small direct helper, not a session superclass.

**Tech Stack:** AutoHotkey v2, PowerShell 7, native Win32 calls, repository test harness.

## Global Constraints

- Preserve all documented user-facing shortcuts, picker behavior, themes, and layouts.
- Do not retain compatibility shims for direct reads of old internal controller fields.
- Every AHK function must explicitly declare its introduced locals.
- Run `pwsh -NoProfile -File tests/Run-Tests.ps1` before reporting completion.

---

### Task 1: Enforce explicit local declarations

**Files:**
- Create: `tests/Check-Locals.ps1`
- Create: `tests/fixtures/locals/missing-local.ahk`
- Modify: `tests/Run-Tests.ps1:30-60`
- Modify: `src/WindowSwitcher.ahk:45-205`

**Interfaces:**
- Produces `tests/Check-Locals.ps1`, which exits `0` only if every introduced function-local name occurs in that function's `local` declaration.
- Consumes all `Legend.ahk` and `src/*.ahk` production sources plus an optional fixture path.

- [ ] **Step 1: Write failing checker coverage**

  Add a `missing-local.ahk` fixture containing one function with `local declared` and an undeclared assignment `missing := 1`. Add a PowerShell test invocation in `Run-Tests.ps1` that runs `Check-Locals.ps1` over the fixture and fails unless its output names `missing-local.ahk`, the function, and `missing`.

- [ ] **Step 2: Run the checker coverage and verify RED**

  Run:

  ```powershell
  pwsh -NoProfile -File tests/Check-Locals.ps1 tests/fixtures/locals/missing-local.ahk
  ```

  Expected: the command is absent or does not identify the undeclared `missing` local.

- [ ] **Step 3: Implement the conservative checker**

  Parse function bodies, strip comments and quoted strings, collect names from assignments, compound assignments, loop variables, `catch ... as`, and ByRef/output parameters. Parse that function's `local` declaration and report each missing name as `<file>:<function>: undeclared local <name>`. Return nonzero if any are missing.

- [ ] **Step 4: Declare production locals and wire the test runner**

  Add the missing declarations in `LegendWindowSwitcher.Source`, `DetailOf`, `IconOf`, `LegendPeek.Show`, and `LegendPeek.Frame`. Invoke the checker from `Run-Tests.ps1` before the generated-host validation; separately assert that the invalid fixture fails and the production source succeeds.

- [ ] **Step 5: Verify GREEN**

  Run:

  ```powershell
  pwsh -NoProfile -File tests/Check-Locals.ps1 Legend.ahk src
  pwsh -NoProfile -File tests/Run-Tests.ps1
  ```

  Expected: production-source check succeeds; the fixture is rejected; all existing tests remain green.

### Task 2: Make sticky-letter persistence atomic

**Files:**
- Modify: `src/Letters.ahk:56-77`
- Modify: `tests/Letters.Tests.ahk`

**Interfaces:**
- `LegendLetterStore.Write(path, pages, letters, saved)` either replaces `path` with complete UTF-8 content or leaves its prior content untouched.

- [ ] **Step 1: Write a failing preservation test**

  Create an existing mapping file, force the replacement operation to fail through a narrow file-operation seam, call `LegendLetterStore.Write`, and assert the original mapping text remains intact and no temporary file remains.

- [ ] **Step 2: Run the focused test and verify RED**

  Run:

  ```powershell
  & AutoHotkey64.exe /ErrorStdOut tests/Legend.Tests.ahk
  ```

  Expected: the new test fails because the current direct `FileOpen(path, "w")` truncates the live file.

- [ ] **Step 3: Implement same-directory replacement**

  Add narrowly scoped file-operation methods on `LegendLetterStore` for test substitution. Write the complete mapping to a unique sibling temporary path, close it, then replace the destination using an overwrite move. Use `try/finally` to close an open stream and delete the temporary file after a failed write or replacement. Do not alter `path` until the temporary content is complete.

- [ ] **Step 4: Verify GREEN**

  Run the focused AHK suite and confirm both normal persistence and failure preservation tests pass.

### Task 3: Decouple peek rendering from global controller state

**Files:**
- Modify: `src/WindowSwitcher.ahk:8-25, 139-205`
- Modify: `Legend.ahk:499-506`
- Modify: `tests/Windows.Tests.ahk` or `tests/Controller.Tests.ahk`

**Interfaces:**
- `LegendWindowSwitcher(hotkey, options)` accepts `RenderContext: () => {Outline, Below}`.
- `LegendPeek.Show(win, outline, below)` does not read `Legend`.

- [ ] **Step 1: Write failing render-context tests**

  Construct a switcher with a callback that returns a distinctive outline and HWND; verify highlight forwarding supplies both values to the peek boundary. Add a contract test that `LegendPeek.Show` uses passed values and does not require `Legend.Theme` or `Legend.Gui`.

- [ ] **Step 2: Run focused tests and verify RED**

  Run the AHK test suite containing the new tests. Expected: failure because `RenderContext` is ignored and `LegendPeek.Show` accepts only the window.

- [ ] **Step 3: Implement explicit context propagation**

  Store an optional `RenderContext` callback in `LegendWindowSwitcher`; its highlight callback obtains the context and passes `item.Data`, `context.Outline`, and `context.Below` to `LegendPeek.Show`. Change `LegendPeek.Show` to take those parameters directly. Have `Legend.WindowSwitcher` supply the current renderer context.

- [ ] **Step 4: Verify GREEN**

  Run the focused test suite; confirm the existing outline-placement and restore tests still pass.

### Task 4: Extract explicit interaction sessions

**Files:**
- Create: `src/Session.ahk`
- Create: `src/ReferenceSession.ahk`
- Create: `src/ChordSession.ahk`
- Create: `src/PickerSession.ahk`
- Modify: `Legend.ahk`
- Modify: `tests/Controller.Tests.ahk`
- Modify: `tests/Legend.Tests.ahk`
- Modify: `tests/race/ChordRace.ahk`
- Modify: `tests/race/PickerRace.ahk`

**Interfaces:**
- `LegendSessionRenderer` owns `{Gui, Measurer, DrawnLayout}` and exposes `Render(layoutKey, build, selectedIndex)` and `Close()`.
- Each interaction exposes `Open()`, `Close()`, and event methods appropriate to its mode.
- `Legend.Session` is either `""` or the sole active session; `Legend.ReplaceSession(session)` closes the current session before opening the replacement.

- [ ] **Step 1: Write session lifecycle tests**

  Add tests that opening a picker closes an active chord, opening a reference session closes a picker, and calling `Close()` twice stops resources only once without throwing. Assert stale callbacks do not affect a replacement session.

- [ ] **Step 2: Run focused controller tests and verify RED**

  Run:

  ```powershell
  & AutoHotkey64.exe /ErrorStdOut tests/Legend.Tests.ahk
  ```

  Expected: tests fail because `Legend.Session` and `ReplaceSession` do not exist.

- [ ] **Step 3: Extract shared renderer and reference session**

  Move the GUI/measurer/layout-key rendering behavior into `LegendSessionRenderer`. Move reference navigation, warning tooltip, visible-mode watcher, focus timer, and overlay drawing into `LegendReferenceSession`. Keep hotkey registration in the facade and route handlers to the active reference session.

- [ ] **Step 4: Verify the reference session**

  Run controller, navigator, letters, overlay, and selection tests. Expected: all pass without direct dependency on `Legend.Gui`, `Legend.Measurer`, `Legend.Nav`, or `Legend.Visible`.

- [ ] **Step 5: Extract chord and picker sessions**

  Move chord hook/timer/key dispatch into `LegendChordSession` and picker hook/queue/highlight/deferred dispatch into `LegendPickerSession`. Give each an idempotent `Close()` that stops its own hook and timers and closes its renderer. Preserve `Critical` sections and deferred picker callback timing.

- [ ] **Step 6: Route facade transitions through one replacement path**

  Replace `Visible`, `ChordState`, `PickerState`, `Gui`, `Measurer`, `Nav`, watcher, and focus-timer cross-mode checks with `Legend.Session` type checks and `Legend.ReplaceSession`. Update facade callbacks, race tests, and controller tests to use the session boundary rather than former implementation fields.

- [ ] **Step 7: Verify session integration**

  Run all AHK test suites and both race scripts. Expected: no stranded overlays, no missed chord cleanup, and no picker key backlog regressions.

### Task 5: Full regression and documentation validation

**Files:**
- Modify only if code signatures or references require it: `README.md`, `docs/**/*.md`, `CLAUDE.md`

- [ ] **Step 1: Review public API documentation**

  Confirm every documented API retains its prior behavior. Do not document internal session classes unless intentionally public.

- [ ] **Step 2: Run the complete test command**

  Run:

  ```powershell
  pwsh -NoProfile -File tests/Run-Tests.ps1
  ```

  Expected: all test assertions, syntax validation, generated-host validation, local-scope checker, documentation code-block checks, and link checks pass.

- [ ] **Step 3: Review the final diff**

  Run:

  ```powershell
  git diff --check
  git diff --stat
  git status --short
  ```

  Expected: no whitespace errors, only intended files changed, and no generated artifacts.
