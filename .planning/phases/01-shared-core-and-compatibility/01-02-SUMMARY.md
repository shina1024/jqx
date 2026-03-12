---
phase: 01-shared-core-and-compatibility
plan: 02
subsystem: api
tags: [jq, moonbit, js, typescript, compatibility]
requires:
  - phase: 01-01
    provides: maintained compatibility corpus and jq 1.8.1 ledger baseline
provides:
  - explicit shared Json/Value boundary in the core package
  - core-owned run helpers for Json, Value, and JSON-text execution lanes
  - JS runtime wrapper delegation through the shared core run boundary
affects: [01-03, phase-2-moonbit-api, phase-3-js-ts-runtime, phase-4-cli]
tech-stack:
  added: []
  patterns:
    - core-owned run-lane orchestration
    - wrapper-side error shaping over shared core RunError branches
key-files:
  created: []
  modified:
    - core/jqx.mbt
    - jqx.mbt
    - jqx_public_types.mbt
    - js/jqx_js.mbt
    - js/jqx_typed.mbt
    - core/jqx_test.mbt
key-decisions:
  - "The shared core now owns compiled and string-filter run orchestration for both Value and JSON-text lanes, so wrappers only convert inputs/outputs and shape public errors."
  - "CLI stream segmentation and TS JSON encode/decode remain adapter concerns; they were audited but left outside the semantic core because they do not change jq meaning."
patterns-established:
  - "Add new execution helpers in core first, then expose them through MoonBit or JS wrappers instead of recreating parse/compile/execute flow per surface."
  - "JS-facing structured errors stay as adapter-level translations from core RunError variants, not wrapper-local execution paths."
requirements-completed: [ARCH-01, ARCH-03, ARCH-04]
duration: 18 min
completed: 2026-03-12
---

# Phase 1 Plan 02: Runtime Boundary Refactor Summary

**Shared core now owns the Json/Value boundary and run-lane orchestration, with MoonBit and JS wrappers reduced to thin adapter layers over the same jq semantics.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-03-12T14:09:53Z
- **Completed:** 2026-03-12T14:27:21Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments
- Moved the shared Json-to-Value boundary and text-lane conversion helpers into `core/jqx.mbt`, removing the old top-level conversion file and making the semantic center easier to find.
- Centralized core run behavior for Json, Value, and JSON-text lanes, then retargeted the top-level MoonBit wrapper and JS runtime bridge to delegate into that shared path.
- Reverified the maintained jq corpus and native diff checks against jq 1.8.1 with only the existing documented `cli-e-exit-status` temporary exceptions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Define the semantic boundary in code** - `25fdb0c` (feat)
2. **Task 2: Move compatibility-sensitive implementation inward** - `c76c302` (feat)
3. **Task 3: Retarget CLI and JS/TS wrappers to the new core boundary** - `e48798d` (feat)

**Plan metadata:** pending in follow-up docs commit

## Files Created/Modified
- `core/jqx.mbt` - now owns Json/Value conversion plus shared run helpers for compiled and string-filter execution.
- `jqx.mbt` - top-level MoonBit runtime wrapper delegates public parse and run lanes to the refactored core.
- `jqx_public_types.mbt` - maps core parse, filter, and eval errors into the public MoonBit error surface.
- `js/jqx_js.mbt` - converts core `RunError` branches into structured JS-facing `JqxError` values while delegating run lanes to core.
- `js/jqx_typed.mbt` - typed query helpers execute compiled text lanes directly through the shared core.
- `core/jqx_test.mbt` - adds coverage for the new core Value-lane run helpers.
- `jqx_json_convert.mbt` - removed after moving shared Json conversion helpers into the core package.

## Decisions Made
- Kept CLI stream splitting in the adapter layer after audit, because stdin segmentation, `-R`, and `-s` are transport concerns while single-document parse semantics remain core-owned.
- Left `ts/jqx/src/direct_runtime.ts` unchanged after audit, because it already only stringifies/parses structured JSON and delegates execution to the MoonBit JS bridge.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added core Value-lane run helpers so JS wrappers stop owning run orchestration**
- **Found during:** Task 3 (Retarget CLI and JS/TS wrappers to the new core boundary)
- **Issue:** `js/jqx_js.mbt` still owned parse/compile/execute flow for `run_values` and `run_compiled_values`, leaving compatibility-sensitive control flow outside the shared core.
- **Fix:** Added `@core.run_values` and `@core.run_compiled_values`, rewired `run_compiled_json_text` through the same shared helper path, and simplified the JS bridge to translate `@core.RunError` instead of reimplementing execution flow.
- **Files modified:** `core/jqx.mbt`, `js/jqx_js.mbt`, `core/jqx_test.mbt`
- **Verification:** `moon check -d`, `moon test`, `moon test --target js js`, `./scripts/jq_diff.ps1`, `./scripts/jq_diff_native.ps1`
- **Committed in:** `e48798d` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** The auto-fix was necessary to finish the shared-core refactor cleanly. No scope creep.

## Issues Encountered
- Resumed from a post-rebase clean worktree with Task 1 and Task 2 commits already present but no `01-02-SUMMARY.md`, so the remaining work started with an audit instead of replaying the interrupted attempt.
- `./scripts/ts_packages.ps1 verify --frozen-lockfile` failed early with `spawnSync pnpm.cmd EINVAL`, so TS verification had to be checked with direct package commands instead of the wrapper script.
- `pnpm test` in `ts/jqx` is currently blocked by the missing optional dependency `@esbuild/win32-x64` required by `tsx`; package typechecking still passed via direct `node .../typescript/bin/tsc -p tsconfig.json --noEmit`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase `01-03` can now focus on cross-surface fidelity and ordering proof with a clearer semantic center and thinner wrapper layers.
- The TS test-runner dependency issue should be fixed before Phase 3 package hardening work, but it did not block the required MoonBit or jq parity verification for this plan.

## Self-Check: PASSED
- Found `.planning/phases/01-shared-core-and-compatibility/01-02-SUMMARY.md`
- Found task commits `25fdb0c`, `c76c302`, and `e48798d` in git history

---
*Phase: 01-shared-core-and-compatibility*
*Completed: 2026-03-12*
