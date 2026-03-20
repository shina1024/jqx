---
phase: 05-schema-adapter-packages
plan: 01
subsystem: infra
tags: [typescript, pnpm, npm-exports, adapters, zod, yup, valibot]
requires:
  - phase: 03-js-ts-runtime-surface
    provides: stable runtime and bind entrypoints for the root npm package
provides:
  - runtime-only root npm exports for `@shina1024/jqx`
  - standalone adapter package boundary proof for Zod, Yup, and Valibot
  - frozen-lockfile TS workspace verification after adapter subpath removal
affects: [05-02, 06-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - runtime-only root export map with standalone adapter packages
    - adapter tests execute against built self-referenced package entrypoints
key-files:
  created:
    - .planning/phases/05-schema-adapter-packages/05-01-SUMMARY.md
  modified:
    - ts/jqx/package.json
    - ts/jqx/pnpm-lock.yaml
    - ts/jqx/test/package_exports.test.ts
    - ts/zod-adapter/package.json
    - ts/zod-adapter/test/index.test.ts
    - ts/yup-adapter/package.json
    - ts/yup-adapter/test/index.test.ts
    - ts/valibot-adapter/package.json
    - ts/valibot-adapter/test/index.test.ts
key-decisions:
  - "The root `@shina1024/jqx` package now publishes only `.` and `./bind`; adapter imports are standalone package names only."
  - "Standalone adapter tests must build first and import their own package name so package-boundary proof runs against shipped artifacts."
patterns-established:
  - "Root npm export maps should prove the intended public boundary directly in package-name import tests."
  - "Adapter package tests should self-reference the package name instead of importing `src/` when boundary behavior matters."
requirements-completed: [ADPT-01, ADPT-02, ADPT-03]
duration: 6 min
completed: 2026-03-20
---

# Phase 05 Plan 01: Schema Adapter Packages Summary

**Runtime-only `@shina1024/jqx` exports with standalone adapter package proof across Zod, Yup, and Valibot**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-20T07:11:30Z
- **Completed:** 2026-03-20T07:17:36Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Removed `./zod`, `./yup`, and `./valibot` from the root `@shina1024/jqx` export map and deleted the matching shim entry files.
- Updated the root package proof so only `.` and `./bind` are valid public entrypoints and the removed adapter subpaths stay absent.
- Tightened all standalone adapter packages to build before testing and prove `createAdapter` and `createQueryAdapter` through self-referenced package-name imports.

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove root adapter subpaths and make `@shina1024/jqx` runtime-only** - `51d7e59` (feat)
2. **Task 2: Prove standalone adapter packages and shared contract boundaries after cleanup** - `0e3b75c` (test)

## Files Created/Modified

- `ts/jqx/package.json` - removed adapter exports, build inputs, and adapter dependencies from the root runtime package.
- `ts/jqx/pnpm-lock.yaml` - refreshed root package lock data after removing local adapter dependencies.
- `ts/jqx/test/package_exports.test.ts` - asserts the root export map is runtime-only and only `.` plus `./bind` resolve.
- `ts/jqx/src/zod.ts` - removed obsolete root adapter shim.
- `ts/jqx/src/yup.ts` - removed obsolete root adapter shim.
- `ts/jqx/src/valibot.ts` - removed obsolete root adapter shim.
- `ts/zod-adapter/package.json` - builds before tests so package proof runs against `dist/`.
- `ts/zod-adapter/test/index.test.ts` - verifies self-referenced Zod package imports and shared contract behavior.
- `ts/yup-adapter/package.json` - builds before tests so package proof runs against `dist/`.
- `ts/yup-adapter/test/index.test.ts` - verifies self-referenced Yup package imports and shared contract behavior.
- `ts/valibot-adapter/package.json` - builds before tests so package proof runs against `dist/`.
- `ts/valibot-adapter/test/index.test.ts` - verifies self-referenced Valibot package imports and shared contract behavior.

## Decisions Made

- Kept the shared adapter contract in `@shina1024/jqx-adapter-core` and expressed the public package boundary entirely through runtime-only root exports plus standalone adapter packages.
- Used package-name self-reference inside adapter tests instead of source imports so package-boundary regressions fail on shipped artifacts, not only on local source structure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Repaired TS package installs to restore `ts_package_build.mjs` native binding resolution**
- **Found during:** Task 1 (Remove root adapter subpaths and make `@shina1024/jqx` runtime-only)
- **Issue:** `pnpm build && pnpm test` in `ts/jqx` failed because the package build step could not load its native binding from the local TS toolchain after dependency boundary changes.
- **Fix:** Ran the documented `./scripts/ts_packages.ps1 refresh` flow, which rebuilt the package dependency chain and refreshed `ts/jqx/pnpm-lock.yaml` for the new root-package dependency set.
- **Files modified:** `ts/jqx/pnpm-lock.yaml`
- **Verification:** `pnpm build && pnpm test` in `ts/jqx`; `bash ./scripts/ts_packages.sh verify --frozen-lockfile`
- **Committed in:** `51d7e59` (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The fix was required to make the planned verification path runnable. No scope creep beyond restoring the intended package build flow.

## Issues Encountered

- `ts/jqx` initially failed to build because the local TS package install was missing a native binding used by the package build toolchain. The documented refresh workflow restored the environment and kept the planned verification path intact.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 05-02 can build on a stable package-boundary story: `@shina1024/jqx` is runtime-only and adapters are proven as standalone package surfaces.
- Release-readiness work now has frozen-lockfile verification proving the adapter package split through built artifacts rather than source-only imports.

## Self-Check: PASSED

- Found `.planning/phases/05-schema-adapter-packages/05-01-SUMMARY.md`
- Found commit `51d7e59`
- Found commit `0e3b75c`

---
*Phase: 05-schema-adapter-packages*
*Completed: 2026-03-20*
