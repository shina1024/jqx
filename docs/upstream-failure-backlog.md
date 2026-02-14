# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-14

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 506
- failed: 171
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `output-mismatch` | 131 | evaluator semantics differences (streaming behavior, error propagation, numeric semantics, key order policy) |
| `unknown-function` | 21 | builtin/function coverage gaps |
| `runtime-error-vs-jq-success` | 11 | jqx runtime errors where jq succeeds |
| `unknown-variable` | 8 | variable binding/scoping coverage gaps |
| `parser-invalid-character` | 0 | resolved in current baseline |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

| Function | Count |
| --- | ---: |
| `splits` | 6 |
| `combinations` | 2 |
| `fromdate` | 2 |
| `fromstream` | 2 |
| `IN` | 2 |
| `pow` | 2 |
| `env` | 1 |
| `fabs` | 1 |
| `INDEX` | 1 |
| `split` | 1 |
| `truncate_stream` | 1 |

## Latest Progress

- Parser invalid-character cluster has been reduced to `0` in full upstream diff.
- Local `def` parsing was expanded:
  - `def` in nested/local expression positions (`|`/`,`/括弧/配列要素内) is parsed.
  - nested `def` semicolon scanning was fixed for definition-body extraction.
  - name resolution now prefers matching arity.
- Differential smoke cases were expanded from 180 to 185 (additional `def`-focused cases).
- Upstream stage1 subset was expanded from 84 to 92 passing cases.

## Priority Plan

1. Triage `output-mismatch` (`131`) by subcategory:
   - intentional policy differences (e.g. object key order)
   - real behavioral regressions (streaming/error semantics).
2. Reduce `unknown-function` (`21`) with focus on `splits`, `fromdate`, `fromstream`, `combinations`.
3. Continue `def` compatibility improvements (recursion and filter-argument semantics).
4. Keep expanding stage1 allowlist incrementally with newly stable cases.
