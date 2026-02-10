# Agent TODO

Updated: 2026-02-10

## P0: jq互換の未実装/部分実装を埋める

- [ ] `def`（ユーザー定義関数）の最小実装を追加する（parser + eval + differential case）
- [ ] update assignment（`|=`, `+=` など）の対応範囲を拡張する（静的パス以外の実用ケース）
- [ ] 正規表現ファミリ（`test`/`match`/`capture`/`scan`/`sub`/`gsub`）を最小互換で実装する
- [ ] CLI `-R`/`-s` の入力セマンティクス差分を縮小する（line/slurp境界のjq互換）

## P1: 互換性の精度と回帰検知を強化する

- [ ] Objectキー順の扱いを安定化する方針を決めて実装する（順序保持または明示仕様）
- [ ] エラーメッセージ差分を縮小する（`expect_error` ケース追加 + 正規化改善）
- [ ] differentialケースを拡張する（`reduce`/`foreach`/`try-catch`/演算の境界系）

## P1: JS/TS公開に向けた仕上げ

- [ ] npm向け公開エントリポイントを確定する（`import { ... } from \"jqx\"` の最終設計）
- [ ] Zod/Yup/Valibotの実ランタイム接続例をdocsに追加する（mockではない配線例）
- [ ] Typed DSLコンビネータを拡張し、compile-time推論テストを追加する

## P2: CI/運用の底上げ

- [ ] differentialテストの実行対象OSを拡張する（Linux専用からの段階的拡張）
- [ ] カバレッジ可視化（`moon coverage analyze`）をCIに組み込む
