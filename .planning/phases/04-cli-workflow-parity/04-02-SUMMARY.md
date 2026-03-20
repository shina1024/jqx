---
phase: 04-cli-workflow-parity
plan: 02
subsystem: cli
tags: [cli, moonbit, jq, parity, testing]
requires:
  - phase: 04-01
    provides: jqx-first CLI contract and focused direct-input workflow regressions
provides:
  - maintained jq differential cases for direct-input raw output, raw slurp, module-path imports, and runtime-error output ordering
  - wbtest and native wbtest proof names aligned to the maintained parity corpus
  - full local validation for CLI parity plus cross-phase JS and TS regression gates
affects: [phase-6-release-readiness-and-docs, cli]
tech-stack:
  added: []
  patterns:
    - maintained jq differential corpus stays strict and names concrete CLI workflows explicitly
    - fast wbtests and native wbtests mirror the maintained corpus instead of drifting into separate proof stories
key-files:
  created: []
  modified:
    - scripts/jq_compat_cases.json
    - cmd/main_wbtest.mbt
    - cmd/main_native_wbtest.mbt
key-decisions:
  - "The maintained CLI corpus now names the direct-input raw string, raw slurp, module-path, and runtime-error workflows explicitly instead of leaving them implied by broader cases."
  - "No `scripts/jq_exit_cases.json` or `scripts/jq_diff.mjs` code changes were needed because the existing strict exit corpus and profile-aware native runner already satisfied the Phase 4 proof contract."
patterns-established:
  - "Treat maintained jq differential cases as the source of truth, then mirror those workflows in wbtests and native wbtests with matching intent."
  - "Keep CLI parity strict by preserving exact stdout, stderr, and exit-status comparison rather than widening skips or normalizing outputs more aggressively."
requirements-completed: [CLI-01, CLI-02]
duration: 8 min
completed: 2026-03-20
---

# Phase 4 Plan 02: CLI Parity Proof Summary

**Strict maintained jq CLI parity cases plus matching fast and native proof for direct input, module paths, and runtime-error output ordering**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-20T14:42:22+09:00
- **Completed:** 2026-03-20T14:50:18+09:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Expanded `scripts/jq_compat_cases.json` with explicit maintained cases for direct-input raw string output, raw direct-input slurp, `-L` module loading, and runtime errors that preserve prior outputs.
- Aligned the wbtest and native wbtest proof names with those maintained parity cases so the fast CLI loop and the native-only proof describe the same workflows.
- Re-ran the full MoonBit quality gate, native jq differential corpus, dedicated `-e` exit corpus, JS-target MoonBit tests, and TS package verification to confirm Phase 4 did not regress earlier surfaces.

## Task Commits

Each task was committed atomically:

1. **Task 1: Expand maintained differential cases for under-specified CLI workflows** - `ec16c3d` (test)
2. **Task 2: Mirror maintained parity gaps in fast and native CLI tests without loosening the harness** - `a45db26` (test)

**Plan metadata:** pending in follow-up docs commit

## Files Created/Modified
- `scripts/jq_compat_cases.json` - adds named strict jq-vs-jqx cases for direct-input raw output, raw slurp, module-path imports, and runtime-error output ordering.
- `cmd/main_wbtest.mbt` - keeps the fast CLI proof aligned with the maintained parity corpus naming and intent.
- `cmd/main_native_wbtest.mbt` - keeps the native-only module-path proof aligned with the maintained parity corpus.

## Decisions Made
- Kept the existing `scripts/jq_exit_cases.json` unchanged because the dedicated `-e` corpus already covered the missing exit-status behaviors without adding new exceptions or relaxed comparisons.
- Kept the existing `scripts/jq_diff.mjs` implementation unchanged because it already used the profile-aware native runner path and exact stdout/stderr/status comparison required by the plan.

## Deviations from Plan

- The planned `scripts/jq_exit_cases.json` and `scripts/jq_diff.mjs` edits were not needed after inspection and execution proved the existing files already satisfied the stricter Phase 4 contract.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase `04` is ready for goal verification with both CLI requirements now backed by maintained differential proof and fast/native regression coverage.
- Phase `06` release-readiness work can reuse the explicit jqx-first CLI workflows and maintained native differential cases produced here.

## Self-Check: PASSED

- Found task commits `ec16c3d` and `a45db26` in git history
- `moon test`, `moon test --target js js`, `node scripts/jq_diff.mjs`, and `node scripts/jq_diff.mjs scripts/jq_exit_cases.json` all passed locally

---
*Phase: 04-cli-workflow-parity*
*Completed: 2026-03-20*
