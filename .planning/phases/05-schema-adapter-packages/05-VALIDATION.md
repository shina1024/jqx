---
phase: 5
slug: schema-adapter-packages
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 5 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Node test runner plus package-local `pnpm` scripts and TS package artifact verification |
| **Config file** | `ts/jqx/package.json`, `ts/adapter-core/package.json`, `ts/zod-adapter/package.json`, `ts/yup-adapter/package.json`, `ts/valibot-adapter/package.json` |
| **Quick run command** | `pnpm test` |
| **Full suite command** | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` |
| **Estimated runtime** | ~240 seconds |

---

## Sampling Rate

- **After every task commit:** Run package-local `pnpm test` in the touched TS package
- **After every plan wave:** Run `bash ./scripts/ts_packages.sh verify --frozen-lockfile`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 240 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | ADPT-01, ADPT-02, ADPT-03 | shared contract and issue-shape proof | `pnpm test && pnpm typecheck` | ✅ | ⬜ pending |
| 05-01-02 | 01 | 1 | ADPT-01, ADPT-02, ADPT-03 | root export-map and built-artifact proof | `pnpm build && pnpm test` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | ADPT-01, ADPT-02, ADPT-03 | adapter README and install/import contract | `pnpm test` | ✅ | ⬜ pending |
| 05-02-02 | 02 | 2 | ADPT-01, ADPT-02, ADPT-03 | full package verification | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] Root-package artifact verification in `ts/jqx` must be restored so `pnpm build && pnpm test` is runnable after export-map changes
- [ ] `ts/jqx/test/package_exports.test.ts` must be updated to prove the post-cleanup package boundary rather than the current root adapter subpaths
- [ ] Package refresh or build-path hardening may be required if the missing native binding under `ts_package_build.mjs` persists in this checkout

Current local finding:
- `pnpm test` passes in `ts/zod-adapter`
- `pnpm test` passes in `ts/yup-adapter`
- `pnpm test` passes in `ts/valibot-adapter`
- `pnpm test` fails in `ts/jqx` because `pnpm build` fails before tests with a missing native binding

If local `file:` dependencies need refresh while stabilizing package verification, use the documented dependency-order path:
- Windows: `./scripts/ts_packages.ps1 refresh`
- Linux/macOS: `bash ./scripts/ts_packages.sh refresh`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `@shina1024/jqx` reads as a runtime-only package after cleanup | ADPT-01, ADPT-02, ADPT-03 | A human should confirm the public story is no longer split between root subpaths and standalone adapters | Review `ts/jqx/package.json` and `ts/jqx/README.md`; confirm root exports only runtime surfaces and adapter docs point to standalone package names |
| Each adapter README starts with `createAdapter(runtime).filter(...)` and keeps query/infer secondary | ADPT-01, ADPT-02, ADPT-03 | Example ordering and narrative clarity need human judgment even when tests are green | Review `ts/zod-adapter/README.md`, `ts/yup-adapter/README.md`, and `ts/valibot-adapter/README.md`; confirm install/import examples use standalone package names and lead with filter-based usage |
| Yup and Valibot preserve structured native issue detail instead of collapsing to `string[]` | ADPT-02, ADPT-03 | Human review is needed to ensure richer issue payloads are genuinely preserved and documented, not merely renamed | Review `ts/yup-adapter/src/index.ts`, `ts/valibot-adapter/src/index.ts`, and their type fixtures; confirm `AdapterError` carries native issue arrays or an equally structured library-shaped payload |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 240s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
