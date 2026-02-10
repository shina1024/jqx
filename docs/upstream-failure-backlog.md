# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-10

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 532
- failed: 145
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `parser-invalid-character` | 144 | parser grammar gaps (`[`, `{`, `$`, `,`, etc.) |
| `parser-invalid-number` | 1 | remaining unary/special numeric parse gap |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

| Function | Count |
| --- | ---: |
| (none) | 0 |

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
- Builtin/function pass 2 completed on 2026-02-10:
  - implemented `path`, `del`, and recursive descent (`..`) used by path expressions
  - upstream `path`/`del` runtime cases now mostly pass; remaining mismatches are tied to existing `try/catch` semantics and object key-order policy
- Unknown-function cluster reduced from 87 to 77 (`-10`) in upstream full diff.
- Builtin/function pass 3 completed on 2026-02-10:
  - implemented `have_decnum`, `abs`, `isempty`, `trimstr`, `trim`, `ltrim`, `rtrim`
  - unknown-function cluster reduced from 77 to 0 (`-77`) in upstream full diff
- Current remaining failures are parser-only (`Invalid character/number`: 145 total).

## Priority Plan

1. Parser cluster first: reduce `parser-invalid-character` + `parser-invalid-number` (145 total).
2. Re-run upstream full diff after each parser slice to surface newly unblocked non-parser gaps.
3. Expand stage1 allowlist incrementally with newly stable parser features.

## Representative Failing Cases

- Parser:
  - `upstream-jq-test-l118`
  - `upstream-jq-test-l122`
  - `upstream-jq-test-l273`
