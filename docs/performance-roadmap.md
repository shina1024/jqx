# Performance Roadmap

Updated: 2026-02-28

## Goal

jqx の jq 互換性を維持しつつ、実行時ボトルネックを段階的に削減する。

## Priority

1. `sort` 系の `O(n^2)` 実装を `O(n log n)` 化（非破壊・高ROI）
2. 正規表現コンパイル結果のキャッシュ導入（非破壊・高ROI）
3. `env.copy()` 多発箇所の削減（破壊的: Env をフレーム連鎖へ変更）
4. `Scope` 実行時 lowering のキャッシュ（非破壊〜軽微破壊）
5. `sub/gsub` の連結戦略をバッファ化（非破壊）

## Breaking change candidates

- Env を `Map[String, Json]` の都度コピーから、親参照を持つ `EnvFrame` へ移行
  - 効果: `as/reduce/foreach` の割り当てを大幅削減
  - 影響: `execute_with_env` と path 評価経路の内部設計が変わる
- 実行結果収集を eager `Array[Json]` から逐次ストリーム評価へ変更
  - 効果: 中間配列を削減し、大入力時のメモリ圧を低減
  - 影響: evaluator の制御フローとエラープレフィックス処理を再設計

## Current progress

- 2026-02-28:
  - `core/jqx.mbt` の `sort_strings_lex` を安定 `O(n log n)`（merge sort）に変更
  - `core/collection_ops.mbt` の `sort_json_array` / `sort_keyed_pairs` を安定 `O(n log n)` に変更
  - 既存の順序安定性（同値時に入力順維持）は保持
  - `core/execute.mbt` に regex compile cache を導入し、`(pattern, flags)` の再コンパイルを削減
  - `as/reduce/foreach` と path 評価の `as` で `env.copy()` を一時束縛+復元へ置換
  - `JsonObject` に lex ソート済みキーを保持し、Object 比較時の再ソートを削減
  - Object 比較で lex キー配列のコピー生成を避け、保持済み配列を直接参照

## Validation policy

- 毎ステップで `moon test` を実行
- 仕上げで `moon info && moon fmt`
- 変更ごとにコミット・プッシュし、CI 緑を確認して次へ進む
