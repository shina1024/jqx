---
phase: 01-shared-core-and-compatibility
plan: 01
subsystem: testing
tags: [jq, compatibility, ledger, cli]
requires: []
provides:
  - maintained compatibility corpus annotated with explicit status metadata
  - shared maintained/upstream compatibility ledger verification
  - documented temporary jq CLI `-e` exit-status exceptions
affects: [01-02, 01-03, phase-4-cli]
tech-stack:
  added: []
  patterns:
    - shared compatibility ledger verification
    - explicit compat metadata in case corpora
key-files:
  created: []
  modified:
    - scripts/jq_compat_cases.json
    - scripts/jq_diff.ps1
    - scripts/jq_diff.sh
    - scripts/jq_upstream_diff_ledger.md
    - scripts/jq_upstream_ledger.ps1
    - scripts/jq_upstream_ledger.sh
key-decisions:
  - "Maintained compatibility cases now carry `compat_status` metadata, with temporary exceptions tied to ledger IDs, reasons, and removal conditions."
  - "The shared compatibility ledger reports both maintained and upstream corpus health so exceptions remain visible from tests and docs together."
patterns-established:
  - "Compatibility cases use `compat_status` plus optional ledger metadata instead of ad hoc skip markers."
  - "Ledger verification runs through `jq_upstream_ledger.*` and checks maintained and upstream corpora together."
requirements-completed: [COMP-01, COMP-02]
duration: 20 min
completed: 2026-03-12
---

# Phase 1 Plan 01: Compatibility Corpus and Ledger Summary

**Maintained jq compatibility cases now carry explicit status metadata, with shared ledger verification covering both maintained and upstream corpora**.

## Performance

- **Duration:** 20 min
- **Started:** 2026-03-12T13:28:46Z
- **Completed:** 2026-03-12T13:48:25Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Added shared-ledger verification in the differential tooling so maintained and upstream corpora are checked against the same compatibility ledger.
- Expanded the maintained compatibility corpus with explicit `compat_status` annotations plus focused CLI/object-order regression cases.
- Documented the remaining jq CLI `-e` exit-status mismatch as a narrow temporary exception with a removal condition.

## Task Commits

Each task was committed atomically:

1. **Task 1: Audit case metadata and exception visibility** - `6af3c75` (feat)
2. **Task 2: Tighten the maintained compatibility corpus** - `5be2622` (test)
3. **Task 3: Align upstream difference tracking with Phase 1 rules** - `eb12f6a` (docs)

**Plan metadata:** pending in follow-up docs commit

## Files Created/Modified
- `scripts/jq_compat_cases.json` - adds explicit compatibility status metadata and new maintained parity cases.
- `scripts/jq_diff.ps1` - recognizes shared-ledger exception metadata during maintained and upstream differential runs.
- `scripts/jq_diff.sh` - forwards ledger-aware diff execution to the PowerShell implementation.
- `scripts/jq_upstream_diff_ledger.md` - reports maintained and upstream corpus health plus the current temporary exceptions.
- `scripts/jq_upstream_ledger.ps1` - verifies ledger coverage across both corpora and keeps the diff ledger synchronized.
- `scripts/jq_upstream_ledger.sh` - exposes shared-ledger verification and differential options from the shell wrapper.

## Decisions Made
- Kept the compatibility ledger in the existing `scripts/` area instead of introducing a separate docs location, so the docs/test linkage stays close to the differential harness.
- Recorded the known CLI `-e` mismatch as one shared ledger entry referenced by three maintained cases, which keeps the exception narrow while preserving case-level visibility.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Two executor agents were interrupted before SUMMARY creation. The already-committed task work was preserved and the plan was completed from the current worktree state.
- The `bash` wrapper entrypoints hit `E_ACCESSDENIED` in this Windows shell, so verification was run through the equivalent `*.ps1` scripts instead.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- The shared ledger and maintained corpus now provide a measurable jq parity baseline for the runtime-boundary refactor in `01-02`.
- The documented `cli-e-exit-status` temporary exception remains intentionally open and should be removed when CLI `-e` semantics are implemented in later phase work.

---
*Phase: 01-shared-core-and-compatibility*
*Completed: 2026-03-12*
