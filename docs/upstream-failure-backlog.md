# Upstream Failure Backlog (jq Differential)

Updated: 2026-02-15

This document tracks failing upstream differential cases so they do not stay
"postponed forever". Snapshot source:

- `scripts/jq_upstream_failures.snapshot.json`
- generated from: `./scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`

## Snapshot Summary

- total: 824
- passed: 677
- failed: 0
- skipped: 147

## Failure Categories (Current)

| Category | Count | Typical root cause |
| --- | ---: | --- |
| `output-mismatch` | 0 | resolved in current baseline |
| `runtime-error-vs-jq-success` | 0 | resolved in current baseline |
| `unknown-variable` | 0 | resolved in current baseline |
| `parser-invalid-character` | 0 | resolved in current baseline |
| `unknown-function` | 0 | resolved in current baseline |

## Top Unknown Functions

From current snapshot (`unknown-function` subset):

- none (cluster is `0`)

## Latest Progress

- Remaining `output-mismatch` cluster (`6`) was closed:
  - string error preview truncation now matches jq byte-oriented behavior for Unicode text.
  - `tostring` / `tojson` number rendering was aligned for decnum-gated compatibility cases.
  - differential runner filter escaping now keeps `\uXXXX` as a single backslash sequence.
- Differential snapshot writing was fixed for empty-failure runs:
  - `scripts/jq_diff.ps1` now writes `[]` when no failures remain.
- full upstream diff reached `failed 0`:
  - total `824` / passed `677` / failed `0` / skipped `147`.

- Unicode/string index compatibility and stream error parity were expanded:
  - `indices`/`index`/`rindex` string search now uses Unicode codepoint indexing
    (fixes `upstream-jq-test-l1579`).
  - `comma` now preserves prior stream outputs on downstream errors, and
    `repeat(stream)` was implemented with partial-output propagation
    (fixes `upstream-man-test-l654`).
- Numeric formatting and error-preview compatibility were expanded:
  - parser now preserves repr for high-significance decimals / large-exponent literals.
  - `abs` now preserves positive numeric repr and `-0` rendering compatibility.
  - deep object add-error preview was aligned with jq-style truncation.
  - fixes: `upstream-jq-test-l2000`, `upstream-jq-test-l2220`,
    `upstream-jq-test-l2233`, `upstream-man-test-l5`.
- full upstream diff was reduced from `failed 15 -> 9`.
- ストリーム評価の部分出力保持を jq 寄せに拡張:
  - `pipe` 経由で先行出力済みの値を保持したままエラーを伝播できるように修正。
  - 配列/オブジェクト構築コンテキストでは部分出力を外へ漏らさないよう補正。
  - `upstream-jq-test-l2320` を解消。
- CLI のエラー時出力順を jq 寄せに調整:
  - error 行を先に出力し、その後に既出ストリーム結果を出力。
  - `upstream-jq-test-l2325` を解消。
- full upstream diff を `failed 17 -> 15` まで縮小。
- deep `tojson` / `fromjson` 互換を jq 寄せに修正:
  - `tojson` に深さ上限時の `<skipped: too deep>` プレースホルダ出力を追加。
  - `fromjson` で同プレースホルダ入力時の数値リテラル系エラー位置を jq 寄せに調整。
  - `upstream-jq-test-l2524`, `upstream-jq-test-l2529`, `upstream-jq-test-l2534` を解消。
- single quote の JSON 文字列リテラルエラー文言を jq 寄せに修正:
  - `Invalid string literal; expected \", but got '` 系の位置情報を実装。
  - `upstream-jq-test-l2464` を解消。
- full upstream diff を `failed 21 -> 17` まで縮小。
- `sort_by` / `group_by` / `unique_by` / `min_by` / `max_by` の
  複数キー評価を jq 寄せに修正:
  - key filter の複数出力を先頭1件ではなく配列キー全体として比較に使用。
  - `upstream-jq-test-l1651` と `upstream-man-test-l482` の差分を解消。
- `as` の優先順位を jq 寄せに修正:
  - `x | .[] as $v | ...` を `(x | (.[] as $v | ...))` と同等に解釈。
  - `?//` を伴うパターン束縛分岐でも同様に RHS での束縛を優先。
  - `upstream-jq-test-l716` の差分を解消。
- full upstream diff を `failed 24 -> 21` まで縮小。
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
- `fromjson`/`foreach`/CLI入出力の互換性を拡張:
  - `fromjson` が `NaN`/`±Inf` を内部数値として保持し、`isnan`/`isinfinite` 互換を改善
  - 非有限数値トークンの不正サフィックス（例: `NaN10`）で jq 寄せ文言
    (`Invalid numeric literal at EOF ...`) を返す
  - `foreach` の複数初期状態ストリーム順序を jq 寄せに修正
  - `cmd` の native stdin 読み取りを UTF-8 デコード化し、Unicode入力の互換を改善
  - differential runner (`jq_diff.ps1` / `jq_diff.sh`) の `jqx_use_stdin` 既定を `true` に変更
- full upstream diff を `failed 53 -> 47` まで縮小。
- error parity / meta builtin / runner 判定の互換性を拡張:
  - `cmd` の実行エラー終了コードを `5` に変更し、jq 互換の非0終了コードへ調整
  - `modulemeta` が string 入力時に `module not found: <name>` を返すように修正
  - `jq_diff.ps1` / `jq_diff.sh` で「jq側が失敗するケース」の比較を強化し、
    jqx 側の wrapper 由来ステータス差異があっても正規化エラーメッセージ一致で pass 判定
- full upstream diff を `failed 47 -> 40` まで縮小。
- Object キー順を jq 準拠へ修正:
  - `Json::Object` を `map + key_order` で保持し、parser/object-literal/setpath/delpaths/merge/add/from_entries/map_values/INDEX を順序保持化
  - `to_json` / `.[]` / `keys_unsorted` の順序を入力・更新順へ揃え、`keys` は jq 準拠の文字列比較ソートを維持
  - `Json` の `Eq` は object key order を無視して比較するよう維持（互換性保持）
- full upstream diff を `failed 40 -> 24` まで縮小。

## Priority Plan

1. Keep differential at `failed 0` while expanding supported-feature coverage.
2. Continue `def` compatibility improvements (recursion and full filter-argument semantics).
3. Keep expanding stage1 allowlist incrementally with newly stable cases.
