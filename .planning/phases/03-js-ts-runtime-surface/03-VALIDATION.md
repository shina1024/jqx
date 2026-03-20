---
phase: 3
slug: js-ts-runtime-surface
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-14
---

# Phase 3 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node test runner plus built-artifact package smoke tests and TS declaration fixtures |
| **Config file** | `ts/jqx/package.json`, `ts/jqx/tsconfig.json`, `ts/jqx/tsconfig.build.json`, `scripts/ts_package_build.mjs` |
| **Quick run command** | `pnpm test` |
| **Full suite command** | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` |
| **Estimated runtime** | ~180 seconds |

---

## Sampling Rate

- **After every task commit:** Run `pnpm test`
- **After every plan wave:** Run `bash ./scripts/ts_packages.sh verify --frozen-lockfile`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | TS-01, TS-05 | runtime-surface | `pnpm test` | ✅ | ✅ green |
| 03-01-02 | 01 | 1 | TS-01 | docs+runtime | `pnpm test` | ✅ | ✅ green |
| 03-01-03 | 01 | 1 | TS-01, TS-05 | type-surface | `pnpm test` | ✅ | ✅ green |
| 03-02-01 | 02 | 2 | TS-02, TS-03, TS-05 | shared-lane internals | `pnpm test` | ✅ | ✅ green |
| 03-02-02 | 02 | 2 | TS-02, TS-03, TS-05 | compiled+bind contract | `pnpm test` | ✅ | ✅ green |
| 03-02-03 | 02 | 2 | TS-02, TS-03 | streaming+query contract | `pnpm test` | ✅ | ✅ green |
| 03-03-01 | 03 | 3 | TS-04 | build pipeline | `pnpm build && pnpm typecheck` | ✅ | ✅ green |
| 03-03-02 | 03 | 3 | TS-04 | artifact import smoke | `pnpm build && pnpm test` | ✅ | ✅ green |
| 03-03-03 | 03 | 3 | TS-04, TS-05 | full package verification | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

Already present and locally verified:
- `ts/jqx/test/package_exports.test.ts` proves package-name `import` / `require` against built artifacts.
- `ts/jqx/test/package_typecheck.ts` and `ts/jqx/test/package_typecheck.cts` prove shipped ESM and CommonJS declarations.
- `scripts/ts_package_build.mjs` repairs missing current-platform tool shims before `pnpm build` and `pnpm typecheck`.
- `bash ./scripts/ts_packages.sh verify --frozen-lockfile` passes across the TS workspace using fresh built artifacts.

Wave 0 is complete for this phase because the previously missing built-artifact smoke tests, declaration fixtures, and Windows-resilient build path are now present in the repository and verified by the current Phase 3 proof.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Root package still reads as a small runtime-first API | TS-01, TS-05 | Export order and README emphasis need human judgment even when tests are green | Review `ts/jqx/src/index.ts` and `ts/jqx/README.md`; confirm `run`, `runJsonText`, `compile`, `parseJson`, and `isValidJson` are the obvious first path, with query helpers and runtime objects clearly secondary |
| Package export map matches the documented public surface | TS-04 | A human should confirm the intended entrypoints are the only promoted ones before release | Review `ts/jqx/package.json`; confirm the canonical public entrypoints are `.` and `./bind`, and confirm removed root adapter subpaths stay absent rather than drifting back in |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 180s
- [x] `nyquist_compliant: true` set in frontmatter

Approval: approved
