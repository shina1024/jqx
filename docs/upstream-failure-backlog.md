# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-14

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 527
- failed: 150
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `output-mismatch` | 131 | evaluator semantics differences (streaming behavior, error propagation, numeric semantics, key order policy) |
| `runtime-error-vs-jq-success` | 11 | jqx runtime errors where jq succeeds |
| `unknown-variable` | 8 | variable binding/scoping coverage gaps |
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
- Differential smoke cases were expanded from 190 to 199.
- Upstream stage1 subset was expanded from 95 to 110 passing cases.

## Priority Plan

1. Triage `output-mismatch` (`131`) by subcategory:
   - intentional policy differences (e.g. object key order)
   - real behavioral regressions (streaming/error semantics).
2. Reduce `runtime-error-vs-jq-success` (`11`) and `unknown-variable` (`8`).
3. Continue `def` compatibility improvements (recursion and filter-argument semantics).
4. Keep expanding stage1 allowlist incrementally with newly stable cases.
