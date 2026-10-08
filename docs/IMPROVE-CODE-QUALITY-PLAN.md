# Improve Code Quality Plan

## Context

Started 2026-10-08. Legend is a local AutoHotkey v2 / Win32 shortcut overlay, picker, and window switcher. The most serious failure is displaying misleading information to a user. It has an existing automated test suite (`pwsh -NoProfile -File tests/Run-Tests.ps1`) reported green by the maintainer. It is not yet in use by others, has no database or web framework, and makes no outbound API, payment, email, or queue calls. Initial intake limited the work to Phase 1; the maintainer subsequently approved Phase 2 for the pinned window-switcher/picker lifetime.

## Phase Status

| Phase | Skill | Status | Artifact | Date |
|---|---|---|---|---|
| 1 — Build the safety net | working-with-legacy-code | done | TESTING.md + TECH-DEBT.md (GATE) | 2026-10-08 |
| 2 — Make the code readable | clean-code | done | TECH-DEBT.md | 2026-10-08 |
| 3 — Apply named refactorings | refactoring-patterns | pending | TECH-DEBT.md | |
| 4 — Reduce complexity | software-design-philosophy | pending | TECH-DEBT.md | |
| 5 — Draw the architecture boundary | clean-architecture | pending | ARCHITECTURE.md | |
| 6 — Lock in the habits | pragmatic-programmer | pending | TECH-DEBT.md | |
| 7 — Make it survive production | release-it | deferred: no outbound dependencies or external users; revisit before release | RELIABILITY.md | 2026-10-08 |
| 8 — Size for real load | system-design | skipped: local desktop app; no server load or storage to size | ARCHITECTURE.md + RELIABILITY.md | 2026-10-08 |
| 9 — Get the data layer right | ddia-systems | skipped: no database or concurrent data layer | ARCHITECTURE.md | 2026-10-08 |
| Optional — Domain language | domain-driven-design | pending | ARCHITECTURE.md | |

Statuses: pending · in-progress · awaiting-evidence · done · deferred: <reason> · skipped: <reason>

## Key Decisions

| Date | Phase | Decision | Rationale |
|---|---|---|---|
| 2026-10-08 | Intake | Start at window-switcher picker lifetime; do Phase 1 only | Next area under consideration; no source changes until its behavior is pinned. |
| 2026-10-08 | Intake | Defer Phase 7; skip Phases 8–9 for current product shape | No users or outbound integrations, and no server or database. Reassess if those facts change. |
| 2026-10-08 | 1 | Pin failed-open resource retention as observed and log debt; do not change production behavior | A characterization test must describe the current code, even when it reveals a likely defect. |
| 2026-10-08 | 1 | Approve the Safety Net Map and debt ledger; mark Phase 1 complete for the pinned paths | Three new switcher tests pass; unpinned paths are explicit and off-limits until covered. |
| 2026-10-08 | 1 | Replace fake-icon tests with real native-handle characterization; leave production cleanup unchanged | Confirm partial-open retention and pin owned/borrowed icon lifetime plus scope-reload rendering before a separate cleanup fix. |
| 2026-10-08 | 1 follow-up | Release owned icons when source construction fails, then rethrow; do not run normal cancellation | Fix the characterized defect separately; preserve borrowed-icon ownership and the picker's failed-open callback contract. |
| 2026-10-08 | 2 entry | Enter the readability audit for the pinned switcher/picker lifetime | Maintainer approved Phase 2; keep behavior changes separate and unpinned paths untouched. |
| 2026-10-08 | 2 | Apply naming/constant fixes 1–6; defer structural, suppression-policy and test-integration findings 7–10 | Maintainer approved the ten-row inventory; change no public API, callback timing, ownership or behavior. |
| 2026-10-08 | 2 | Adopt repo-native naming, native constants, absence and cleanup conventions; keep scores advisory | Preserve AHK/Win32 contracts and deterministic test gates; do not introduce null objects, arbitrary function limits or model-score CI. |
| 2026-10-08 | 2 exit | Complete the approved readability pass with an advisory review score of 8.0; keep findings 7–10 tracked | Native queued-key/selection/reload/deferred-callback smoke passed after both transformations; the full runner passed 229 tests, validations, local checks, 44 doc blocks and links. |

## Next Actions

- [x] Map window-switcher picker lifetime effects and current test gaps (agent; priority: high; Phase 1).
- [x] Agree to pin observed incorrect behavior and log debt rather than fix it silently (maintainer; priority: high; Phase 1).
- [x] Approve TESTING.md and TECH-DEBT.md before writing (maintainer; priority: high; Phase 1).
- [x] Pin real icon extraction/destruction before changing resource ownership (agent; priority: high; see TESTING.md backlog).
- [x] Fix confirmed owned-icon retention on partial source failure as a separate behavior change (agent; priority: high; see TECH-DEBT.md).
- [x] Choose whether and when to enter Phase 2 (maintainer; priority: low).
- [x] Audit Phase 2 readability and agree the inventory, naming/error conventions and score policy (maintainer + agent; priority: high).
- [x] Apply approved naming/constant fixes 1–6 and record deferred findings 7–10 (agent; priority: high).
- [x] Verify the behavior-preserving Phase 2 change (agent; priority: high).
- [ ] Choose the Phase 3 transformation target; characterize its listed blockers before extraction (maintainer + agent; priority: medium).
