# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-10

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 326
- failed: 351
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `parser-invalid-character` | 146 | parser grammar gaps (`[`, `{`, `$`, `,`, etc.) |
| `unknown-function` | 127 | builtin not implemented yet |
| `output-mismatch` | 70 | evaluator semantics mismatch |
| `runtime-error-vs-jq-success` | 4 | behavior diverges (jq succeeds, jqx raises error) |
| `unknown-variable` | 3 | variable scope/binding mismatch |
| `parser-invalid-number` | 1 | remaining unary/special numeric parse gap |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

| Function | Count |
| --- | ---: |
| `range` | 28 |
| `have_decnum` | 9 |
| `splits` | 6 |
| `abs` | 6 |
| `isempty` | 6 |
| `pick` | 5 |
| `limit` | 5 |
| `del` | 5 |
| `path` | 5 |
| `nth` | 4 |
| `skip` | 4 |

## Latest Progress

- Parser pass 1 completed on 2026-02-10:
  - accepted `=` assignment in addition to `|=` family
  - added `%`/`%=` and unary minus for non-literal operands
  - added `."quoted"` field syntax
  - added `foreach` two-clause form (`extract` defaults to identity)
  - added object-literal shorthand keys (`{a, "b"}`)
  - added multi-index bracket form (`.[1,2]`, `.[\"a\", \"b\"]`)
- Parser cluster reduced from 188 to 147 (`-41`) in upstream full diff.

## Priority Plan

1. Parser cluster first: reduce `parser-invalid-character` + `parser-invalid-number` (147 total).
2. Builtin cluster second: implement high-frequency unknown functions (`range`, `limit`, `skip`, `path`, `del`).
3. Semantics cluster third: resolve high-impact `output-mismatch` cases.
4. Remaining runtime/variable gaps.

## Representative Failing Cases

- Parser:
  - `upstream-jq-test-l118`
  - `upstream-jq-test-l122`
  - `upstream-jq-test-l168`
- Unknown functions:
  - `upstream-jq-test-l287` (`range`)
  - `upstream-jq-test-l361` (`limit`)
  - `upstream-jq-test-l474` (`del`)
- Semantics mismatch:
  - `upstream-jq-test-l187`
  - `upstream-jq-test-l200`
  - `upstream-jq-test-l205`
