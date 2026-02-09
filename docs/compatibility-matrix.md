# jqx Compatibility Matrix (Baseline)

Updated: 2026-02-09

Scope:
- Target compatibility: jq 1.7 behavior
- Current differential smoke run: jq 1.8.1 (local)
- Source of truth for current implementation: `core/filter_parse.mbt`, `core/eval.mbt`

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
| Update assignment (`|=`, `+=`, `*=` etc.) | planned | parser/evaluator not implemented |

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
| Number edge behavior | partial | `Double`-first semantics; Infinity/NaN handling still evolving |
| Exact error text | partial | close to jq style but not byte-for-byte compatible |
| CLI option coverage | partial | currently `-r`, `-R`, `-c`, `-n`, `-s`, `-e` (`-R` is line-based without full JSON-stream parity) |

## JS/TS Library Track

| Area | Status | Notes |
| --- | --- | --- |
| Dynamic API | supported | `parseJson`, `parseFilter`, `eval`, `evalToJsonStrings` |
| Typed DSL | planned | `Query[I, O]` style API not started yet |
| TS compile-time inference tests | planned | runtime tests exist, type-level tests pending |

## Differential Testing

Smoke differential scripts:
- PowerShell: `scripts/jq_diff.ps1`
- Bash: `scripts/jq_diff.sh`
- Cases: `scripts/jq_compat_cases.json`

Run examples:

```powershell
./scripts/jq_diff.ps1
```

```bash
bash ./scripts/jq_diff.sh
```

Notes:
- `jq_diff.ps1` is the primary runner for Windows environments and can resolve
  `jq` from `mise`.
- `jq_diff.sh` targets Linux/macOS and falls back to `mise` when available.

## Next Execution Order

1. Expand differential cases from smoke to feature coverage (per builtin/operator).
2. Add unsupported high-priority jq features (starting with assignment/update and regex family).
3. Expand CLI differential tests (`-R/-s/-n/-e` combinations and stdin variants).
4. Split JS API into Dynamic/Typed lanes and start typed DSL scaffolding.
