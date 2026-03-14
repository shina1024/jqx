---
phase: 03-js-ts-runtime-surface
verified: 2026-03-14T05:27:45Z
status: passed
score: 4/4 must-haves verified
---

# Phase 3: JS/TS Runtime Surface Verification Report

**Phase Goal:** JS/TS users can use a canonical runtime and binding package that stays aligned with the MoonBit and CLI semantics.
**Verified:** 2026-03-14T05:27:45Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | JS/TS users can parse, validate, compile, and run filters from a small canonical runtime API. | ✓ VERIFIED | `ts/jqx/src/index.ts` now leads with `run`, `runJsonText`, `compile`, `parseJson`, and `isValidJson`. `ts/jqx/README.md` teaches `run(filter, input)` as the quick start, and `ts/jqx/test/direct_runtime.test.ts` proves those root entrypoints. |
| 2 | JS/TS users can execute compiled filters through separate structured-input and JSON-text methods. | ✓ VERIFIED | `ts/jqx/src/direct_runtime.ts` keeps `CompiledFilter.run(...)` and `CompiledFilter.runJsonText(...)` distinct, `ts/jqx/src/bind.ts` stays explicit about not exposing compiled filters, and `ts/jqx/test/direct_runtime.test.ts` plus `ts/jqx/test/typecheck.ts` cover both direct compiled lanes. |
| 3 | JS/TS users can import the documented runtime and binding entry points with working ESM, CJS, and declaration outputs. | ✓ VERIFIED | `ts/jqx/package.json` exports `.` and `./bind` from `dist/`, `ts/jqx/test/package_exports.test.ts` smoke-tests package-name `import` and `require`, and `ts/jqx/test/package_typecheck.ts` plus `ts/jqx/test/package_typecheck.cts` prove ESM and CommonJS declaration resolution after a fresh build. |
| 4 | Maintainers can reshape JS/TS public and helper APIs before versioning without drifting from shared semantics. | ✓ VERIFIED | `ts/jqx/src/runtime_shared.ts` centralizes the direct/bind lane helpers, keeping both surfaces aligned while still allowing runtime-surface cleanup. The Plan 01 and Plan 02 summaries document the root export cleanup and the explicit `/bind` boundary that removed accidental surface ambiguity without weakening shared behavior. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ts/jqx/src/index.ts` | Canonical root runtime exports | ✓ EXISTS + SUBSTANTIVE | Groups the direct runtime first and keeps query/integration helpers secondary. |
| `ts/jqx/src/direct_runtime.ts` | Direct runtime and compiled-filter implementation | ✓ EXISTS + SUBSTANTIVE | Exposes structured-input and JSON-text compiled execution over the MoonBit runtime. |
| `ts/jqx/src/bind.ts` | Explicit backend-binding surface | ✓ EXISTS + SUBSTANTIVE | Lifts JSON-text backends into value-lane and streaming helpers without adding compiled-filter methods. |
| `ts/jqx/package.json` | Observable package export contract | ✓ EXISTS + SUBSTANTIVE | Declares runtime, bind, and adapter subpaths that point at built `dist/` artifacts. |
| `scripts/ts_package_build.mjs` | Reproducible package build pipeline | ✓ EXISTS + SUBSTANTIVE | Builds ESM/CJS/declarations and repairs missing current-platform tool shims when needed. |
| `ts/jqx/test/package_exports.test.ts` | Artifact-level import/require smoke proof | ✓ EXISTS + SUBSTANTIVE | Verifies export-map files and package-name ESM/CJS resolution. |
| `ts/jqx/test/package_typecheck.ts` | ESM declaration proof | ✓ EXISTS + SUBSTANTIVE | Resolves the shipped package declarations through package-name imports. |
| `ts/jqx/test/package_typecheck.cts` | CommonJS declaration proof | ✓ EXISTS + SUBSTANTIVE | Resolves the shipped package declarations through CommonJS consumer syntax. |

**Artifacts:** 8/8 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ts/jqx/src/index.ts` | `ts/jqx/src/direct_runtime.ts` | Root package routes users through the canonical direct runtime | ✓ WIRED | The root export block now leads with the direct runtime entrypoints rather than a mixed barrel. |
| `ts/jqx/src/direct_runtime.ts` | `ts/jqx/src/bind.ts` | Shared helper path keeps direct and bound lane behavior aligned | ✓ WIRED | Both surfaces use `ts/jqx/src/runtime_shared.ts` for value-lane encoding, output decoding, error normalization, and typed-query normalization. |
| `ts/jqx/package.json` | `ts/jqx/test/package_exports.test.ts` | Export map is checked against built files and package-name resolution | ✓ WIRED | The package smoke test reads the export map and verifies `.`/`./bind` plus adapter subpaths against `dist/`. |
| `scripts/ts_packages.mjs` | `ts/jqx/package.json` | Cross-package TS verification now exercises fresh built artifacts | ✓ WIRED | The `verify` flow builds packages before running lint, typecheck, and tests, and the `ts/jqx` scripts themselves build `dist/` before the package-name fixtures run. |

**Wiring:** 4/4 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| `TS-01`: small canonical runtime API from `@shina1024/jqx` | ✓ SATISFIED | - |
| `TS-02`: compiled-filter methods for structured inputs | ✓ SATISFIED | - |
| `TS-03`: compiled-filter methods for JSON text inputs | ✓ SATISFIED | - |
| `TS-04`: documented runtime and binding entry points import as ESM, CJS, and types | ✓ SATISFIED | - |
| `TS-05`: JS/TS public and helper APIs can be reshaped before versioning for clarity | ✓ SATISFIED | - |

**Coverage:** 5/5 requirements satisfied

## Anti-Patterns Found

None found during phase verification.

## Human Verification Required

None. The runtime-first API shape, compiled-lane separation, `/bind` scope, and package artifact proof were all verified through source inspection plus the documented TS verification commands.

## Local Environment Notes

- Local `ts/jqx` verification passed for `pnpm build`, `pnpm typecheck`, and `pnpm test`.
- Full cross-package verification passed for `bash ./scripts/ts_packages.sh verify --frozen-lockfile`.
- The build script now self-repairs missing current-platform tool shims after cross-OS installs, which removed the Windows-specific package-build failure that initially blocked artifact proof.

## Gaps Summary

**No gaps found.** Phase goal achieved. Ready to proceed.

## Verification Metadata

**Verification approach:** Goal-backward, derived from the Phase 3 goal and success criteria in `.planning/ROADMAP.md`
**Must-haves source:** Phase 3 success criteria and requirements mapping in `.planning/ROADMAP.md`
**Automated checks:** 4 passed, 0 failed
**Human checks required:** 0
**Implementation commits reviewed:** `2bac586` through `cf53996`
**Total verification time:** ~10 min local review plus full TS package gate

---
*Verified: 2026-03-14T05:27:45Z*
*Verifier: Codex*
