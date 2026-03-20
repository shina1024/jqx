---
phase: 04-cli-workflow-parity
verified: 2026-03-20T14:50:18+09:00
status: passed
score: 3/3 must-haves verified
---

# Phase 4: CLI Workflow Parity Verification Report

**Phase Goal:** CLI users can complete the common jq workflows against the same shared core used by the library surfaces.
**Verified:** 2026-03-20T14:50:18+09:00
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CLI users can execute jq-compatible filters against JSON from stdin and direct input arguments through the public CLI. | ✓ VERIFIED | `cmd/main_cli.mbt` now presents `jqx` as the canonical command, `cmd/main.mbt` keeps stdin vs direct-input normalization in `parse_cli_inputs(...)`, `cmd/main_wbtest.mbt` covers direct-input precedence and raw direct-input slurp, and the maintained corpus includes `cli-direct-input-raw-string-output` plus `cli-direct-input-raw-slurp`. |
| 2 | CLI users can use `-r`, `-R`, `-s`, `-n`, and `-e` with jq-compatible behavior. | ✓ VERIFIED | `moon test` passed the focused CLI wbtests, `node scripts/jq_diff.mjs` passed all `252` maintained strict jq comparisons including raw/slurp and runtime-error cases, and `node scripts/jq_diff.mjs scripts/jq_exit_cases.json` passed all `9` dedicated `-e` status cases. |
| 3 | CLI behavior still comes from the shared semantic core rather than surface-local semantic patches. | ✓ VERIFIED | `cmd/main_cli.mbt` still compiles via `@lib.compile(cfg.filter)` and executes via `@lib.execute_for_cli(compiled, input)`, while CLI-specific transport behavior remains in `cmd/main.mbt` and proof stays aligned across `cmd/main_wbtest.mbt`, `cmd/main_native_wbtest.mbt`, and the maintained jq differential runner. |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `cmd/main_cli.mbt` | Public jqx-first CLI usage and shared-core execution wiring | ✓ EXISTS + SUBSTANTIVE | Presents the canonical `jqx` command identity while still delegating compile and execute to the shared core. |
| `cmd/main.mbt` | CLI-side input normalization for stdin, direct input, raw mode, and slurp | ✓ EXISTS + SUBSTANTIVE | Owns stream segmentation and raw/slurp handling without moving jq semantics out of the shared core. |
| `cmd/main_wbtest.mbt` | Focused CLI regression proof for the maintained workflow story | ✓ EXISTS + SUBSTANTIVE | Covers jqx usage, direct-input precedence, raw direct-input slurp, raw string output, compile errors, and runtime-error output ordering. |
| `cmd/main_native_wbtest.mbt` | Native-only module-path CLI proof | ✓ EXISTS + SUBSTANTIVE | Verifies `-L` module loading against the same jqx command identity used by the maintained corpus. |
| `scripts/jq_compat_cases.json` | Maintained strict jq differential corpus for CLI workflows | ✓ EXISTS + SUBSTANTIVE | Includes explicit Phase 4 cases for direct-input raw output, raw slurp, module-path imports, runtime-error output ordering, and `-e`-sensitive CLI workflows. |
| `scripts/jq_exit_cases.json` | Dedicated exit-status parity corpus | ✓ EXISTS + SUBSTANTIVE | Continues to prove jq-compatible `-e` behavior without adding relaxed comparisons or skips. |
| `scripts/jq_diff.mjs` | Exact stdout/stderr/status differential runner | ✓ EXISTS + SUBSTANTIVE | Uses the profile-aware native runner and preserves strict stdout, stderr, and exit-status comparison. |

**Artifacts:** 7/7 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `cmd/main_cli.mbt` | `cmd/main.mbt` | CLI entrypoint normalizes stdin/direct input through `parse_cli_inputs(...)` before execution | ✓ WIRED | `run_cli(...)` parses CLI args, normalizes inputs in `cmd`, then passes shared-core values forward for execution. |
| `cmd/main_cli.mbt` | shared core | CLI delegates compile and execute through the canonical core entrypoints | ✓ WIRED | `run_cli(...)` still uses `@lib.compile(cfg.filter)` and `@lib.execute_for_cli(compiled, input)` instead of surface-local semantic branches. |
| `scripts/jq_diff.mjs` | `scripts/jq_compat_cases.json` / `scripts/jq_exit_cases.json` | Maintained jq corpora drive exact stdout/stderr/status comparison | ✓ WIRED | The runner keeps strict output and exit-status comparison for both the main maintained CLI corpus and the dedicated `-e` exit corpus. |
| `cmd/main_native_wbtest.mbt` | `cmd/main_cli.mbt` | Native wbtests pin the same module-path CLI workflow exercised by the maintained corpus | ✓ WIRED | The native-only test uses `run_cli(...)` with `-L` and `import "a"` to mirror the maintained `cli-module-search-path-import` case. |

**Wiring:** 4/4 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| `CLI-01`: stdin and direct-input execution through the CLI | ✓ SATISFIED | - |
| `CLI-02`: common jq options `-r`, `-R`, `-s`, `-n`, and `-e` behave compatibly | ✓ SATISFIED | - |

**Coverage:** 2/2 requirements satisfied

## Anti-Patterns Found

None found during phase verification.

## Human Verification Required

None. The user-facing jqx command wording, shared-core delegation path, and CLI parity proof were all verified through source inspection plus the documented automated checks.

## Local Environment Notes

- Local verification passed for `moon info`, `moon fmt`, `moon check`, `moon test`, `moon test --target js js`, `node scripts/jq_diff.mjs`, and `node scripts/jq_diff.mjs scripts/jq_exit_cases.json`.
- Cross-phase regression proof also passed for `bash ./scripts/ts_packages.sh verify --frozen-lockfile`.
- `node scripts/jq_diff.mjs` ran the native jqx differential path with strict stdout, stderr, and exit-status comparison, which covers the packaged CLI story more directly than a wrapper-only `moon run` flow.

## Gaps Summary

**No gaps found.** Phase goal achieved. Ready to proceed.

## Verification Metadata

**Verification approach:** Goal-backward, derived from the Phase 4 goal and success criteria in `.planning/ROADMAP.md`
**Must-haves source:** Phase 4 success criteria and requirements mapping in `.planning/ROADMAP.md`
**Automated checks:** 8 passed, 0 failed
**Human checks required:** 0
**Implementation commits reviewed:** `4dba761`, `052bef3`, `ec16c3d`, `a45db26`
**Total verification time:** ~10 min local verification plus TS regression gate

---
*Verified: 2026-03-20T14:50:18+09:00*
*Verifier: Codex*
