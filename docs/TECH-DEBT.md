# Technical Debt

## Debt Ledger

| Item | Location | Type | Risk | Effort | Priority | Owner | Status |
|---|---|---|---|---|---|---|---|
| Partial source construction previously retained extracted `HICON`s on error. `Source` now destroys acquired owned icons and rethrows the original exception; borrowed handles survive and failed open does not invoke normal cancellation. | `src/WindowSwitcher.ahk:46–78,118–145`; `tests/Switcher.Tests.ahk` (`Switcher_FailedSourceReleasesIcons`, `Switcher_SourceFailurePreservesError`) | resource lifetime / behavior | Owned icon retention after partial open | medium | high | agent | closed; native cleanup regression and original-error propagation verified |
| Real icon extraction/destruction and scope reload ordering lacked direct tests at the switcher source. | `src/WindowSwitcher.ahk:46–78,94–123`; `tests/Switcher.Tests.ahk` | test gap | Cleanup regression | medium | medium | agent | closed; executable extraction, borrowed window/class icons, native row-image copies, and scope reload characterized |
| Highlight failure after a peek raises a window lacks a cleanup characterization test. | `src/WindowSwitcher.ahk:147–154`; `src/PickerSession.ahk:38–46` | test gap | Window presentation may not be restored on failure | medium | medium | agent | open; unpinned |

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
