---
phase: 01-shared-core-and-compatibility
plan: 03
subsystem: verification
tags: [jq, moonbit, js, ci, release, compatibility]
requires:
  - phase: 01-01
    provides: maintained compatibility corpus and jq 1.8.1 exception ledger
  - phase: 01-02
    provides: shared core run lanes consumed by MoonBit and JS wrappers
provides:
  - explicit fidelity and ordering proof through the MoonBit public API and JS-target wrapper
  - native-run differential harness support for release-profile CLI proof
  - Phase 1 CI and release workflows aligned to the documented gate
affects: [phase-2-moonbit-api, phase-3-js-ts-runtime, phase-4-cli, phase-6-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - cross-surface fidelity proofs anchored in public runtime entry points
    - native release differential execution for CLI parity checks
key-files:
  created: []
  modified:
    - core/execute_test.mbt
    - core/execute_test_support_test.mbt
    - jqx_test.mbt
    - js/jqx_js_test.mbt
    - scripts/jq_diff.sh
    - scripts/jq_diff_native.sh
    - .github/workflows/ci.yml
    - .github/workflows/release-cli.yml
key-decisions:
  - "Phase 1 fidelity proof must flow through the MoonBit top-level package and the JS wrapper, not just through core-only tests."
  - "Linux CI now proves CLI parity with native release binaries for maintained and upstream differential checks, while macOS and Windows stay on smoke-level coverage."
  - "The CLI release workflow now builds `--release` artifacts and smoke-tests the packaged binary before upload."
patterns-established:
  - "When semantics are fidelity-sensitive, add the same regression shape at core, MoonBit public, and JS wrapper layers."
  - "Use `JQX_RUNNER=native` plus `JQX_PROFILE=release` in shell differential jobs when Phase-level proof must reflect the real CLI artifact."
requirements-completed: [COMP-03, COMP-04]
duration: 114 min
completed: 2026-03-14
---

# Phase 1 Plan 03: Fidelity Proof and CI Gate Summary

**Phase 1 now proves shared-core fidelity through the MoonBit public API, the JS wrapper, and release-profile CLI differential jobs instead of relying on lower-signal core-only coverage.**

## Performance

- **Duration:** 114 min
- **Started:** 2026-03-13T23:09:05+09:00
- **Completed:** 2026-03-14T01:03:24+09:00
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Added regression proof for ordering-sensitive updates, escaped string outputs, and large-number text fidelity across the shared core run helpers, the top-level MoonBit API, and the JS wrapper.
- Extended the shell differential harness so CI can run maintained parity checks against a prebuilt native CLI binary, then switched the native exit harness to release-profile proof by default.
- Reshaped CI to expose the documented MoonBit gate order on Linux, run top-level MoonBit tests instead of only package-local native suites, and make the CLI release workflow build and smoke-test real release binaries.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add fidelity and ordering regression proof** - `8d83a84` (test)
2. **Task 2: Reconcile differential harnesses with the refactored core** - `457cedb` (test)
3. **Task 3: Reshape CI to match the Phase 1 gate** - `aaaf687` (ci)

## Files Created/Modified

- `core/execute_test.mbt` - adds shared-core run-lane regressions for order-sensitive updates, escaped string outputs, and large-number repr preservation.
- `core/execute_test_support_test.mbt` - adds run-lane helpers used by execute-focused regression tests.
- `jqx_test.mbt` - proves fidelity-sensitive behavior through the public MoonBit API and compiled-filter text lane.
- `js/jqx_js_test.mbt` - proves the JS wrapper preserves ordering and repr-sensitive outputs through both direct and compiled execution lanes.
- `scripts/jq_diff.sh` - adds optional native-binary execution so shell differential jobs can prove CLI parity against release-profile artifacts.
- `scripts/jq_diff_native.sh` - defaults native exit proof to the release profile.
- `.github/workflows/ci.yml` - aligns Linux CI with `moon info -> moon fmt --check -> moon check -d -> moon test`, keeps JS-target and TS verification explicit, and runs Linux differential jobs against release binaries.
- `.github/workflows/release-cli.yml` - builds `--release` binaries on every platform and smoke-tests the produced CLI before packaging.

## Decisions Made

- Kept the heaviest upstream corpus run in CI rather than trying to force a Windows-local completion path once the shell harness proved too slow in this environment.
- Preserved the dedicated timezone smoke matrix, but upgraded the Linux/macOS branch of that matrix to use the native release CLI for stronger artifact-level signal.

## Deviations from Plan

### Auto-fixed Issues

**1. [Execution] Replaced a blocked executor run with local task execution**
- **Found during:** Plan orchestration
- **Issue:** The `gsd-executor` subagent could not access local tools because of a sandbox backend mismatch before any repo changes were made.
- **Fix:** Executed Tasks 1-3 directly in this session, keeping the task boundaries and atomic commits intact.
- **Files modified:** none by the failed executor; all implementation happened in the main session
- **Verification:** task-level verifies were run locally after each commit boundary
- **Committed in:** n/a (orchestration recovery only)

---

**Total deviations:** 1 auto-fixed (execution environment)
**Impact on plan:** No scope change; only the execution route changed.

## Issues Encountered

- `bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json` exceeded a 1 hour timeout in this Windows-local environment, even after enabling native release execution. Maintained corpus and native exit proof still passed locally, and the full upstream corpus is delegated to Linux CI.
- Clearing the stale GSD auto-chain flag modified `.planning/config.json`; that change remains workflow-local and should not be committed as part of this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 1 now has an explainable proof surface for MoonBit, JS/TS, and CLI fidelity, so Phase 2 can focus on API design rather than re-litigating shared-core semantics.
- The remaining known compatibility exception is still limited to the documented CLI `-e` exit-status behavior.

## Self-Check: PASSED

- Found task commits `8d83a84`, `457cedb`, and `aaaf687` in git history
- Targeted MoonBit, JS, TS, maintained differential, and native exit verification passed locally
- Full upstream differential remains delegated to CI because the Windows-local shell run timed out

---
*Phase: 01-shared-core-and-compatibility*
*Completed: 2026-03-14*
