# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-10

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 307
- failed: 370
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `parser-invalid-character` | 175 | parser grammar gaps (`[`, `{`, `$`, `,`, `%`, etc.) |
| `unknown-function` | 116 | builtin not implemented yet |
| `output-mismatch` | 59 | evaluator semantics mismatch |
| `parser-invalid-number` | 13 | numeric literal parsing gaps (`-...`) |
| `runtime-error-vs-jq-success` | 4 | behavior diverges (jq succeeds, jqx raises error) |
| `unknown-variable` | 3 | variable scope/binding mismatch |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

| Function | Count |
| --- | ---: |
| `range` | 26 |
| `have_decnum` | 7 |
| `abs` | 6 |
| `isempty` | 6 |
| `splits` | 6 |
| `pick` | 5 |
| `limit` | 5 |
| `path` | 4 |
| `nth` | 4 |
| `skip` | 4 |

## Priority Plan

1. Parser cluster first: reduce `parser-invalid-character` + `parser-invalid-number` (188 total).
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

