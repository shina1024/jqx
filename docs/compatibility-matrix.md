# jqx Compatibility Matrix (Baseline)

Updated: 2026-02-21

Scope:
- Target compatibility: jq 1.7 behavior
- Differential baseline used in this repo: jq 1.8.1 (local)
- Source of truth for behavior: `core/parser.mbt`, `core/execute.mbt`, `core/builtin*.mbt`

Policy:
- Aim for full jq compatibility (eventual zero-skip upstream differential).
- Do not relax compatibility checks by default (no ad-hoc skip widening or permissive error matching).
- When a temporary exception is unavoidable, document scope and removal condition explicitly.

Legend:
- `supported`: implemented and covered by tests
- `partial`: implemented with known differences
- `planned`: not implemented yet

## Core Language

| Area | Status | Notes |
| --- | --- | --- |
| Identity / field / index / iter / recurse | supported | `.`, `.foo`, `.[n]`, `.[]`, `..`, optional forms |
| Slice | supported | `.[start:end]`, optional form |
| Pipe / comma | supported | stream composition |
| Literals | supported | number/string/bool/null, array/object literals |
| Variables | supported | `.expr as $x | ...`, `$x` |
| Error control | supported | `expr?`, `try ... catch ...` |
| Control flow | supported | `if ... then ... else ... end`, `empty`, `//` |
| Reduce / foreach | supported | minimal stream semantics |
| Arithmetic / compare / logic | supported | `+ - * / %`, `== != < <= > >=`, `and or not` |
| User-defined functions (`def`) | partial | local/nested `def` + arity-aware runtime resolution; recursion and filter-arg closure capture are implemented for upstream-covered cases (including `jq.test:789/864/880`, `man.test:945/952`). Remaining edge semantics outside current differential coverage are tracked incrementally |
| Labels / break | partial | `label $name | ...` と `break $name` の最小互換を実装（upstream `jq.test:315/319/333/2251` を通過）。追加の網羅ケースは継続 |
| Module system (`import`/`include`) | partial | 実モジュール読み込みは未実装だが、`import`/`include` prefix を解釈して `module not found: <name>` の最小互換エラーを返す |
| Update assignment (`=`, `|=`, `+=`, `-=`, `*=`, `/=`, `%=`, `//=`) | partial | minimal lowering via `setpath(getpath(...))` for static path LHS (`.foo`, `.[n]`, `.a.b`, `.a.[1]`) |

## Builtins and Functions (Implemented)

Implemented builtins/functions in `core/execute.mbt` + `core/builtin*.mbt` include:

- `length`, `type`, `keys`, `keys_unsorted`
- `values`, `nulls`, `booleans`, `numbers`, `strings`, `arrays`, `objects`, `iterables`, `scalars`
- `paths`, `add`, `tostring`, `tojson`, `tonumber`, `fromjson`
- `first`, `last`, `nth`（`nth(index)` と `nth(index; stream)`）, `any`, `all`
- `range`, `limit`, `skip`, `IN`
- `flatten`, `transpose`
- `to_entries`, `from_entries`, `with_entries`, `map`, `map_values`, `select`
- `contains`, `inside`, `has`, `in`
- `startswith`, `endswith`, `ltrimstr`, `rtrimstr`
- `join`, `split`, `splits`, `test`, `scan`, `match`, `capture`, `sub`, `gsub`
- `sort`, `sort_by`, `group_by`, `min`, `max`, `min_by`, `max_by`, `unique`, `unique_by`
- `reverse`, `explode`, `implode`, `ascii_upcase`, `ascii_downcase`
- `bsearch`
- `getpath`, `setpath`, `delpaths`
- `path`, `del`
- `index`, `rindex`, `indices`
- `combinations`, `fromdate`, `env`
- `tostream`, `fromstream`, `truncate_stream`

## Known Differences (Current)

| Topic | Status | Notes |
| --- | --- | --- |
| Number edge behavior | partial | parser/evaluator now avoid non-finite JSON output (`NaN -> null`, `±Infinity -> ±MAX_DOUBLE` in numeric ops), but full jq decnum parity is still out of scope |
| Compile-time diagnostics | partial | upstream `compile_fail` coverage is enabled, but comparison currently prioritizes error-presence parity (`expect_error_mode=any`) over byte-for-byte diagnostic text parity |
| Time builtins | partial | `strftime`/`strflocaltime`/`strptime`/`mktime`/`gmtime` are implemented for upstream-covered flows; `%A`/`%B` locale name rendering now delegates to native `strftime` and matches jq differential output on native targets |
| Exact error text | partial | close to jq style but not byte-for-byte compatible |
| CLI option coverage | partial | currently `-r`, `-R`, `-c`, `-n`, `-s`, `-e` (JSON stream parsing now handles whitespace-separated and adjacent structured values; remaining byte-for-byte parity differences are still possible) |

