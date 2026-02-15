# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-15

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 545
- failed: 132
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `output-mismatch` | 132 | evaluator semantics differences (streaming behavior, error propagation, numeric semantics, key order policy) |
| `runtime-error-vs-jq-success` | 0 | resolved in current baseline |
| `unknown-variable` | 0 | resolved in current baseline |
| `parser-invalid-character` | 0 | resolved in current baseline |
| `unknown-function` | 0 | resolved in current baseline |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

- none (cluster is `0`)

## Latest Progress

- Parser invalid-character cluster has been reduced to `0` in full upstream diff.
- Local `def` parsing was expanded:
  - `def` in nested/local expression positions (`|`/`,`/括弧/配列要素内) is parsed.
  - nested `def` semicolon scanning was fixed for definition-body extraction.
  - name resolution now prefers matching arity.
- Numeric builtin/call coverage expanded:
  - implemented `pow(2-arg)`, `fabs`, `log2`, and `round`.
  - full upstream unknown-function cluster reduced from `21` to `18`.
- `IN`/`INDEX` call coverage expanded:
  - implemented `IN(stream; stream)` and `INDEX(stream; index_expr)`.
  - full upstream unknown-function cluster reduced from `18` to `15`.
- Split/stream/date/environment/function coverage expanded:
  - implemented regex-aware `split(...; flags)` / `splits(...; flags)` (minimal `?/*/+`, `i`, `n`).
  - implemented `combinations`, `fromdate`, `env`, `tostream`, `fromstream`, `truncate_stream`.
  - full upstream unknown-function cluster reduced from `15` to `0`.
- Variable/scoping compatibility expanded:
  - fixed `as ... |` scope for comma-separated RHS.
  - fixed `?//` pattern fallback variable defaults (`null` initialization).
  - added special variables `$ENV` (minimal empty object) and `$__loc__` (minimal location object).
  - full upstream unknown-variable cluster reduced from `8` to `0`.
- Runtime error parity expanded:
  - implemented string-division compatibility (`string / string` as split behavior).
  - `abs` now matches jq for non-numeric scalar/container inputs (null/bool are still type errors).
  - `path()` evaluation now keeps variable-bound path state through `as` and dynamic `getpath`.
  - full upstream runtime-error-vs-jq-success cluster reduced from `10` to `0`.
- Differential smoke cases were expanded from 203 to 214.
- Upstream stage1 subset was expanded from 95 to 110 passing cases.

## Priority Plan

1. Triage `output-mismatch` (`132`) by subcategory:
   - intentional policy differences (e.g. object key order)
   - real behavioral regressions (streaming/error semantics).
2. Continue `def` compatibility improvements (recursion and filter-argument semantics).
3. Keep expanding stage1 allowlist incrementally with newly stable cases.
