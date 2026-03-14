---
phase: 02-moonbit-public-api
plan: 03
subsystem: api
tags: [moonbit, errors, public-boundary, generated-contract]
requires:
  - phase: 02-01
    provides: canonical top-level runtime entrypoints and docs ordering
  - phase: 02-02
    provides: compiled-filter lane separation
provides:
  - narrower public run error contracts shaped per entrypoint
  - generated contract proof that normal MoonBit consumption does not depend on `@core.Value`
  - docs and tests that keep normal users on `shina1024/jqx`
affects: [phase-3-js-ts-runtime, phase-6-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - entrypoint-shaped composite errors over stable leaf error payloads
    - generated surface audit for internal-type leakage
key-files:
  created: []
  modified:
    - jqx_public_types.mbt
    - jqx.mbt
    - jqx_test.mbt
    - README.mbt.md
    - pkg.generated.mbti
key-decisions:
  - "The public MoonBit surface no longer exposes a broad `JqxError` catch-all; each run entrypoint now raises only its relevant failure modes."
  - "Normal MoonBit users stay on `shina1024/jqx` and do not need `@core.Value` or `@core.Filter`."
patterns-established:
  - "Keep `JsonParseError`, `CompileError`, and `RuntimeError` as structured leaf payloads while shaping entrypoint-specific composite errors above them."
  - "Use docs, tests, and `.mbti` together to prevent internal-type leakage from reappearing."
requirements-completed: [ARCH-02, MBT-04, MBT-05]
duration: 30 min shared across Phase 2 plans
completed: 2026-03-14
---

# Phase 2 Plan 03: Public Boundary and Error Contract Summary

**The MoonBit public package now uses narrower run error contracts and keeps normal users off internal core-only types.**

## Performance

- **Duration:** 30 min shared across Phase 2 plans
- **Started:** 2026-03-14T11:56:24+09:00
- **Completed:** 2026-03-14T12:25:57+09:00
- **Execution style:** shared implementation pass across Plans 01-03

## Accomplishments

- Replaced the broad `JqxError` public contract with `RunError`, `JsonTextRunError`, and `CompiledJsonTextRunError`.
- Preserved `JsonParseError`, `CompileError`, and `RuntimeError` as the structured leaf error types that user code can still inspect.
- Verified through the generated public contract and top-level tests that normal usage stays on `shina1024/jqx` without surfacing `@core.Value` or `@core.Filter`.

## Execution Commits

Implementation for Plans 01-03 landed together because the error-contract cleanup was inseparable from the public runtime and compiled-lane changes:

1. **Phase 2 planning artifacts** - `ec677f4` (docs)
2. **Shared MoonBit public API implementation** - `80df341` (feat)

## Files Created/Modified

- `jqx_public_types.mbt` - defines `RunError`, `JsonTextRunError`, and `CompiledJsonTextRunError`.
- `jqx.mbt` - raises the new entrypoint-shaped contracts from the top-level public API.
- `jqx_test.mbt` - proves the new error mapping through direct and compiled execution paths.
- `README.mbt.md` - tells normal users to stay on the top-level package and the standard `Json` / text lanes.
- `pkg.generated.mbti` - proves `JqxError` is gone from the generated public contract.

## Decisions Made

- Kept advanced internal-value escape hatches out of the normal MoonBit quick start.
- Preferred truthful public error contracts over a smaller but misleading catch-all union.

## Deviations from Plan

### Execution note

**1. [Execution] Shared implementation with Plans 01 and 02**
- **Why:** Error narrowing required coordinated changes across entrypoints, docs, tests, and the generated contract.
- **Impact:** The plan goals were satisfied in one integrated change rather than isolated plan-by-plan commits.

## Issues Encountered

- None in the code path itself. Verification relied on direct local inspection because the helper checker subagent could not read local files in this environment.

## Next Phase Readiness

- Phase 3 can now align JS/TS runtime errors and naming to a stable MoonBit boundary instead of inheriting the old broad `JqxError` shape.

## Self-Check: PASSED

- Found shared implementation commit `80df341`
- Generated contract no longer contains `JqxError`
- `moon info`, `moon fmt`, `moon check -d`, and `moon test` all passed

---
*Phase: 02-moonbit-public-api*
*Completed: 2026-03-14*
