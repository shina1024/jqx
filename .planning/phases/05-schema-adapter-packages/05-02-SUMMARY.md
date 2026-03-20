---
phase: 05-schema-adapter-packages
plan: 02
subsystem: adapters
tags: [typescript, adapters, docs, zod, yup, valibot]
requires:
  - phase: 05-01
    provides: runtime-only root package boundary and standalone adapter import path
provides:
  - native Yup and Valibot issue payload preservation under the stable adapter error contract
  - standalone adapter README alignment around filter-first runtime injection
  - frozen-lockfile package verification for root and adapter packages after adapter hardening
affects: [06-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - adapter errors keep jqx-owned top-level kinds while exposing validator-native issues
    - adapter docs teach createAdapter(runtime).filter(...) before query and infer lanes
key-files:
  created:
    - .planning/phases/05-schema-adapter-packages/05-02-SUMMARY.md
  modified:
    - ts/jqx/README.md
    - ts/zod-adapter/README.md
    - ts/yup-adapter/README.md
    - ts/valibot-adapter/README.md
    - ts/yup-adapter/src/index.ts
    - ts/yup-adapter/test/index.test.ts
    - ts/yup-adapter/test/typecheck.ts
    - ts/valibot-adapter/src/index.ts
    - ts/valibot-adapter/test/index.test.ts
    - ts/valibot-adapter/test/typecheck.ts
key-decisions:
  - "The stable adapter error contract keeps jqx-owned top-level kinds and messages while `issues` preserves validator-native detail."
  - "Root and adapter docs should teach standalone package names and `createAdapter(runtime).filter(...)` as the default adapter story."
patterns-established:
  - "Yup adapters should surface `yup.ValidationError[]` rather than collapsing issues to strings."
  - "Valibot adapters should surface `v.BaseIssue<unknown>[]` directly from `safeParseAsync(...)`."
requirements-completed: [ADPT-01, ADPT-02, ADPT-03]
duration: 6 min
completed: 2026-03-20
---

# Phase 05 Plan 02: Schema Adapter Packages Summary

**Structured native adapter issues for Yup and Valibot with standalone-package, filter-first docs across Zod, Yup, and Valibot**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-20T07:25:32Z
- **Completed:** 2026-03-20T07:31:12Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Changed the Yup adapter to return `CoreAdapterError<yup.ValidationError[]>` and preserve native `ValidationError` instances in `issues`.
- Changed the Valibot adapter to return `CoreAdapterError<v.BaseIssue<unknown>[]>` and preserve native `safeParseAsync(...)` issues.
- Added runtime tests and type fixtures that prove `issues[0]` exposes validator-native structured fields for Yup and Valibot.
- Rewrote the root and adapter READMEs around standalone package names and `createAdapter(runtime).filter(...)` as the primary on-ramp.

## Task Commits

Each task was committed atomically:

1. **Task 1: Preserve native Yup and Valibot issue detail while keeping the shared error shape stable** - `05edf98` (feat)
2. **Task 2: Rewrite root and adapter docs around standalone package imports and filter-first examples** - `ef69821` (chore)

## Files Created/Modified

- `ts/yup-adapter/src/index.ts` - preserves `yup.ValidationError[]` in adapter failures while keeping the shared top-level error contract.
- `ts/yup-adapter/test/index.test.ts` - proves runtime failures expose structured Yup issue objects.
- `ts/yup-adapter/test/typecheck.ts` - locks the public Yup adapter type contract to `yup.ValidationError[]`.
- `ts/valibot-adapter/src/index.ts` - preserves native Valibot issues from `safeParseAsync(...)`.
- `ts/valibot-adapter/test/index.test.ts` - proves runtime failures expose structured Valibot issue objects.
- `ts/valibot-adapter/test/typecheck.ts` - locks the public Valibot adapter type contract to `v.BaseIssue<unknown>[]`.
- `ts/jqx/README.md` - points adapter users to standalone package names only and keeps the runtime-first package story coherent.
- `ts/zod-adapter/README.md` - leads with `createAdapter(runtime).filter(...)` and keeps query support secondary.
- `ts/yup-adapter/README.md` - leads with `createAdapter(runtime).filter(...)` and documents standalone installation/imports.
- `ts/valibot-adapter/README.md` - leads with `createAdapter(runtime).filter(...)` and documents standalone installation/imports.

## Decisions Made

- Preserved one shared adapter error shape across validators by keeping `input_validation`, `runtime`, and `output_validation` as the top-level kinds while letting `issues` stay validator-native.
- Kept adapters explicitly layered on the stable jqx runtime contract, with runtime injection documented as the normal path and `query(...)` / `infer(...)` kept as secondary lanes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Workflow] Final summary and tracking had to be completed inline after executor shutdown**
- **Found during:** Post-commit workflow closeout
- **Issue:** The executor produced both task commits but stopped before writing `05-02-SUMMARY.md` and updating the phase tracking artifacts.
- **Fix:** Re-ran the required verification commands inline, recreated the missing summary, and continued phase closeout from the orchestrator.
- **Files modified:** `.planning/phases/05-schema-adapter-packages/05-02-SUMMARY.md`
- **Verification:** `moon info`; `moon fmt`; `moon check`; `moon test`; `pnpm build && pnpm test` in `ts/jqx`; `pnpm test && pnpm typecheck` in `ts/zod-adapter`; `pnpm test && pnpm typecheck` in `ts/yup-adapter`; `pnpm test && pnpm typecheck` in `ts/valibot-adapter`; `bash ./scripts/ts_packages.sh verify --frozen-lockfile`
- **Committed in:** follow-up docs closeout commit

---

**Total deviations:** 1 auto-fixed
**Impact on plan:** Implementation scope stayed on-plan; only the workflow artifact step needed manual recovery after the executor stopped.

## Issues Encountered

- The first manual verification pass hit the known local native-binding toolchain issue again. Running the documented `./scripts/ts_packages.ps1 refresh` workflow restored package builds without further code changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Release-readiness work can assume the JS/TS runtime package is runtime-only and the adapter packages present one coherent standalone story.
- Adapter docs, types, and runtime tests now agree on a stable jqx-owned error contract with validator-native issue detail where practical.

## Self-Check: PASSED

- Found `.planning/phases/05-schema-adapter-packages/05-02-SUMMARY.md`
- Found commit `05edf98`
- Found commit `ef69821`

---
*Phase: 05-schema-adapter-packages*
*Completed: 2026-03-20*
