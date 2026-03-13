---
phase: 01-shared-core-and-compatibility
verified: 2026-03-13T17:18:48Z
status: passed
score: 4/4 must-haves verified
---

# Phase 1: Shared Core and Compatibility Verification Report

**Phase Goal:** Users can rely on one shared semantic core that matches `jq 1.8.1` and can be reorganized without creating surface-specific behavior.
**Verified:** 2026-03-13T17:18:48Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The maintained jq compatibility corpus matches `jq 1.8.1`, with exceptions explicit and removable rather than hidden. | ✓ VERIFIED | `scripts/jq_upstream_diff_ledger.md` now reports maintained `248/248` passing and `0` temporary exceptions. GitHub Actions run `23061502021` (`edca8c0`) completed successfully with `Differential Smoke (jq)`, `Differential Upstream Full (jq)`, and `Differential Native Exit (jq)` enabled in `.github/workflows/ci.yml`. |
| 2 | Compatibility-sensitive execution preserves JSON-text fidelity for large-number and raw-output-sensitive cases. | ✓ VERIFIED | Public and wrapper tests cover repr-sensitive lanes in `jqx_test.mbt` (`run_json_text preserves escaped strings and large-number repr`, `compiled filter run_json_text preserves order and repr-sensitive outputs`), `js/jqx_js_test.mbt` (`js run_json_text preserves large-number repr output`), and `core/execute_test.mbt` (`execute shared run lanes preserve ordering and repr-sensitive outputs`). Local `moon test`, `moon test --target js js`, and `bash ./scripts/jq_diff_native.sh` all passed during final verification. |
| 3 | Shared JSON semantics, including object key update order, are consistent across the shared core, MoonBit public API, and JS wrapper. | ✓ VERIFIED | Ordering-sensitive coverage exists in `jqx_test.mbt` (`run preserves public Json object order across updates`) and `js/jqx_js_test.mbt` (`js run_json_text preserves escaped strings and object order`, `js compiled lanes preserve ordering and repr-sensitive outputs`). The shared core keeps object update order in `core/jqx.mbt` via `JsonObject::set`. |
| 4 | Semantic ownership sits in one shared core, while surfaces stay thin adapters over that core. | ✓ VERIFIED | Shared execution lanes live in `core/jqx.mbt` (`run_compiled_values`, `run_values`, `run_json_text`), while the top-level MoonBit surface in `jqx.mbt` delegates to that core and exposes the public API. Phase 1 Plan 02 and Plan 03 summaries document the boundary refactor plus the cross-surface proof that exercises the same core behavior from MoonBit, JS, and CLI-oriented differential harnesses. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `core/jqx.mbt` | Shared semantic execution lanes and JSON fidelity helpers | ✓ EXISTS + SUBSTANTIVE | Contains object-order-preserving updates plus shared run helpers for value and JSON-text lanes. |
| `jqx.mbt` | Canonical MoonBit public runtime wrapper over the shared core | ✓ EXISTS + SUBSTANTIVE | Exposes `parse_json`, `is_valid_json`, `compile`, `run`, and `run_json_text` through the top-level package. |
| `jqx_test.mbt` | Public MoonBit fidelity and ordering proof | ✓ EXISTS + SUBSTANTIVE | Covers object order, escaped strings, large-number repr, and compiled filter text-lane behavior. |
| `js/jqx_js_test.mbt` | JS wrapper fidelity and ordering proof | ✓ EXISTS + SUBSTANTIVE | Covers direct and compiled execution lanes against the same repr-sensitive behavior. |
| `scripts/jq_upstream_diff_ledger.md` | Shared compatibility ledger for maintained and upstream corpora | ✓ EXISTS + SUBSTANTIVE | Reports `248/248` maintained and `843/843` upstream passing with no temporary exceptions or stale metadata. |
| `.github/workflows/ci.yml` | Phase 1 gate aligned to documented MoonBit, TS, and differential proof | ✓ EXISTS + SUBSTANTIVE | Runs `moon info -> moon fmt --check -> moon check -d -> moon test`, JS wrapper tests, TS verify with type-aware lint, and Linux native differential jobs. |

**Artifacts:** 6/6 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `jqx.mbt` | `core/jqx.mbt` | Public API delegation | ✓ WIRED | `run` and `run_json_text` delegate into `@core.run_values` / `@core.run_json_text` rather than reimplementing semantics at the surface. |
| `js/jqx_js_test.mbt` | shared core semantics | JS-target wrapper tests | ✓ WIRED | JS tests exercise repr-sensitive and ordering-sensitive behavior against the same MoonBit-produced runtime. |
| `.github/workflows/ci.yml` | `scripts/jq_diff.sh` / `scripts/jq_diff_native.sh` | Linux differential jobs with `JQX_RUNNER: native` | ✓ WIRED | CI uses native release binaries for maintained, upstream, and `-e` exit proof instead of a wrapper-only smoke path. |
| `scripts/ts_packages.mjs` | TS package quality gate | `lint:typeaware` invocation | ✓ WIRED | TS verification now includes type-aware oxlint in addition to `tsgo` typechecking and package build/test flow. |

**Wiring:** 4/4 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| `COMP-01`: maintained compatibility corpus matches `jq 1.8.1` | ✓ SATISFIED | - |
| `COMP-02`: known compatibility exceptions stay explicit, narrow, and removable | ✓ SATISFIED | - |
| `COMP-03`: compatibility-lane APIs preserve JSON-text fidelity | ✓ SATISFIED | - |
| `COMP-04`: shared JSON semantics and object key order stay consistent across surfaces | ✓ SATISFIED | - |
| `ARCH-01`: internal architecture can evolve toward a clearer shared-core design | ✓ SATISFIED | - |
| `ARCH-03`: one shared semantic core owns semantics across surfaces | ✓ SATISFIED | - |
| `ARCH-04`: package and module boundaries can be reorganized before versioning | ✓ SATISFIED | - |

**Coverage:** 7/7 requirements satisfied

## Anti-Patterns Found

None found during phase verification.

## Human Verification Required

None — all Phase 1 exit criteria were verified through code inspection, automated tests, differential harnesses, and CI evidence.

## Local Environment Notes

- Local final verification passed for `moon info`, `moon fmt --check`, `moon check -d`, `moon test`, `moon test --target js js`, `bash ./scripts/ts_packages.sh verify --frozen-lockfile`, and `bash ./scripts/jq_diff_native.sh`.
- `bash ./scripts/jq_diff.sh` was not used as the final local authority in this Windows/WSL-like environment because it previously timed out on the full shell differential path.
- `bash ./scripts/jq_upstream_ledger.sh --verify` still hits a local PowerShell `ConvertFrom-Json` issue in this environment, but the authoritative CI run succeeded with both maintained and upstream differential coverage enabled.

## Gaps Summary

**No gaps found.** Phase goal achieved. Ready to proceed.

## Verification Metadata

**Verification approach:** Goal-backward, derived from the Phase 1 goal and success criteria in `.planning/ROADMAP.md`
**Must-haves source:** Phase 1 success criteria and requirements mapping in `.planning/ROADMAP.md`
**Automated checks:** 8 passed, 0 failed
**Human checks required:** 0
**Authoritative CI evidence:** GitHub Actions `CI` run `23061502021` for commit `edca8c0`
**Total verification time:** ~3 min local rerun plus CI inspection

---
*Verified: 2026-03-13T17:18:48Z*
*Verifier: Codex*
