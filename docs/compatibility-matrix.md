# jqx Compatibility Matrix (Baseline)

Updated: 2026-02-10

Scope:
- Target compatibility: jq 1.7 behavior
- Differential baseline used in this repo: jq 1.8.1 (local)
- Source of truth for behavior: `core/filter_parse.mbt`, `core/eval.mbt`

Legend:
- `supported`: implemented and covered by tests
- `partial`: implemented with known differences
- `planned`: not implemented yet

## Core Language

| Area | Status | Notes |
| --- | --- | --- |
| Identity / field / index / iter | supported | `.`, `.foo`, `.[n]`, `.[]`, optional forms |
| Slice | supported | `.[start:end]`, optional form |
| Pipe / comma | supported | stream composition |
| Literals | supported | number/string/bool/null, array/object literals |
| Variables | supported | `.expr as $x | ...`, `$x` |
| Error control | supported | `expr?`, `try ... catch ...` |
| Control flow | supported | `if ... then ... else ... end`, `empty`, `//` |
| Reduce / foreach | supported | minimal stream semantics |
| Arithmetic / compare / logic | supported | `+ - * /`, `== != < <= > >=`, `and or not` |
| User-defined functions (`def`) | planned | parser/evaluator not implemented |
| Labels / break | planned | parser/evaluator not implemented |
| Module system (`import`/`include`) | planned | parser/evaluator not implemented |
| Update assignment (`|=`, `+=`, `-=`, `*=`, `/=`, `//=`) | partial | minimal lowering via `setpath(getpath(...))` for static path LHS (`.foo`, `.[n]`, `.a.b`, `.a.[1]`) |

## Builtins and Functions (Implemented)

Implemented builtins/functions in `core/eval.mbt` include:

- `length`, `type`, `keys`, `keys_unsorted`
- `values`, `nulls`, `booleans`, `numbers`, `strings`, `arrays`, `objects`, `iterables`, `scalars`
- `paths`, `add`, `tostring`, `tojson`, `tonumber`, `fromjson`
- `first`, `last`, `nth`, `any`, `all`
- `flatten`, `transpose`
- `to_entries`, `from_entries`, `with_entries`, `map`, `map_values`, `select`
- `contains`, `inside`, `has`, `in`
- `startswith`, `endswith`, `ltrimstr`, `rtrimstr`
- `join`, `split`
- `sort`, `sort_by`, `group_by`, `min`, `max`, `min_by`, `max_by`, `unique`, `unique_by`
- `reverse`, `explode`, `implode`, `ascii_upcase`, `ascii_downcase`
- `bsearch`
- `getpath`, `setpath`, `delpaths`
- `index`, `rindex`, `indices`

## Known Differences (Current)

| Topic | Status | Notes |
| --- | --- | --- |
| Object key order | partial | `Map` iteration order is not guaranteed |
| Number edge behavior | partial | parser/evaluator now avoid non-finite JSON output (`NaN -> null`, `±Infinity -> ±MAX_DOUBLE` in numeric ops), but full jq decnum parity is still out of scope |
| Exact error text | partial | close to jq style but not byte-for-byte compatible |
| CLI option coverage | partial | currently `-r`, `-R`, `-c`, `-n`, `-s`, `-e` (`-R` is line-based without full JSON-stream parity) |

## JS/TS Library Track

| Area | Status | Notes |
| --- | --- | --- |
| Dynamic API | supported | compatibility lane: `run`/`runCompat`/`evalToJsonStrings` (JSON text); convenience lane: `runValues`/`safeRunValues` (core `Json` values) |
| Typed DSL | partial | `Query[I, O]` scaffold + practical combinators (`identity`, `field`, `index`, `iter`, `pipe`, `comma`, `literal`, `call`, `select`, `eq`, `add`, `fallback`, `try_catch`, `map`) with `evalQuery` / `runQuery` |
| jq string partial inference layer | supported | `runWithInferred` + `InferJqOutput` are available in `ts/zod-adapter`, `ts/yup-adapter`, `ts/valibot-adapter`; unsupported jq syntax falls back to `unknown` (default) or `Json` |
| TS compile-time inference tests | supported | `expectTypeOf`-based compile-time assertions are present in `ts/zod-adapter`, `ts/yup-adapter`, and `ts/valibot-adapter` |
| Zod adapter | partial | `ts/zod-adapter` provides `safeRunWithZod`, `safeExecuteWithZod`, aliases, tests, and CI checks; final npm binding is pending |
| Yup adapter | partial | `ts/yup-adapter` provides `safeRunWithYup`, `safeExecuteWithYup`, aliases, tests, and CI checks; final npm binding is pending |
| Valibot adapter | partial | `ts/valibot-adapter` provides `safeRunWithValibot`, `safeExecuteWithValibot`, aliases, tests, and CI checks; final npm binding is pending |

## Differential Testing and CI

Differential scripts:
- Smoke: `scripts/jq_diff.ps1`, `scripts/jq_diff.sh`
- Upstream stage1: `scripts/jq_compat_cases.upstream.stage1.json`
- Native `-e`: `scripts/jq_diff_native.ps1`, `scripts/jq_diff_native.sh`
- Cases: `scripts/jq_compat_cases.json`, `scripts/jq_exit_cases.json`
- Imported upstream cases: `scripts/jq_compat_cases.upstream.json`
- Upstream fixtures (vendored copy): `third_party/jq-tests/tests/*.test`

CI coverage in `.github/workflows/ci.yml`:
- Linux/macOS/Windows: MoonBit `check` + tests
- Linux: `ts/zod-adapter`, `ts/yup-adapter`, `ts/valibot-adapter` (`pnpm lint`, `pnpm typecheck`, `pnpm test`)
- Linux: imported upstream case drift check (`jq_upstream_import` + `git diff --exit-code`)
- Linux: differential smoke, upstream stage1 subset, and native `-e` scripts

Notes:
- `jq_diff.ps1` is the primary runner for Windows environments and can resolve
  `jq` from `mise`.
- `jq_diff.sh` targets Linux/macOS and falls back to `mise` when available.
- Upstream jq test fixtures are copied into `third_party/jq-tests` via
  `scripts/update_jq_tests.ps1` or `scripts/update_jq_tests.sh` (copy strategy,
  not git submodule).
- `scripts/jq_upstream_import.ps1` converts vendored `*.test` fixtures into
  `scripts/jq_compat_cases.upstream.json` using sidecar config in
  `scripts/jq_upstream_import.json` (skip patterns + per-case overrides).
- `scripts/jq_compat_cases.upstream.stage1.json` is auto-generated from
  `scripts/jq_upstream_stage1_allowlist.txt` and is the current CI-safe subset
  (79 passing cases as of 2026-02-10).
- CLI compatibility cases can specify `jq_args` / `jqx_args` and
  `jqx_use_stdin` for option-aware differential runs.
- Cases with `skip_reason` are counted as skipped by `jq_diff.*`.
- `expect_error: true` in smoke differential cases compares normalized jq/jqx
  error messages and accepts jqx `moon run` wrapper status behavior.
- `expect_error_mode` can be `strict` (default) or `any`.

## Next Execution Order

1. Expand differential cases from smoke to feature coverage (builtins/operators/options).
2. Expand high-priority jq features (broaden update-assignment coverage and add regex family).
3. Expand Typed lane from scaffold to richer combinators and compile-time TS tests.
4. Finalize npm-facing JS/TS runtime binding (including Zod adapter import path design).
