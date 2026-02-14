# Refactor Roadmap (Core Maintainability)

Updated: 2026-02-14

## Why now

現状、`core` には以下の巨大ファイルがあり、仕様追加と回帰修正の速度を落とし始めている。

- `core/parser_lowering.mbt`: 933 lines
- `core/parser_atom.mbt`: 849 lines
- `core/execute_test.mbt`: 2176 lines
- `core/builtin_stream.mbt`: 575 lines

結論として、互換性実装を継続するためにリファクタリングは **必要**。
ただし挙動変更を伴う大改修は避け、まず「責務分割のみ」を行う。

## Current progress

- `core/execute_test.mbt` の分割を開始済み（`core/execute_collections_test.mbt`, `core/execute_path_test.mbt`, `core/execute_aggregate_test.mbt`, `core/execute_test_support_test.mbt`）
- `core/execute.mbt` から path 系を `core/path_ops.mbt` へ分離済み（挙動不変）
- `core/execute.mbt` から collection 系を `core/collection_ops.mbt` へ分離済み（挙動不変）
- `core/execute.mbt` から json 系を `core/json_ops.mbt` へ分離済み（挙動不変）
- `core/parser.mbt` から cursor 系を `core/parser_cursor.mbt` へ分離済み（挙動不変）
- `core/parser.mbt` から atom 系を `core/parser_atom.mbt` へ分離済み（挙動不変）
- `core/parser.mbt` から expr 系を `core/parser_expr.mbt` へ分離済み（挙動不変）
- `core/parser.mbt` から lowering 系を `core/parser_lowering.mbt` へ分離済み（挙動不変）
- `core/parser.mbt` は public API（`compile`/`parse_filter`）とエラー定義のみを保持する薄い入口へ整理済み
- `core/builtin_dispatch.mbt` から path 系 call を `core/builtin_path.mbt` へ分離済み（挙動不変）
- `core/builtin_dispatch.mbt` から string/index 系 call を `core/builtin_string.mbt` へ分離済み（挙動不変）
- `core/builtin_dispatch.mbt` から collection 系 call を `core/builtin_collection.mbt` へ分離済み（挙動不変）
- `core/builtin_dispatch.mbt` から numeric 系 call を `core/builtin_numeric.mbt` へ分離済み（挙動不変）
- `core/builtin_dispatch.mbt` から stream 系 call を `core/builtin_stream.mbt` へ分離済み（挙動不変）
- `core/builtin_dispatch.mbt` は call dispatcher の薄い入口へ整理済み
- internal dispatch 命名を `builtin_call_*` へ統一済み
- 次の主対象は大きいテスト/補助モジュールの追加分割（挙動不変）

## Upstream jq からの参照方針

本家 jq は `src/` を責務で分離している（例: `parser.y` / `lexer.l` / `compile.c` / `execute.c` / `builtin.c` / `main.c`）。
jqx でも同じ思想を取り、言語仕様の差を保ったまま次の対応関係を目標にする。

- parser/lexer 相当: `parser*`
- execute 相当: `execute*`
- builtin 相当: `builtin*`
- CLI 相当: `cmd/main*`
- tests 相当: `core/*_test.mbt` の機能別分割

## Naming policy

未採番期間のため、公開API名も jq 寄せで進める。

- parser API: `compile` を正とし、`parse_filter` は互換alias扱い
- evaluator API: `execute` を正とする
- JS公開APIも同方針（`compile`/`execute` を主、旧名は alias）
- internal builtin dispatch: `builtin_call_*` 系へ統一する

## Target file layout (core)

段階的に次の構成へ寄せる。

- `core/parser_cursor.mbt`
  - 文字走査、位置情報、キーワード判定、字句ユーティリティ
- `core/parser_atom.mbt`
  - primary/atom、リテラル、配列・オブジェクト、呼び出し素片
- `core/parser_expr.mbt`
  - 優先順位付き式パース（`parse_mul` 〜 `parse_comma`）
- `core/parser_lowering.mbt`
  - `as` / `?//` / update assignment / `def` lowering

- `core/execute.mbt`
  - `execute`, `execute_with_env`, dispatch 本体
- `core/json_ops.mbt`
  - 型判定、比較、算術、truthy判定などの共通演算
- `core/path_ops.mbt`
  - `path` / `getpath` / `setpath` / `delpaths` 系
- `core/collection_ops.mbt`
  - sort/group/unique/min/max/flatten/transpose など

- `core/execute_test_support_test.mbt`
  - `must_parse`, `must_execute` などテスト共通ヘルパ
- `core/execute_test.mbt`
  - execute 本体の基本挙動、複合ケース、回帰ケース
- `core/execute_path_test.mbt`
  - path/getpath/setpath/delpaths と path builtin
- `core/execute_collections_test.mbt`
  - map/select/sort/group/unique/contains など collection/string 系
- `core/execute_aggregate_test.mbt`
  - reduce/foreach/add/min/max/stream 系
- `core/filter_test.mbt`
  - parser (`compile`/`parse_filter`) の構文エラー・構文木期待値
- `core/jqx_test.mbt`
  - JSON parser (`parse_json`) の入力/エラーケース

## Source/Test mapping (current)

現状の `core` は、次の対応でソースとテストを追える状態にしている。

| Source (core) | Primary tests (core) | Scope |
|---|---|---|
| `parser.mbt`, `parser_cursor.mbt`, `parser_atom.mbt`, `parser_expr.mbt`, `parser_lowering.mbt` | `filter_test.mbt` | フィルタ文字列の構文解析と lowering |
| `execute.mbt`, `json_ops.mbt`, `builtin_dispatch.mbt` | `execute_test.mbt` | execute の中核挙動と主要回帰 |
| `path_ops.mbt`, `builtin_path.mbt` | `execute_path_test.mbt` | path 操作と関連 builtin |
| `collection_ops.mbt`, `builtin_collection.mbt`, `builtin_string.mbt` | `execute_collections_test.mbt` | collection/string 操作 builtin |
| `builtin_numeric.mbt`, `builtin_stream.mbt` | `execute_aggregate_test.mbt` | numeric/aggregate/stream builtin |
| `jqx.mbt` | `jqx_test.mbt` | JSON parser の単体 |
| (test helper) | `execute_test_support_test.mbt` | テスト共通補助の健全性 |

## Execution plan

### Phase 1 (low risk, first)

- `execute_test.mbt` を機能別に分割し、`execute_test_support_test.mbt` を導入
- 挙動変更禁止（テスト名と期待値を維持）

Done criteria:

- `moon test` が現状同等で通る
- 差分はファイル移動・関数移設のみ

### Phase 2 (parser split, no behavior change, completed 2026-02-14)

- `parser.mbt` を cursor/atom/expr/lowering に分割
- parser の public API とエラーメッセージは維持

Done criteria:

- `moon test`
- `pwsh -File scripts/jq_diff.ps1`
- upstream stage1 diff

### Phase 3 (evaluator split, no behavior change)

- `execute.mbt` の path/collection/helper を分離
- `execute_with_env` の match dispatch のみを `execute.mbt` に残す

Done criteria:

- `moon test`
- smoke + stage1 differential pass
- `docs/upstream-failure-backlog.md` の件数悪化なし

### Phase 4 (optional, after stabilization)

- `builtin_dispatch.mbt` / `builtin.mbt` の命名統一と重複削減
- エラーメッセージ整備タスクと接続

## Guardrails

- 1 PR/commit あたり 1 phase の一部までに制限する
- 互換性タスクと混ぜない（実装追加と構造変更を同一コミットにしない）
- 毎段階で `moon info && moon fmt && moon test` を必須化する

