---
phase: 02-moonbit-public-api
verified: 2026-03-14T03:28:35Z
status: passed
score: 4/4 must-haves verified
---

# Phase 2: MoonBit Public API Verification Report

**Phase Goal:** MoonBit users get a small, idiomatic, canonical API for both value-lane and JSON-text execution without leaking internal types.
**Verified:** 2026-03-14T03:28:35Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | MoonBit users can parse, validate, compile, and run filters from a small canonical top-level API. | ✓ VERIFIED | `jqx.mbt` and `pkg.generated.mbti` expose `parse_json`, `is_valid_json`, `compile`, `run`, and `run_json_text`. `README.mbt.md` now teaches `run(filter, input)` as the normal path. |
| 2 | MoonBit users can reuse compiled filters through clear value-lane and JSON-text methods. | ✓ VERIFIED | `CompiledFilter::run(Self, Json)` and `CompiledFilter::run_json_text(Self, StringView, ...)` are both present in `pkg.generated.mbti`, and `jqx_test.mbt` covers both paths including repr-sensitive compatibility-lane behavior. |
| 3 | Normal MoonBit users do not need `@core.Value` or `@core.Filter` to consume the public package. | ✓ VERIFIED | `pkg.generated.mbti` exposes an opaque `CompiledFilter` with no public `@core.Filter` field and no `@core.Value`-typed public API. `README.mbt.md` explicitly keeps normal usage on `shina1024/jqx`. |
| 4 | The public surface can be reshaped before versioning to reduce API debt without weakening the shared-core contract. | ✓ VERIFIED | The old broad `JqxError` public contract has been removed from `pkg.generated.mbti` and replaced by `RunError`, `JsonTextRunError`, and `CompiledJsonTextRunError`, while shared semantics still delegate into `core` through `jqx.mbt`. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `jqx.mbt` | Canonical top-level MoonBit runtime wrapper | ✓ EXISTS + SUBSTANTIVE | Exposes the stable top-level entrypoints and raises narrower entrypoint-shaped error contracts. |
| `jqx_public_types.mbt` | Public error and opaque compiled-filter boundary | ✓ EXISTS + SUBSTANTIVE | Defines `RunError`, `JsonTextRunError`, `CompiledJsonTextRunError`, and the opaque `CompiledFilter`. |
| `jqx_test.mbt` | Top-level MoonBit proof for direct and compiled lanes | ✓ EXISTS + SUBSTANTIVE | Covers direct run, compiled run, compatibility-lane fidelity, and the narrowed public error mapping. |
| `README.mbt.md` | MoonBit-facing docs aligned to the canonical lane ordering | ✓ EXISTS + SUBSTANTIVE | Teaches value lane first, compiled reuse second, compatibility lane third, and keeps users off `core`. |
| `pkg.generated.mbti` | Generated proof of the public MoonBit contract | ✓ EXISTS + SUBSTANTIVE | Confirms the public API no longer exposes `JqxError` and keeps the `CompiledFilter` boundary opaque. |

**Artifacts:** 5/5 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `jqx.mbt` | `jqx_public_types.mbt` | Top-level run entrypoints raise narrowed public errors | ✓ WIRED | `run` raises `RunError`, `run_json_text` raises `JsonTextRunError`, and compiled text execution raises `CompiledJsonTextRunError`. |
| `jqx.mbt` | `core/jqx.mbt` | Public API remains a thin wrapper over the shared core | ✓ WIRED | `parse_json`, `compile`, `CompiledFilter::run`, and `CompiledFilter::run_json_text` all delegate into `@core` helpers rather than reimplementing semantics. |
| `jqx_test.mbt` | `jqx.mbt` | Top-level tests prove the public API instead of `core`-only helpers | ✓ WIRED | Tests exercise direct `run`, compiled `run`, `run_json_text`, and compiled `run_json_text` from the top-level package. |
| `README.mbt.md` | `pkg.generated.mbti` | Docs and generated contract reinforce the same public boundary | ✓ WIRED | README examples and boundary guidance match the names and lane separation present in the generated public API. |

**Wiring:** 4/4 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| `ARCH-02`: internal or public API structure can change before versioning to reduce debt | ✓ SATISFIED | - |
| `MBT-01`: small canonical top-level runtime API from `shina1024/jqx` | ✓ SATISFIED | - |
| `MBT-02`: compiled-filter methods for the value lane | ✓ SATISFIED | - |
| `MBT-03`: compiled-filter methods for the JSON-text compatibility lane | ✓ SATISFIED | - |
| `MBT-04`: public API usable without `@core.Value` | ✓ SATISFIED | - |
| `MBT-05`: MoonBit public APIs can be renamed/restructured before versioning for clarity | ✓ SATISFIED | - |

**Coverage:** 6/6 requirements satisfied

## Anti-Patterns Found

None found during phase verification.

## Human Verification Required

None — the phase exit criteria were verified through source inspection, generated contract review, docs review, and the MoonBit quality gate.

## Local Environment Notes

- Local verification passed for `moon info`, `moon fmt`, `moon check -d`, and `moon test`.
- The helper checker subagent could not read local files in this Windows environment because of a sandbox backend mismatch, so final phase verification was completed directly in the main session.

## Gaps Summary

**No gaps found.** Phase goal achieved. Ready to proceed.

## Verification Metadata

**Verification approach:** Goal-backward, derived from the Phase 2 goal and success criteria in `.planning/ROADMAP.md`
**Must-haves source:** Phase 2 success criteria and requirements mapping in `.planning/ROADMAP.md`
**Automated checks:** 4 passed, 0 failed
**Human checks required:** 0
**Implementation commits reviewed:** `ec677f4`, `80df341`
**Total verification time:** ~10 min local review plus MoonBit gate

---
*Verified: 2026-03-14T03:28:35Z*
*Verifier: Codex*
