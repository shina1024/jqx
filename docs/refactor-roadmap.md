# Refactor Roadmap (Core Maintainability)

Updated: 2026-02-14

## Why now

現状、`core` には以下の巨大ファイルがあり、仕様追加と回帰修正の速度を落とし始めている。

- `core/filter_parse.mbt`: 2765 lines
- `core/eval_test.mbt`: 2176 lines
- `core/eval.mbt`: 1936 lines
- `core/eval_call.mbt`: 1521 lines

結論として、互換性実装を継続するためにリファクタリングは **必要**。
ただし挙動変更を伴う大改修は避け、まず「責務分割のみ」を行う。

## Current progress

- `core/eval_test.mbt` の分割を開始済み（`core/eval_collections_test.mbt`, `core/eval_path_test.mbt`, `core/eval_aggregate_test.mbt`, `core/eval_test_support_test.mbt`）
- `core/eval.mbt` から path 系を `core/eval_path_ops.mbt` へ分離済み（挙動不変）
- 次段は `eval_collection_ops` と `filter_parse` 分割

## Upstream jq からの参照方針

本家 jq は `src/` を責務で分離している（例: `parser.y` / `lexer.l` / `compile.c` / `execute.c` / `builtin.c` / `main.c`）。
jqx でも同じ思想を取り、言語仕様の差を保ったまま次の対応関係を目標にする。

- parser/lexer 相当: `filter_parse*`
- execute 相当: `eval*`
- builtin 相当: `eval_builtin*`, `eval_call*`
- CLI 相当: `cmd/main*`
- tests 相当: `core/*_test.mbt` の機能別分割

## Naming policy

未採番期間のため、公開API名も jq 寄せで進める。

- parser API: `compile` を正とし、`parse_filter` は互換alias扱い
- evaluator API: `execute` を正とし、`eval` は互換alias扱い
- JS公開APIも同方針（`compile`/`execute` を主、旧名は alias）

## Target file layout (core)

段階的に次の構成へ寄せる。

- `core/filter_parse_cursor.mbt`
  - 文字走査、位置情報、キーワード判定、字句ユーティリティ
- `core/filter_parse_atom.mbt`
  - primary/atom、リテラル、配列・オブジェクト、呼び出し素片
- `core/filter_parse_expr.mbt`
  - 優先順位付き式パース（`parse_mul` 〜 `parse_comma`）
- `core/filter_parse_lowering.mbt`
  - `as` / `?//` / update assignment / `def` lowering

- `core/eval_core.mbt`
  - `eval`, `eval_with_env`, dispatch 本体
- `core/eval_json_ops.mbt`
  - 型判定、比較、算術、truthy判定などの共通演算
- `core/eval_path_ops.mbt`
  - `path` / `getpath` / `setpath` / `delpaths` 系
- `core/eval_collection_ops.mbt`
  - sort/group/unique/min/max/flatten/transpose など

- `core/eval_test_support_test.mbt`
  - `must_parse`, `must_eval` などテスト共通ヘルパ
- `core/eval_basic_test.mbt`
- `core/eval_path_test.mbt`
- `core/eval_builtin_test.mbt`
- `core/eval_control_test.mbt`
- `core/eval_compat_test.mbt`
  - `eval_test.mbt` を無理なく分割

## Execution plan

### Phase 1 (low risk, first)

- `eval_test.mbt` を機能別に分割し、`eval_test_support.mbt` を導入
- 挙動変更禁止（テスト名と期待値を維持）

Done criteria:

- `moon test` が現状同等で通る
- 差分はファイル移動・関数移設のみ

### Phase 2 (parser split, no behavior change)

- `filter_parse.mbt` を cursor/atom/expr/lowering に分割
- parser の public API とエラーメッセージは維持

Done criteria:

- `moon test`
- `pwsh -File scripts/jq_diff.ps1`
- upstream stage1 diff

### Phase 3 (evaluator split, no behavior change)

- `eval.mbt` の path/collection/helper を分離
- `eval_with_env` の match dispatch のみを `eval_core.mbt` に残す

Done criteria:

- `moon test`
- smoke + stage1 differential pass
- `docs/upstream-failure-backlog.md` の件数悪化なし

### Phase 4 (optional, after stabilization)

- `eval_call.mbt` / `eval_builtin.mbt` の命名統一と重複削減
- エラーメッセージ整備タスクと接続

## Guardrails

- 1 PR/commit あたり 1 phase の一部までに制限する
- 互換性タスクと混ぜない（実装追加と構造変更を同一コミットにしない）
- 毎段階で `moon info && moon fmt && moon test` を必須化する