## JS/TS Library Track

| Area | Status | Notes |
| --- | --- | --- |
| Dynamic API | supported | compatibility lane: `run`/`runCompat`/`executeToJsonStrings` (JSON text); convenience lane: `runValues`/`safeRunValues` (core `Json` values) |
| Typed DSL | partial | `Query[I, O]` scaffold + practical combinators (`identity`, `field`, `index`, `iter`, `pipe`, `comma`, `literal`, `call`, `select`, `eq`, `add`, `fallback`, `try_catch`, `map`) with `executeQuery` / `runQuery` |
| jq string partial inference layer | supported | `createAdapter(...).inferred(...)` + `InferJqOutput` are available in `ts/zod-adapter`, `ts/yup-adapter`, `ts/valibot-adapter`; unsupported jq syntax falls back to `unknown` (default) or `Json` |
| TS compile-time inference tests | supported | `expectTypeOf`-based compile-time assertions are present in `ts/zod-adapter`, `ts/yup-adapter`, and `ts/valibot-adapter` |
| Zod adapter | partial | `ts/zod-adapter` provides `createAdapter(...).filter/query/inferred`, tests, and CI checks; final npm binding is pending |
| Yup adapter | partial | `ts/yup-adapter` provides `createAdapter(...).filter/query/inferred`, tests, and CI checks; final npm binding is pending |
| Valibot adapter | partial | `ts/valibot-adapter` provides `createAdapter(...).filter/query/inferred`, tests, and CI checks; final npm binding is pending |

## Differential Testing and CI

Differential scripts:
- Smoke: `scripts/jq_diff.ps1`, `scripts/jq_diff.sh`
- Upstream full: `scripts/jq_compat_cases.upstream.json`
- Native `-e`: `scripts/jq_diff_native.ps1`, `scripts/jq_diff_native.sh`
- Cases: `scripts/jq_compat_cases.json`, `scripts/jq_exit_cases.json`
- Imported upstream cases: `scripts/jq_compat_cases.upstream.json`
- Upstream fixtures (vendored copy): `third_party/jq-tests/tests/*.test`

CI coverage in `.github/workflows/ci.yml`:
- Linux/macOS/Windows: MoonBit `check` + tests
- Linux: `ts/zod-adapter`, `ts/yup-adapter`, `ts/valibot-adapter` (`pnpm lint`, `pnpm typecheck`, `pnpm test`)
- Linux: imported upstream case drift check (`jq_upstream_import` + `git diff --exit-code`)
- Linux: differential smoke, upstream full, and native `-e` scripts

Notes:
- `jq_diff.ps1` is the primary runner for Windows environments and can resolve
  `jq` from `mise`.
- `jq_diff.sh` targets Linux/macOS and falls back to `mise` when available.
- Both differential runners sanitize `PAGER` during execution to avoid
  host-environment drift in `env.PAGER` / `$ENV.PAGER` cases.
- Differential runner parity was fixed on 2026-02-10 (`jq_diff.ps1` exit-code capture),
  and PowerShell/bash now report the same full-upstream baseline.
- Upstream jq test fixtures are copied into `third_party/jq-tests` via
  `scripts/update_jq_tests.ps1` or `scripts/update_jq_tests.sh` (copy strategy,
  not git submodule).
- `scripts/jq_upstream_import.ps1` converts vendored `*.test` fixtures into
  `scripts/jq_compat_cases.upstream.json` using sidecar config in
  `scripts/jq_upstream_import.json`.
- Imported upstream set now includes both runtime and `compile_fail` cases.
- `compile_fail` cases are currently generated with `expect_error_mode=any`
  (error-presence parity first, strict diagnostic text parity tracked separately).
- Full upstream failure backlog and prioritization:
  `docs/upstream-failure-backlog.md`.
- CLI compatibility cases can specify `jq_args` / `jqx_args` and
  `jqx_use_stdin` for option-aware differential runs.
- Differential runners now default `jqx_use_stdin=true` unless explicitly
  overridden per case.
- Cases with `skip_reason` are counted as skipped by `jq_diff.*`.
- Smoke differential currently covers 233 cases (as of 2026-02-19).
- Full upstream differential baseline is currently:
  total 843 / passed 843 / failed 0 / skipped 0
  (see `scripts/jq_upstream_failures.snapshot.json` and `docs/upstream-failure-backlog.md`).
- `expect_error: true` in smoke differential cases compares normalized jq/jqx
  error messages and accepts jqx `moon run` wrapper status behavior.
- `expect_error_mode` can be `strict` (default) or `any`.

## Next Execution Order

1. Expand differential cases from smoke to feature coverage (builtins/operators/options).
2. Keep zero-skip upstream differential while expanding covered feature surface.
3. Expand Typed lane from scaffold to richer combinators and compile-time TS tests.
4. Finalize npm-facing JS/TS runtime binding (including Zod adapter import path design).
