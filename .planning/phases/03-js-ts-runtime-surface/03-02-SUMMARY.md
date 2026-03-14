---
phase: 03-js-ts-runtime-surface
plan: 02
subsystem: runtime
tags: [typescript, runtime, bind, compiled-filters, tests]
requires:
  - phase: 03-01
    provides: runtime-first root package contract and JS/TS naming direction
provides:
  - shared lane helpers for direct and bound JS runtimes
  - explicit `/bind` scope as a JSON-text backend integration surface
  - regression proof for direct versus bound lane parity and compiled-filter boundaries
affects: [phase-3-package-outputs, phase-5-schema-adapters, phase-6-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - direct and bound runtimes share one internal helper path for value-lane encoding, output decoding, and query normalization
    - `/bind` remains query and JSON-text based until a deliberate compiled-backend transport exists
key-files:
  created:
    - ts/jqx/src/runtime_shared.ts
  modified:
    - ts/jqx/src/direct_runtime.ts
    - ts/jqx/src/bind.ts
    - ts/jqx/README.md
    - ts/jqx/test/direct_runtime.test.ts
    - ts/jqx/test/index.test.ts
    - ts/jqx/test/typecheck.ts
key-decisions:
  - "Direct and bound runtimes now share one internal helper path for JSON value-lane conversion and typed-query normalization."
  - "Compiled filters stay on the direct runtime; `/bind` remains an explicit JSON-text backend integration surface instead of implying a second compiled contract."
patterns-established:
  - "When direct and bound runtimes need the same stringify, parse, or DSL-normalization behavior, put it in `runtime_shared.ts` instead of copying helpers."
  - "Use runtime tests and type proof together to keep `/bind` explicit about what it does not expose, especially compiled filters."
requirements-completed: [TS-02, TS-03, TS-05]
duration: 10 min
completed: 2026-03-14
---

# Phase 3 Plan 02: Compiled and Bind Surface Summary

**Shared direct and bound JS runtime lane helpers with an explicit `/bind` JSON-text scope and no implied compiled-filter transport**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-14T14:06:00+09:00
- **Completed:** 2026-03-14T14:15:46+09:00
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Extracted the shared value-lane encoding, output decoding, error normalization, and typed-query normalization helpers so `direct_runtime.ts` and `bind.ts` no longer maintain drift-prone copies.
- Made the `/bind` boundary explicit in code, docs, and type proof: it lifts JSON-text backends into value-lane and streaming helpers, but compiled filters stay on the direct runtime.
- Added parity regression proof that direct and bound runtimes now surface the same `input_stringify` behavior while `/bind` remains intentionally free of compiled-filter methods.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract or consolidate shared lane helpers between direct and bound runtimes** - `e2ca363` (feat)
2. **Task 2: Resolve the compiled-filter versus `/bind` boundary explicitly** - `419af62` (docs)
3. **Task 3: Expand regression proof for compiled, bound, streaming, and typed-query behavior** - `672e484` (test)

## Files Created/Modified

- `ts/jqx/src/runtime_shared.ts` - centralizes shared JSON-lane conversion, error normalization, and typed-query normalization helpers.
- `ts/jqx/src/direct_runtime.ts` - routes direct runtime and compiled execution through the shared helper path.
- `ts/jqx/src/bind.ts` - reuses the shared helpers and documents `/bind` as a JSON-text backend surface.
- `ts/jqx/README.md` - states that compiled filters stay on the direct runtime and that `/bind` does not imply a second compiled contract.
- `ts/jqx/test/direct_runtime.test.ts` - proves direct runtime input-stringify behavior on the shared helper path.
- `ts/jqx/test/index.test.ts` - proves the bound runtime uses the same value-lane input-stringify semantics.
- `ts/jqx/test/typecheck.ts` - locks `/bind` out of compiled-filter methods at the type level.

## Decisions Made

- Kept `/bind` deliberately text-runtime based instead of inventing a half-specified compiled-filter backend story in Phase 3.
- Centralized shared runtime-lane logic in an internal helper module rather than leaving direct and bound runtimes to drift independently.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan `03-03` can harden the actual package build, export map, and artifact checks on top of a now-aligned direct and bound runtime contract.
- The internal helper split gives Wave 3 one place to keep source behavior and built artifacts synchronized if packaging changes touch runtime entrypoints.

## Self-Check: PASSED

- `pnpm test` passed in `ts/jqx`.
- `pnpm typecheck` passed in `ts/jqx`.
- `/bind` now documents and type-proves that compiled filters remain direct-runtime only.

---
*Phase: 03-js-ts-runtime-surface*
*Completed: 2026-03-14*
