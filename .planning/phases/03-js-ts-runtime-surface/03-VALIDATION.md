---
phase: 3
slug: js-ts-runtime-surface
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 3 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node test runner plus `pnpm` package scripts and MoonBit JS runtime build |
| **Config file** | `ts/jqx/package.json`, `ts/jqx/tsconfig.json`, `ts/jqx/tsconfig.build.json` |
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
| 03-01-01 | 01 | 1 | TS-01, TS-05 | runtime-surface | `pnpm test` | ✅ | ⬜ pending |
| 03-01-02 | 01 | 1 | TS-01 | docs+runtime | `pnpm test` | ✅ | ⬜ pending |
| 03-01-03 | 01 | 1 | TS-01, TS-05 | type-surface | `pnpm test` | ✅ | ⬜ pending |
| 03-02-01 | 02 | 2 | TS-02, TS-03, TS-05 | shared-lane internals | `pnpm test` | ✅ | ⬜ pending |
| 03-02-02 | 02 | 2 | TS-02, TS-03, TS-05 | compiled+bind contract | `pnpm test` | ✅ | ⬜ pending |
| 03-02-03 | 02 | 2 | TS-02, TS-03 | streaming+query contract | `pnpm test` | ✅ | ⬜ pending |
| 03-03-01 | 03 | 3 | TS-04 | build pipeline | `pnpm build && pnpm typecheck` | ❌ W0 | ⬜ pending |
| 03-03-02 | 03 | 3 | TS-04 | artifact import smoke | `pnpm build && pnpm test` | ❌ W0 | ⬜ pending |
| 03-03-03 | 03 | 3 | TS-04, TS-05 | full package verification | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `ts/jqx/test/package_exports.test.ts` or equivalent built-artifact smoke-test harness for package-name `import` / `require`
- [ ] `ts/jqx/test/package_typecheck.ts` or equivalent consumer fixtures for `d.ts` and `d.cts` resolution
- [ ] TS package tooling refreshed or hardened so `pnpm build` and `pnpm typecheck` run in the current Windows checkout; the present `node_modules/.bin` uses Unix-style shims only

Current local finding:
- `pnpm test` passes in `ts/jqx`
- `pnpm build` fails because `scripts/ts_package_build.mjs` looks for `esbuild.cmd`
- `pnpm typecheck` fails because `tsgo` is installed only as a Unix-style shim in this checkout

If local `file:` dependencies are refreshed as part of the fix, use the documented dependency-order path:
- Windows: `./scripts/ts_packages.ps1 refresh`
- Linux/macOS: `bash ./scripts/ts_packages.sh refresh`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Root package still reads as a small runtime-first API | TS-01, TS-05 | Export order and README emphasis need human judgment even when tests are green | Review `ts/jqx/src/index.ts` and `ts/jqx/README.md`; confirm `run`, `runJsonText`, `compile`, `parseJson`, and `isValidJson` are the obvious first path, with query helpers and runtime objects clearly secondary |
| Package export map matches the documented public surface | TS-04 | A human should confirm the intended entrypoints are the only promoted ones before release | Review `ts/jqx/package.json` after build, confirm `.` and `./bind` are correct, and verify any adapter subpaths remain intentional rather than accidental carry-over |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
