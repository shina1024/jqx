---
phase: 5
slug: schema-adapter-packages
status: complete
nyquist_compliant: true
wave_0_complete: true
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
| 05-01-01 | 01 | 1 | ADPT-01, ADPT-02, ADPT-03 | shared contract and issue-shape proof | `pnpm test && pnpm typecheck` | ✅ | ✅ green |
| 05-01-02 | 01 | 1 | ADPT-01, ADPT-02, ADPT-03 | root export-map and built-artifact proof | `pnpm build && pnpm test` | ✅ | ✅ green |
| 05-02-01 | 02 | 2 | ADPT-01, ADPT-02, ADPT-03 | adapter README and install/import contract | `pnpm test` | ✅ | ✅ green |
| 05-02-02 | 02 | 2 | ADPT-01, ADPT-02, ADPT-03 | full package verification | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

Already present and locally verified:
- `ts/jqx/package.json` exports only `.` and `./bind`, keeping the root npm surface runtime-only.
- `ts/jqx/test/package_exports.test.ts` proves removed root adapter subpaths stay absent and package-name imports resolve through the built root and bind entrypoints only.
- `ts/zod-adapter/test/index.test.ts`, `ts/yup-adapter/test/index.test.ts`, and `ts/valibot-adapter/test/index.test.ts` prove standalone package-name imports.
- `ts/yup-adapter/test/typecheck.ts` and `ts/valibot-adapter/test/typecheck.ts` prove richer validator-native issue payloads.
- `bash ./scripts/ts_packages.sh verify --frozen-lockfile` passes across `ts/adapter-core`, `ts/jqx`, and all standalone adapter packages.

Wave 0 is complete for this phase because the root package boundary, built-artifact proof, standalone adapter package proof, and richer issue-shape type fixtures are all now present and verified.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `@shina1024/jqx` reads as a runtime-only package after cleanup | ADPT-01, ADPT-02, ADPT-03 | A human should confirm the public story is no longer split between root subpaths and standalone adapters | Review `ts/jqx/package.json` and `ts/jqx/README.md`; confirm root exports only runtime surfaces and adapter docs point to standalone package names |
| Each adapter README starts with `createAdapter(runtime).filter(...)` and keeps query/infer secondary | ADPT-01, ADPT-02, ADPT-03 | Example ordering and narrative clarity need human judgment even when tests are green | Review `ts/zod-adapter/README.md`, `ts/yup-adapter/README.md`, and `ts/valibot-adapter/README.md`; confirm install/import examples use standalone package names and lead with filter-based usage |
| Yup and Valibot preserve structured native issue detail instead of collapsing to `string[]` | ADPT-02, ADPT-03 | Human review is needed to ensure richer issue payloads are genuinely preserved and documented, not merely renamed | Review `ts/yup-adapter/src/index.ts`, `ts/valibot-adapter/src/index.ts`, and their type fixtures; confirm `AdapterError` carries native issue arrays or an equally structured library-shaped payload |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 240s
- [x] `nyquist_compliant: true` set in frontmatter

Approval: approved
