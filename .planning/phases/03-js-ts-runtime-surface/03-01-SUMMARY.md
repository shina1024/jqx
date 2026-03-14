---
phase: 03-js-ts-runtime-surface
plan: 01
subsystem: runtime
tags: [typescript, runtime, public-api, docs, tests]
requires: []
provides:
  - runtime-first root exports for `@shina1024/jqx`
  - README guidance that teaches `run(filter, input)` as the primary JS/TS on-ramp
  - runtime and type-level proof that keeps query and integration helpers secondary
affects: [phase-3-compiled-bind, phase-5-schema-adapters, phase-6-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - canonical direct runtime exports grouped ahead of secondary root-package lanes
    - docs, runtime tests, and type proof kept aligned around one runtime-first story
key-files:
  created: []
  modified:
    - ts/jqx/src/index.ts
    - ts/jqx/src/direct_runtime.ts
    - ts/jqx/README.md
    - ts/jqx/test/direct_runtime.test.ts
    - ts/jqx/test/typecheck.ts
key-decisions:
  - "The root package now groups `run`, `runJsonText`, `compile`, `parseJson`, and `isValidJson` ahead of query and adapter-facing helpers."
  - "README and regression proof now treat query helpers and runtime objects as secondary lanes while keeping them available from the root package."
patterns-established:
  - "Keep canonical root runtime exports in a dedicated top block so the main package reads as a direct-use runtime first."
  - "Use README, runtime tests, and typecheck proof together to prevent the root JS/TS surface from drifting back into a kitchen-sink barrel."
requirements-completed: [TS-01, TS-05]
duration: 25 min
completed: 2026-03-14
---

# Phase 3 Plan 01: JS/TS Root Runtime Surface Summary

**Runtime-first `@shina1024/jqx` root exports with aligned docs and regression proof for `run(filter, input)`**

## Performance

- **Duration:** 25 min
- **Started:** 2026-03-14T13:41:00+09:00
- **Completed:** 2026-03-14T14:06:03+09:00
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Re-grouped the root export module so the canonical direct runtime names are the first visible `@shina1024/jqx` surface.
- Reframed the README around `run(filter, input)` and the value lane, with compiled reuse and JSON-text compatibility clearly positioned after the quick start.
- Tightened runtime and type-level regression proof so the root package keeps the canonical runtime story while leaving query and integration helpers available as secondary lanes.

## Task Commits

Each task was committed atomically:

1. **Task 1: Audit and trim the root package runtime contract** - `2bac586` (feat)
2. **Task 2: Reframe docs and regression proof around the direct runtime on-ramp** - `8202370` (docs)
3. **Task 3: Remove surface drift that would block pre-1.0 cleanup** - `8e3eb18` (test)

## Files Created/Modified

- `ts/jqx/src/index.ts` - groups canonical direct-use exports ahead of secondary query and integration lanes.
- `ts/jqx/src/direct_runtime.ts` - documents the direct runtime/query split and keeps the adapter-facing runtime object with the primary lane.
- `ts/jqx/README.md` - teaches the runtime-first JS/TS on-ramp and demotes secondary lanes without removing them.
- `ts/jqx/test/direct_runtime.test.ts` - proves the root package exposes the canonical direct runtime entrypoints and keeps query/integration helpers secondary.
- `ts/jqx/test/typecheck.ts` - keeps the public type proof aligned to the root runtime-first surface and the direct runtime contracts.

## Decisions Made

- Made the root export file read as a direct-use runtime first rather than a mixed utility barrel.
- Kept query helpers and adapter-facing runtime objects on the root package, but only after the canonical direct runtime block in code and docs.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Verification initially failed because the local `ts/jqx/node_modules` install only had Linux optional tool packages. Re-running `pnpm install --frozen-lockfile` in `ts/jqx` restored `@esbuild/win32-x64` and the Windows `*.CMD` shims already pinned in the lockfile, after which `pnpm test` and `pnpm typecheck` both passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan `03-02` can now align compiled execution and `/bind` helpers around a stable, runtime-first root package contract.
- The local Windows install is repaired for this checkout, but Plan `03-03` still needs to harden the package build and verification path so fresh installs do not depend on this manual repair step.

## Self-Check: PASSED

- `ts/jqx/src/index.ts`, `ts/jqx/README.md`, and `ts/jqx/test/direct_runtime.test.ts` now tell the same runtime-first story.
- `pnpm test` passed in `ts/jqx`.
- `pnpm typecheck` passed in `ts/jqx`.

---
*Phase: 03-js-ts-runtime-surface*
*Completed: 2026-03-14*
