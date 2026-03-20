---
phase: 05-schema-adapter-packages
verified: 2026-03-20T07:46:23.8558531Z
status: passed
score: 6/6 must-haves verified
---

# Phase 05: Schema Adapter Packages Verification Report

**Phase Goal:** JS/TS users can apply schema adapters on top of the stable runtime surface without coupling adapters to internal runtime details.
**Verified:** 2026-03-20T07:46:23.8558531Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | JS/TS user can use the Zod adapter package to validate jqx runtime inputs and outputs. | ✓ VERIFIED | `ts/zod-adapter/src/index.ts` wires Zod validation into `runFilterWithValidation` / `runQueryWithValidation`; `ts/zod-adapter/README.md` teaches standalone usage; `ts/zod-adapter/test/index.test.ts` proves the package-name entrypoint. |
| 2 | JS/TS user can use the Yup adapter package to validate jqx runtime inputs and outputs. | ✓ VERIFIED | `ts/yup-adapter/src/index.ts` validates with Yup and returns `CoreAdapterError<yup.ValidationError[]>`; `ts/yup-adapter/test/index.test.ts` asserts structured `issues[0]`; `ts/yup-adapter/test/typecheck.ts` locks the public error type. |
| 3 | JS/TS user can use the Valibot adapter package to validate jqx runtime inputs and outputs. | ✓ VERIFIED | `ts/valibot-adapter/src/index.ts` validates with `safeParseAsync(...)` and returns `CoreAdapterError<v.BaseIssue<unknown>[]>`; `ts/valibot-adapter/test/index.test.ts` asserts structured `issues[0]`; `ts/valibot-adapter/test/typecheck.ts` locks the public error type. |
| 4 | `@shina1024/jqx` is a stable runtime-only package surface and standalone adapters are the canonical import path. | ✓ VERIFIED | `ts/jqx/package.json` exports only `.` and `./bind`; `ts/jqx/test/package_exports.test.ts` asserts removed `./zod`, `./yup`, and `./valibot` subpaths stay absent and package-name imports resolve only root and bind. |
| 5 | Adapter docs consistently teach `createAdapter(runtime).filter(...)` first and keep infer/query secondary. | ✓ VERIFIED | `ts/zod-adapter/README.md`, `ts/yup-adapter/README.md`, and `ts/valibot-adapter/README.md` all start Quick Start with `createAdapter(runtime).filter(...)`, then move `infer(...)` and query usage into secondary sections. |
| 6 | Adapter packages rely on stable runtime contracts instead of internal runtime details. | ✓ VERIFIED | `ts/jqx/README.md` states adapters depend on the stable `runtime` / `queryRuntime` contract; `ts/jqx/src/index.ts` re-exports those runtime objects and types; adapter source files import only `@shina1024/jqx-adapter-core`, not internal `ts/jqx/src/*` runtime modules. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `ts/jqx/package.json` | Root npm export map and dependency boundary | ✓ VERIFIED | Exists, 78 lines, exports only `.` and `./bind`, and `build` / `test` target only `src/index.ts` and `src/bind.ts`. |
| `ts/jqx/test/package_exports.test.ts` | Built-artifact proof that root exports remain runtime-only | ✓ VERIFIED | Exists, 57 lines, checks removed root adapter subpaths and package-name ESM/CJS imports. |
| `ts/adapter-core/src/index.ts` | Shared adapter contract types and runtime helpers | ✓ VERIFIED | Exists, 348 lines, defines `AdapterError`, `runtimeErrorToMessage`, `runFilterWithValidation`, and `runQueryWithValidation`; imported by root and all adapter packages. |
| `ts/zod-adapter/test/index.test.ts` | Standalone Zod package behavior and package-boundary proof | ✓ VERIFIED | Exists, 35 lines, imports `@shina1024/jqx-zod-adapter` by package name and runs shared contract cases. |
| `ts/yup-adapter/test/index.test.ts` | Standalone Yup package behavior and package-boundary proof | ✓ VERIFIED | Exists, 74 lines, imports `@shina1024/jqx-yup-adapter`, checks native issue objects, and runs shared contract cases. |
| `ts/valibot-adapter/test/index.test.ts` | Standalone Valibot package behavior and package-boundary proof | ✓ VERIFIED | Exists, 62 lines, imports `@shina1024/jqx-valibot-adapter`, checks native issue objects, and runs shared contract cases. |
| `ts/jqx/README.md` | Root runtime-first docs and adapter package references | ✓ VERIFIED | Exists, 127 lines, documents standalone adapter packages and the stable runtime contract. |
| `ts/zod-adapter/README.md` | Canonical Zod adapter install/import/example flow | ✓ VERIFIED | Exists, 67 lines, leads with standalone install and `createAdapter(runtime).filter(...)`. |
| `ts/yup-adapter/src/index.ts` | Yup issue preservation and adapter factory contract | ✓ VERIFIED | Exists, 106 lines, preserves `yup.ValidationError[]` and exposes `createAdapter` / `createQueryAdapter` over `JqxRuntime`. |
| `ts/yup-adapter/test/typecheck.ts` | Yup public type proof for richer adapter errors | ✓ VERIFIED | Exists, 133 lines, asserts `input_validation` and `output_validation` issues are `yup.ValidationError[]`. |
| `ts/valibot-adapter/src/index.ts` | Valibot issue preservation and adapter factory contract | ✓ VERIFIED | Exists, 104 lines, preserves `v.BaseIssue<unknown>[]` and exposes `createAdapter` / `createQueryAdapter` over `JqxRuntime`. |
| `ts/valibot-adapter/test/typecheck.ts` | Valibot public type proof for richer adapter errors | ✓ VERIFIED | Exists, 125 lines, asserts `input_validation` and `output_validation` issues are `v.BaseIssue<unknown>[]`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `ts/jqx/package.json` | `ts/jqx/test/package_exports.test.ts` | Runtime-only root exports plus package-name import tests | WIRED | `package.json` exports only `.` and `./bind`; `package_exports.test.ts` asserts removed adapter subpaths stay absent and imports root/bind by package name. |
| `ts/jqx/README.md` | `ts/*-adapter/README.md` | Standalone package names and runtime injection docs | WIRED | Root README names `@shina1024/jqx-zod-adapter`, `@shina1024/jqx-yup-adapter`, and `@shina1024/jqx-valibot-adapter`; each adapter README leads with `createAdapter(runtime).filter(...)`. |
| `ts/adapter-core/src/index.ts` | `ts/zod-adapter/src/index.ts` | Shared `CoreAdapterError` and validation runners | WIRED | Zod imports `runFilterWithValidation`, `runQueryWithValidation`, and `CoreAdapterError` from adapter-core. |
| `ts/adapter-core/src/index.ts` | `ts/yup-adapter/src/index.ts` | Shared `CoreAdapterError` and validation runners | WIRED | Yup imports the same shared helpers and keeps runtime handling in adapter-core. |
| `ts/adapter-core/src/index.ts` | `ts/valibot-adapter/src/index.ts` | Shared `CoreAdapterError` and validation runners | WIRED | Valibot imports the same shared helpers and keeps runtime handling in adapter-core. |
| `ts/yup-adapter/src/index.ts` | `ts/yup-adapter/test/typecheck.ts` | Public adapter error type proof | WIRED | Source exports `CoreAdapterError<yup.ValidationError[]>`; typecheck locks both validation branches to `yup.ValidationError[]`. |
| `ts/valibot-adapter/src/index.ts` | `ts/valibot-adapter/test/typecheck.ts` | Public adapter error type proof | WIRED | Source exports `CoreAdapterError<v.BaseIssue<unknown>[]>`; typecheck locks both validation branches to `v.BaseIssue<unknown>[]`. |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `ADPT-01` | `05-01`, `05-02` | JS/TS user can use the Zod adapter package to validate jqx runtime input and output contracts. | ✓ SATISFIED | `ts/zod-adapter/src/index.ts`, `ts/zod-adapter/README.md`, `ts/zod-adapter/test/index.test.ts`. |
| `ADPT-02` | `05-01`, `05-02` | JS/TS user can use the Yup adapter package to validate jqx runtime input and output contracts. | ✓ SATISFIED | `ts/yup-adapter/src/index.ts`, `ts/yup-adapter/README.md`, `ts/yup-adapter/test/index.test.ts`, `ts/yup-adapter/test/typecheck.ts`. |
| `ADPT-03` | `05-01`, `05-02` | JS/TS user can use the Valibot adapter package to validate jqx runtime input and output contracts. | ✓ SATISFIED | `ts/valibot-adapter/src/index.ts`, `ts/valibot-adapter/README.md`, `ts/valibot-adapter/test/index.test.ts`, `ts/valibot-adapter/test/typecheck.ts`. |

