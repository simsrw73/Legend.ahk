# Technical Debt

## Debt Ledger

| Item | Location | Type | Risk | Effort | Priority | Owner | Status |
|---|---|---|---|---|---|---|---|
| Partial source failure retains a real extracted `HICON` after picker teardown because switcher cleanup runs only in pick/cancel callbacks. Native-handle tests confirm retention; explicit `FreeIcons` destroys the handle. Fix failure cleanup separately from characterization. | `src/WindowSwitcher.ahk:46–49,113–140`; `src/PickerSession.ahk:31–37,179–204`; `tests/Switcher.Tests.ahk` (`Switcher_FailedSourceRetainsIcons`) | resource lifetime / behavior | Confirmed live owned handle retained after partial open | medium | high | agent | open; real-handle behavior pinned |
| Real icon extraction/destruction and scope reload ordering need direct tests at the switcher source. | `src/WindowSwitcher.ahk:46–73,89–118`; `tests/Switcher.Tests.ahk` | test gap | Cleanup regression | medium | medium | agent | closed; executable extraction, borrowed window/class icons, native row-image copies, and scope reload characterized |
| Highlight failure after a peek raises a window lacks a cleanup characterization test. | `src/WindowSwitcher.ahk:142–149`; `src/PickerSession.ahk:38–46` | test gap | Window presentation may not be restored on failure | medium | medium | agent | open; unpinned |

## Smell Inventory

| Smell | Location | Refactoring | Status |
|---|---|---|---|

No structure changes in Phase 1; assess in later phases.

## Sprout / Wrap Register

None introduced in Phase 1.

## Debt Budget & Broken-Windows Policy

To be decided in Phase 6.

## Adopted Conventions

To be decided in Phase 2. Phase 1 practice: characterize observed behavior before changing it; do not silently fix a quirk in a safety-net test.
