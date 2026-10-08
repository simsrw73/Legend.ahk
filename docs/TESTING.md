# Testing

## Test Strategy

Run `pwsh -NoProfile -File tests/Run-Tests.ps1` from PowerShell. It runs the AutoHotkey tests, validates entry points and host fixtures, checks explicit locals, and verifies documentation examples and links. The 2026-10-08 baseline is 229 passed, 0 failed; 44 documentation code blocks and all links passed. Exercise session methods directly rather than sending keystrokes, opening menus, or clicking on the user's screen. Add characterization tests for observed behavior before production changes; keep structural and behavioral changes separate.

Effect sketch for the window-switcher picker lifetime: `Legend.OpenPicker` → `LegendPickerSession.Open` → picker source → `LegendWindowSwitcher.Source` (icons and rows) → highlight (peek) → draw → pick/cancel or failed open → `LegendPickerSession.CloseNow` (capture and renderer) → deferred switcher `Pick`/`Cancel` (peek and icons, only on normal outcomes). `tests/Switcher.Tests.ahk` runs the real source, icon APIs, picker session, and row renderer against private native fixture windows. Only window enumeration, peek/activation, and overlay placement are substituted; every fixture window and overlay stays off screen without activation. `GetIconInfo` checks real icon validity and releases its temporary bitmaps. Bitmap validity checks fetch the actual `BITMAP` structure with `GetObjectW`, rather than querying its size.

Deferred callbacks can run before the next caller assertion after `Close` or a pick. Use `Legend.RunDeferred()` to ensure completion, then assert cleanup outcomes; observe teardown state inside the callback instead of assuming it is still pending. If a test must inspect the pending callback, preserve and hold the caller's `Critical` state as `Sessions_DeferredPick` does. The switcher pick/cancel tests passed 50 forced-timer runs with a yield before the completion assertions.

## Safety Net Map

| Module | Pinned behaviors | Test files | Gaps |
|---|---|---|---|
| Window-switcher picker lifetime (`src/WindowSwitcher.ahk`, `src/PickerSession.ahk`, `Legend.ahk`) | Executable icons are owned and destroyed on pick/cancel; borrowed window/class icons survive cleanup; actual row-image copies are released with the renderer. Source errors destroy acquired owned icons and rethrow the original exception; failed open releases the session/capture without cancellation. Scope reload destroys old source icons before extraction while old row copies remain usable, then replaces the overlay with valid filtered rows/images. | `tests/Switcher.Tests.ahk` (pick/cancel, borrowed window/class, failed-source cleanup, original error propagation, scope reload); `tests/Controller.Tests.ahk` (source failure, deferred callback teardown) | Actual window enumeration and virtual-desktop membership; real peek restoration and cleanup after failed highlight. These gaps are **not pinned** and are off-limits to changes until covered. |

## Characterization Backlog

- [x] Capture real icon ownership and destruction through switcher source and close/failure paths, without affecting the user's active windows (owner: agent; priority: high).
- [x] Pin icon ownership and row rendering across a switcher scope reload (owner: agent; priority: medium).
- [ ] Pin peek state and cleanup if a highlight callback fails after raising a window (owner: agent; priority: medium).

## CI Gates

- [x] Full runner green on 2026-10-08: 229 passed, 0 failed; validations, 44 doc blocks and links passed (owner: agent; priority: high).
- [ ] Keep the full runner green before and after each subsequent production change; pin any gap in the Safety Net Map before touching it (owner: agent; priority: high).
