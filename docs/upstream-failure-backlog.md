# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-10

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 361
- failed: 316
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `parser-invalid-character` | 146 | parser grammar gaps (`[`, `{`, `$`, `,`, etc.) |
| `unknown-function` | 87 | builtin not implemented yet |
| `output-mismatch` | 75 | evaluator semantics mismatch |
| `runtime-error-vs-jq-success` | 4 | behavior diverges (jq succeeds, jqx raises error) |
| `unknown-variable` | 3 | variable scope/binding mismatch |
| `parser-invalid-number` | 1 | remaining unary/special numeric parse gap |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

| Function | Count |
| --- | ---: |
| `have_decnum` | 9 |
| `splits` | 6 |
| `abs` | 6 |
| `isempty` | 6 |
| `path` | 5 |
| `pick` | 5 |
| `del` | 5 |
| `sqrt` | 3 |
| `add` | 3 |
| `infinite` | 3 |
| `trimstr` | 3 |

## Latest Progress

- Parser pass 1 completed on 2026-02-10:
  - accepted `=` assignment in addition to `|=` family
  - added `%`/`%=` and unary minus for non-literal operands
  - added `."quoted"` field syntax
  - added `foreach` two-clause form (`extract` defaults to identity)
  - added object-literal shorthand keys (`{a, "b"}`)
  - added multi-index bracket form (`.[1,2]`, `.[\"a\", \"b\"]`)
- Parser cluster reduced from 188 to 147 (`-41`) in upstream full diff.
- Builtin/function pass 1 completed on 2026-02-10:
  - implemented `range`, `limit`, `skip`, `IN`, and stream-form `nth(i; expr)`
  - added lazy-prefix evaluation for stream consumers (`first`, `limit`, `nth`) to avoid unnecessary tail evaluation
- Unknown-function cluster reduced from 127 to 87 (`-40`) in upstream full diff.

## Priority Plan

1. Parser cluster first: reduce `parser-invalid-character` + `parser-invalid-number` (147 total).
2. Builtin cluster second: implement remaining high-frequency unknown functions (`have_decnum`, `splits`, `abs`, `isempty`, `path`, `del`).
3. Semantics cluster third: resolve high-impact `output-mismatch` cases.
4. Remaining runtime/variable gaps.

## Representative Failing Cases

- Parser:
  - `upstream-jq-test-l118`
  - `upstream-jq-test-l122`
  - `upstream-jq-test-l168`
- Unknown functions:
  - `upstream-jq-test-l1101` (`path`)
  - `upstream-man-test-l879` (`isempty`)
  - `upstream-jq-test-l474` (`del`)
- Semantics mismatch:
  - `upstream-jq-test-l187`
  - `upstream-jq-test-l200`
  - `upstream-jq-test-l205`
