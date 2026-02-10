# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-10

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 445
- failed: 232
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `output-mismatch` | 102 | evaluator semantics differences (streaming behavior, error propagation, numeric semantics, key order policy) |
| `parser-invalid-character` | 62 | parser grammar gaps (`(`, `{`, update path forms, interpolation, format prefix, etc.) |
| `unknown-function` | 56 | builtin/function coverage gaps |
| `runtime-error-vs-jq-success` | 6 | jqx runtime errors where jq succeeds |
| `unknown-variable` | 6 | variable binding/scoping coverage gaps |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

| Function | Count |
| --- | ---: |
| `splits` | 6 |
| `pick` | 5 |
| `builtins` | 4 |
| `nan` | 4 |
| `add` | 3 |
| `sqrt` | 3 |
| `modulemeta` | 3 |
| `infinite` | 3 |
| `floor` | 2 |
| `toboolean` | 2 |

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
- Parser pass 2 completed on 2026-02-10:
  - added `if/elif/else/end` parsing (including `else` omission as `empty`)
  - allowed postfix bracket access on general expressions (`$x[]`, `[1,2][]`, etc.)
  - parsed array/object literal values with full expression precedence (comparison/logical included)
  - fixed `. as $x` spacing ambiguity (`.as` field accessとの誤解釈を回避)
- Parser cluster reduced from 145 to 108 (`-37`) in upstream full diff.
- Parser pass 3 completed on 2026-02-10:
  - added `as` array/object pattern bindings with parser-lowering (no public AST change)
  - added `as ... ?// ...` destructuring fallback parsing/lowering via `try/catch`
  - supported object-pattern key forms: identifier/string/`$var` shorthand and `(<expr>): ...`
- Parser cluster reduced from 108 to 80 (`-28`) in upstream full diff.
- Parser pass 4 completed on 2026-02-10:
  - extended `reduce`/`foreach` to accept `as` array/object patterns in addition to `$var`
  - lowered non-`$var` loop patterns to existing AST via internal temporary binding + pattern destructuring
- Parser cluster reduced from 80 to 75 (`-5`) in upstream full diff.
- Parser pass 5 completed on 2026-02-10:
  - extended bracket index parsing to accept general expressions (`.[expr]`, `[...][$x]`, `.[1.1]`, `.[nan]` など)
  - added base-aware lowering for dynamic bracket access so key式は元入力コンテキストで評価
  - enabled general postfix field chaining on non-dot bases (`$ENV.PAGER`, `env.PAGER`)
- Parser cluster reduced from 75 to 60 (`-15`) in upstream full diff.
- Differential runner parity fix completed on 2026-02-10:
  - fixed `scripts/jq_diff.ps1` exit-code capture so PowerShell and bash results align
  - after parity fix, full upstream baseline is `445 pass / 232 fail / 147 skip` (not parser-only)

## Priority Plan

1. Parser cluster first: reduce `parser-invalid-character` (`62` total).
2. Unknown-function cluster next: implement top functions (`splits`, `pick`, numeric/time/meta helpers).
3. Triage `output-mismatch` (`102`) by subcategory:
   - intentional policy differences (e.g. object key order)
   - real behavioral regressions (streaming/error semantics).
4. Expand stage1 allowlist incrementally with newly stable parser/eval features.

## Representative Failing Cases

- Parser:
  - `upstream-jq-test-l118`
  - `upstream-jq-test-l122`
  - `upstream-jq-test-l478`
