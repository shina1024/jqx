# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-15

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 624
- failed: 53
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `output-mismatch` | 51 | evaluator semantics differences (streaming behavior, error propagation, numeric semantics, key order policy) |
| `runtime-error-vs-jq-success` | 0 | resolved in current baseline |
| `unknown-variable` | 0 | resolved in current baseline |
| `parser-invalid-character` | 2 | parse error wording/position mismatch in error text |
| `unknown-function` | 0 | resolved in current baseline |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

- none (cluster is `0`)

## Latest Progress

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
- Variable/scoping compatibility expanded:
  - fixed `as ... |` scope for comma-separated RHS.
  - fixed `?//` pattern fallback variable defaults (`null` initialization).
  - added special variables `$ENV` (minimal empty object) and `$__loc__` (minimal location object).
  - full upstream unknown-variable cluster reduced from `8` to `0`.
- Runtime error parity expanded:
  - implemented string-division compatibility (`string / string` as split behavior).
  - `abs` now matches jq for non-numeric scalar/container inputs (null/bool are still type errors).
  - `path()` evaluation now keeps variable-bound path state through `as` and dynamic `getpath`.
  - full upstream runtime-error-vs-jq-success cluster reduced from `10` to `0`.
- Differential smoke cases were expanded from 203 to 214.
- Upstream stage1 subset was expanded from 95 to 110 passing cases.
- `try ... catch ...` の入力セマンティクスを jq 寄せに修正（catch側へエラーメッセージ文字列を入力）し、
  full upstream diff を `failed 132 -> 99` まで縮小。
- 例外モデルを拡張し、`error` 系は JSON 値を保持したまま catch へ渡すように修正
  （`error` 値の文字列化崩れを解消）。
- `if` のストリーム分岐セマンティクス（複数条件出力 / 条件空出力）と、
  `and`/`or`/`not` のストリーム評価セマンティクスを jq 寄せに修正し、
  full upstream diff を `failed 99 -> 88` まで縮小。
- スライス/配列更新/文字列処理の互換性を集中修正:
  - `skip(n; stream)` の評価順序修正（負数エラー時に stream を先行評価しない）
  - `trim/ltrim/rtrim` の空白判定拡張、`trimstr` 系の型エラーメッセージ整合
  - `implode` の `NaN/±Inf` 要素エラー化
  - `.[start:end]` の小数境界丸め（start=floor, end=ceil）
  - `.[nan]` / `setpath` / `getpath` 系の `NaN/±Inf` インデックス扱い整合
  - 代入スライスのエラー優先順位修正（文字列入力は `Cannot update string slices` 優先）
- `pipe` と `comma` の優先順位を jq 寄せに修正し、
  `a,b | f` / `x | y,z` 系の評価順序差分を解消。
- 配列リテラルを jq の `[expr]` セマンティクスに寄せ、
  `as` 束縛と `,` 生成子のスコープ互換性を改善。
- full upstream diff を `failed 88 -> 65` まで縮小。
- `|=` の empty セマンティクスを jq 寄せに修正:
  - 右辺が empty の path は削除対象として扱う
  - `.[].|=...` 系の複数削除で index シフトを避けるため、削除 path を集約して `delpaths` を適用
  - `tonumber` は前後空白付き文字列を拒否（`" 4"`, `"5 "` を parse しない）へ調整
- full upstream diff を `failed 65 -> 61` まで縮小。
- `try/catch` の結合規則を jq 寄せに修正:
  - `try` / `catch` は次の単項式にのみ結合（`try .a + 1` は `(try .a) + 1`）
  - `1 + try 2 catch 3 + 4` / `try (1/0) catch 9 + 2` の優先順位差分を解消
- `setpath`/更新代入の巨大添字で空出力になる挙動を修正:
  - 配列拡張上限を超える添字は `"Array index too large"` を返す
  - `try (.[999999999] = 0) catch .` を jq と同じ結果へ修正
- full upstream diff を `failed 61 -> 59` まで縮小。
- 単項マイナスの内部表現を `Sub(0, x)` から `__neg(x)` へ変更し、jq 互換のエラー文言系を集中修正:
  - 長い文字列プレビューを jq 形式 (`"....`) に整形
  - `-` の型エラー文言を jq 寄せ（`cannot be negated` / `cannot be subtracted`）
  - `%` の 0 除算文言を jq 寄せ（`cannot be divided (remainder) ...`）
- full upstream diff を `failed 59 -> 53` まで縮小。

## Priority Plan

1. Triage `output-mismatch` (`51`) by subcategory:
   - intentional policy differences (e.g. object key order)
   - real behavioral regressions (streaming/error semantics).
2. Triage `parser-invalid-character` (`2`) and align parser error wording/offset behavior.
3. Continue `def` compatibility improvements (recursion and filter-argument semantics).
4. Keep expanding stage1 allowlist incrementally with newly stable cases.
