---
phase: 03-js-ts-runtime-surface
plan: 03
subsystem: packaging
tags: [typescript, package, artifacts, esm, cjs, declarations]
requires:
  - phase: 03-01
    provides: canonical root runtime and runtime-first docs
  - phase: 03-02
    provides: aligned direct and bound runtime semantics on one helper path
provides:
  - package-local build self-repair for missing current-platform tool shims
  - artifact-level smoke tests for package-name import and require entrypoints
  - declaration fixtures that prove ESM and CommonJS package consumers resolve the shipped types
affects: [phase-5-schema-adapters, phase-6-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - package-name smoke tests run against fresh `dist/` artifacts rather than source-file shortcuts
    - CommonJS declaration resolution is proven with `.cts` fixtures alongside ESM type fixtures
key-files:
  created:
    - ts/jqx/test/package_exports.test.ts
    - ts/jqx/test/package_typecheck.ts
    - ts/jqx/test/package_typecheck.cts
  modified:
    - scripts/ts_package_build.mjs
    - scripts/ts_packages.mjs
    - ts/jqx/package.json
    - ts/jqx/tsconfig.json
    - ts/jqx/README.md
key-decisions:
  - "The package build now repairs local package tools with `pnpm install --frozen-lockfile` when current-platform shims are missing, instead of assuming the last install OS matches the current execution OS."
  - "Package smoke tests and declaration fixtures now import `@shina1024/jqx` and `@shina1024/jqx/bind` by package name so TS-04 is proven against shipped artifacts, not source-module fallbacks."
patterns-established:
  - "If a package verification target depends on built artifacts, make the local test and typecheck scripts build `dist/` first."
  - "Use one ESM fixture and one `.cts` fixture when a package promises both import and require entrypoints."
requirements-completed: [TS-04, TS-05]
duration: 10 min
completed: 2026-03-14
---

# Phase 3 Plan 03: Package Artifact Verification Summary

**Self-repairing package builds plus artifact-level import and declaration proof for `@shina1024/jqx` and `@shina1024/jqx/bind`**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-14T14:16:52+09:00
- **Completed:** 2026-03-14T14:26:16+09:00
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Hardened the package build so `ts_package_build.mjs` can repair missing current-platform tool shims with `pnpm install --frozen-lockfile` before it tries to emit artifacts.
- Added package-name smoke tests and declaration fixtures that prove the shipped `@shina1024/jqx` and `@shina1024/jqx/bind` entrypoints resolve as ESM, CJS, and typed artifacts.
- Wired the artifact proof into the normal `pnpm test`, `pnpm typecheck`, and `ts_packages` verification flow so the documented gate now exercises built outputs instead of source-only shortcuts.

## Task Commits

Each task was committed atomically:

1. **Task 1: Make the JS package build and typecheck pipeline reliable on the maintained environments** - `7a58fde` (feat)
2. **Task 2: Add built-artifact smoke tests for runtime and bind entrypoints** - `3f9b517` (test)
3. **Task 3: Fold artifact proof into the documented TS package gate** - `cf53996` (chore)

## Files Created/Modified

- `scripts/ts_package_build.mjs` - repairs missing package-tool shims before building artifacts.
- `scripts/ts_packages.mjs` - builds packages before the cross-package verification steps so artifact checks run against fresh outputs.
- `ts/jqx/package.json` - makes local `test` and `typecheck` build `dist/` before running artifact-level checks.
- `ts/jqx/tsconfig.json` - includes `.cts` declaration fixtures in package typecheck.
- `ts/jqx/README.md` - documents that local package checks now run against built entrypoints.
- `ts/jqx/test/package_exports.test.ts` - smoke-tests export-map targets and package-name import/require resolution.
- `ts/jqx/test/package_typecheck.ts` - proves ESM consumers resolve the shipped package declarations.
- `ts/jqx/test/package_typecheck.cts` - proves CommonJS consumers resolve the shipped package declarations.

## Decisions Made

- Treated cross-OS package installs as a routine environment reality that the build script must repair, not as a manual prerequisite hidden outside the package workflow.
- Promoted artifact-level package-name proof into the normal TS gate so release-facing regressions fail in everyday verification, not only in ad hoc release dry runs.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first CommonJS declaration fixture used ESM import syntax inside a `.cts` file. It was rewritten to use typed CommonJS assignments so the fixture itself matched the consumer mode it was meant to prove.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 3 is now exitable: direct runtime, compiled runtime, `/bind`, and package artifacts are all proven through the documented TS verification path.
- Phase 5 can build adapter hardening work on a stable, artifact-verified JS/TS runtime package.
- Phase 6 can focus on release dry runs and final docs instead of discovering first-order JS/TS packaging gaps.

## Self-Check: PASSED

- `pnpm build`, `pnpm typecheck`, and `pnpm test` passed in `ts/jqx`.
- `bash ./scripts/ts_packages.sh verify --frozen-lockfile` passed from the repo root.
- Package-name ESM, CJS, and declaration fixtures now run against fresh `dist/` artifacts.

---
*Phase: 03-js-ts-runtime-surface*
*Completed: 2026-03-14*
