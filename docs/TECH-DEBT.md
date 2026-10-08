# Technical Debt

## Debt Ledger

| Item | Location | Type | Risk | Effort | Priority | Owner | Status |
|---|---|---|---|---|---|---|---|
| Partial source construction previously retained extracted `HICON`s on error. `Source` now destroys acquired owned icons and rethrows the original exception; borrowed handles survive and failed open does not invoke normal cancellation. | `src/WindowSwitcher.ahk:46–78,121–148`; `tests/Switcher.Tests.ahk` (`Switcher_FailedSourceReleasesIcons`, `Switcher_SourceFailurePreservesError`) | resource lifetime / behavior | Owned icon retention after partial open | medium | high | agent | closed; native cleanup regression and original-error propagation verified |
| Real icon extraction/destruction and scope reload ordering lacked direct tests at the switcher source. | `src/WindowSwitcher.ahk:46–78,94–126`; `tests/Switcher.Tests.ahk` | test gap | Cleanup regression | medium | medium | agent | closed; executable extraction, borrowed window/class icons, native row-image copies, and scope reload characterized |
| Highlight failure after a peek raises a window lacks a cleanup characterization test. | `src/WindowSwitcher.ahk:150–157`; `src/PickerSession.ahk:38–46` | test gap | Window presentation may not be restored on failure | medium | medium | agent | open; unpinned |

## Smell Inventory

| Smell | Location | Refactoring | Owner | Priority | Status |
|---|---|---|---|---|---|
| 1. Handle and record names require mental mapping | `src/WindowSwitcher.ahk`, `Source` | Rename local `active` to `activeHwnd` and `win` to `window` | agent | medium | done in Phase 2 |
| 2. Saved thread state named `was` | `Legend.ahk`, `Serialized` / `RunDeferred` | Rename local to `previousCritical`; retain save/restore semantics | agent | medium | done in Phase 2 |
| 3. Page-relative selected row named `index` | `src/PickerSession.ahk`, `Draw` | Rename local to `selectedRowIndex` | agent | medium | done in Phase 2 |
| 4. Queued input and processing result have generic names | `src/PickerSession.ahk`, `DrainKeysNow` | Rename locals to `queuedKeys` / `outcome`; retain the atomic handoff and dispatch order | agent | medium | done in Phase 2 |
| 5. Previous overlay named `old` | `src/Session.ahk`, `Render` | Rename local to `previousOverlay`; retain build-before-destroy ordering | agent | medium | done in Phase 2 |
| 6. Native selector/type/timeout values require comment lookup | `src/WindowSwitcher.ahk`, `IconOf` | Replace numeric selectors, class offsets, image type and timeout with symbolic constants using identical values | agent | medium | done in Phase 2 |
| 7. Source combines monitor lookup, scope filtering and row construction | `src/WindowSwitcher.ahk`, `Source` | Extract cohesive steps in Phase 3 only after monitor-specific membership/lookup behavior is characterized; keep icon cleanup around the full source transaction | agent | medium | deferred to Phase 3; monitor gap blocks extraction |
| 8. Picker lifecycle and state handoffs are dense | `src/PickerSession.ahk`, `Open` / `CloseNow` / `DrainKeysNow` | Extract named lifecycle steps in Phase 3 after highlight/teardown failure ordering is pinned; preserve callback and resource order | agent | medium | deferred to Phase 3; unpinned failure paths untouched |
| 9. Suppression boundaries lack characterized failure policies | `src/WindowSwitcher.ahk`, `IconOf`; `Legend.ahk`, `ReplaceSessionNow` | Characterize unavailable/closed-window icon fallback and secondary teardown failures, then document the distinct policies before considering narrower catches; retain the primary opening error | agent | high | deferred; audit risk, not a proven defect |
| 10. Render-context tests include forwarding-only/mock-echo assertions | `tests/Controller.Tests.ahk`, `Switcher_RenderContext` / `Switcher_DefaultRenderContext` / `Controller_SwitcherRenderContext` | Replace forwarding probes with native color, placement, changing-context and empty-selection behavior coverage; remove the probes rather than re-pin implementation details | agent | medium | deferred; consumer-visible integration coverage first |

### Phase 2 Review

Scope: pinned switcher/picker lifetime and shared rendering/deferred-callback helpers. The maintainer approved fixes 1–6 and deferred 7–10. Scores are subjective review judgments, not CI measurements.

| Discipline | Before | After |
|---|---:|---:|
| Naming | 7 | 9 |
| Functions | 7 | 7 |
| Comments/formatting | 8 | 8 |
| Error handling | 7 | 7 |
| Tests | 8 | 8 |
| General smells | 8 | 9 |

Overall review score: **7.5 → 8.0 / 10**. The remaining function, error-policy and test-integration gaps have explicit fixes in rows 7–10. Preserve the meaningful ownership/timing comments; neither numeric line limits nor a swarm of tiny helpers is a goal.

## Sprout / Wrap Register

None introduced in Phase 1.

## Debt Budget & Broken-Windows Policy

To be decided in Phase 6.

## Adopted Conventions

The maintainer adopted these Phase 2 conventions:

- Preserve public names and signatures. Use descriptive `camelCase` locals that distinguish handles, records, row positions and saved state. Explicitly declare introduced locals; never shadow AHK built-ins.
- Use established Win32 constant names and explicit units such as `_MS`. Name protocol values without changing their values, lookup order or timeouts.
- Preserve AHK/Win32 absence conventions (`""`, `0`) and their existing guards. Do not introduce null-object classes or change absence into an exception as a readability edit.
- Cleanup catches rethrow the original exception. Optional fallbacks need an explicit, characterized failure policy; narrowing catches, changing error wrappers or surfacing secondary errors requires a separate behavior change.
- Keep functions cohesive rather than enforcing an arbitrary line limit. Preserve timing-sensitive compound handoffs; extract helpers only when the name hides meaningful complexity.
- Readability scores remain advisory. The full deterministic runner is the merge gate; no model-score CI check or manual 8+ threshold was adopted.

Phase 1 practice remains: characterize observed behavior before changing it; do not silently fix a quirk in a safety-net test.