No orphaned Phase 5 requirements were found in `.planning/REQUIREMENTS.md`; the phase plans and requirements file both reference only `ADPT-01` through `ADPT-03`.

Supplementary prior verification evidence is present in the phase artifacts for `moon info`, `moon fmt`, `moon check`, `moon test`, `pnpm build && pnpm test` in `ts/jqx`, `pnpm test && pnpm typecheck` in each adapter package, and `bash ./scripts/ts_packages.sh verify --frozen-lockfile`. This report did not rely on those summaries alone; the repository still contains the export maps, scripts, docs, and tests that those commands were intended to verify.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `ts/jqx/package.json` | 4 | Package description still says "runtime and schema adapters" even though the export map is runtime-only. | ℹ️ Info | Public metadata lags behind the enforced package boundary, but exports, README, and tests all reflect the correct runtime-only root surface. |

### Human Verification Required

None identified for phase-goal verification. Optional release-phase smoke testing can still install each adapter package from a clean external consumer project, but the repository wiring for this phase is already in place and covered by package-name tests plus type fixtures.

### Gaps Summary

No goal-blocking gaps were found. The root package now presents a runtime-only surface, the three standalone adapter packages are the canonical public import paths, Yup and Valibot preserve validator-native issue detail under the shared jqx error shape, and the docs/tests all align around runtime injection rather than internal runtime coupling.

---

_Verified: 2026-03-20T07:46:23.8558531Z_
_Verifier: Codex (gsd-verifier)_
