# Testing

## Test Strategy

Run `pwsh -NoProfile -File tests/Run-Tests.ps1` from PowerShell. It runs the AutoHotkey tests, validates entry points and host fixtures, checks explicit locals, and verifies documentation examples and links. The 2026-10-08 baseline is 225 passed, 0 failed; 44 documentation code blocks and all links passed. Exercise session methods directly rather than sending keystrokes, opening menus, or clicking on the user's screen. Add characterization tests for observed behavior before production changes; keep structural and behavioral changes separate.

Effect sketch for the window-switcher picker lifetime: `Legend.OpenPicker` → `LegendPickerSession.Open` → picker source → `LegendWindowSwitcher.Source` (icons and rows) → highlight (peek) → draw → pick/cancel or failed open → `LegendPickerSession.CloseNow` (capture and renderer) → deferred switcher `Pick`/`Cancel` (peek and icons, only on normal outcomes). Test points are the switcher's recorded icons, peek calls and activation order, together with the detached session and released capture. Tests replace the source and peek at existing object seams and use a harmless zero-valued icon handle; they do not call `DestroyIcon` on a real icon.

Deferred callbacks can run before the next caller assertion after `Close` or a pick. Use `Legend.RunDeferred()` to ensure completion, then assert cleanup outcomes; observe teardown state inside the callback instead of assuming it is still pending. If a test must inspect the pending callback, preserve and hold the caller's `Critical` state as `Sessions_DeferredPick` does. The switcher pick/cancel tests passed 50 forced-timer runs with a yield before the completion assertions.

## Safety Net Map

| Module | Pinned behaviors | Test files | Gaps |
|---|---|---|---|
| Window-switcher picker lifetime (`src/WindowSwitcher.ahk`, `src/PickerSession.ahk`, `Legend.ahk`) | Normal cancel defers release of recorded icons and restores peek; normal pick defers release and clears peek before activation; failed source open currently leaves recorded icons and does not run cancel; failed source releases picker capture, detaches session and closes renderer. | `tests/Controller.Tests.ahk` (`Switcher_CancelReleasesResources`, `Switcher_PickReleasesResources`, `Switcher_FailedSourceRetainsIcons`, `Sessions_PickerSourceFailure`, `Sessions_DeferredPick`) | Real Win32 icon extraction/destruction and actual window enumeration; scope reload ownership and render order; peek state after failed highlight; no assertion of what a real leaked handle does. These gaps are **not pinned** and are off-limits to structural or behavioral changes until covered. |

## Characterization Backlog

- [ ] Capture real icon ownership and destruction through switcher source and close/failure paths, without affecting the user's active windows (owner: agent; priority: high).
- [ ] Pin icon ownership and row rendering across a switcher scope reload (owner: agent; priority: medium).
- [ ] Pin peek state and cleanup if a highlight callback fails after raising a window (owner: agent; priority: medium).

## CI Gates

- [x] Full runner green on 2026-10-08: 225 passed, 0 failed; validations, 44 doc blocks and links passed (owner: agent; priority: high).
- [ ] Keep the full runner green before and after each subsequent production change; pin any gap in the Safety Net Map before touching it (owner: agent; priority: high).
