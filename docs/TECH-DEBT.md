# Technical Debt

## Debt Ledger

| Item | Location | Type | Risk | Effort | Priority | Owner | Status |
|---|---|---|---|---|---|---|---|
| Failed source open can leave switcher-recorded icons because switcher cleanup runs only in pick/cancel callbacks; the characterization test pins this current behavior, not a proven real-handle leak. Fix separately after real-handle ownership is characterized. | `src/WindowSwitcher.ahk:46–49,113–140`; `src/PickerSession.ahk:31–37,179–204` | resource lifetime / behavior | Potential resource retention after partial open | medium | high | agent | open; current behavior pinned |
| Real icon extraction/destruction and scope reload ordering lack a direct test at the switcher source. | `src/WindowSwitcher.ahk:46–73,89–118` | test gap | Cleanup regression may go unnoticed | medium | medium | agent | open; unpinned |
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
