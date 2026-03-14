---
phase: 02-moonbit-public-api
plan: 02
subsystem: api
tags: [moonbit, compiled-filter, compatibility-lane, tests]
requires:
  - phase: 02-01
    provides: canonical top-level runtime entrypoints and direct `Json` lane docs
provides:
  - compiled-filter methods that clearly separate value-lane and JSON-text execution
  - top-level regression proof for compiled reuse across both public lanes
  - docs that present compiled execution as the reuse path after direct `run(...)`
affects: [02-03, phase-3-js-ts-runtime, phase-6-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - compiled execution as an opaque reusable public handle
    - explicit value-lane vs compatibility-lane method separation
key-files:
  created: []
  modified:
    - jqx.mbt
    - jqx_public_types.mbt
    - jqx_test.mbt
    - README.mbt.md
    - pkg.generated.mbti
key-decisions:
  - "Compiled execution remains a reuse-oriented path over the same public contract rather than a competing first entrypoint."
  - "The compiled value lane stays on `Json`, while the compatibility lane stays on JSON text."
patterns-established:
  - "Use `CompiledFilter::run` for normal embedding and `CompiledFilter::run_json_text` for jq-style fidelity-sensitive execution."
  - "Prove compiled-lane behavior through top-level tests and generated contract review together."
requirements-completed: [MBT-02, MBT-03]
duration: 30 min shared across Phase 2 plans
completed: 2026-03-14
---

# Phase 2 Plan 02: Compiled Filter Lane Separation Summary

**Compiled execution now reads as an explicit reuse path with a clear split between the `Json` value lane and the JSON-text compatibility lane.**

## Performance

- **Duration:** 30 min shared across Phase 2 plans
- **Started:** 2026-03-14T11:56:24+09:00
- **Completed:** 2026-03-14T12:25:57+09:00
- **Execution style:** shared implementation pass across Plans 01-03

## Accomplishments

- Preserved the opaque `CompiledFilter` abstraction while keeping `CompiledFilter::run(Json)` and `CompiledFilter::run_json_text(StringView)` visibly distinct.
- Added top-level tests that prove compiled execution behavior on both public lanes, including parse-error and repr-sensitive compatibility-lane cases.
- Kept the generated contract aligned with the intended compiled-filter public methods and error boundaries.

## Execution Commits

Implementation for Plans 01-03 landed together because the compiled-lane changes and error-contract cleanup were tightly coupled:

1. **Phase 2 planning artifacts** - `ec677f4` (docs)
2. **Shared MoonBit public API implementation** - `80df341` (feat)

## Files Created/Modified

- `jqx.mbt` - keeps compiled methods aligned to the public lane split.
- `jqx_public_types.mbt` - defines the compiled JSON-text error contract without reopening `@core.Filter`.
- `jqx_test.mbt` - proves compiled value-lane and text-lane behavior through the public package.
- `README.mbt.md` - documents compiled execution as the reuse path after direct execution.
- `pkg.generated.mbti` - exposes the compiled methods and narrowed compiled text-lane error type.

## Decisions Made

- Kept `CompiledFilter` fully opaque instead of exposing `@core.Filter`.
- Reused the same public package for both direct and compiled execution instead of introducing a separate advanced surface.

## Deviations from Plan

### Execution note

**1. [Execution] Shared implementation with Plans 01 and 03**
- **Why:** Compiled-lane semantics, docs, and public errors all changed on the same public boundary files.
- **Impact:** The plan goals were completed, but the implementation history is one shared feature commit instead of isolated plan commits.

## Issues Encountered

- None beyond the plan-checker sandbox issue noted in the phase verification; the code and test changes themselves landed cleanly.

## Next Phase Readiness

- Phase 3 can mirror the same reuse story for JS/TS: direct runtime first, compiled execution second, text-lane fidelity explicit.

## Self-Check: PASSED

- Found shared implementation commit `80df341`
- Top-level compiled-lane tests passed under `moon test`

---
*Phase: 02-moonbit-public-api*
*Completed: 2026-03-14*
