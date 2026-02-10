# Agent TODO

Updated: 2026-02-10

## P0: jq互換の未実装/部分実装を埋める

- [ ] `def`（ユーザー定義関数）の最小実装を追加する（parser + eval + differential case）
- [ ] update assignment（`|=`, `+=` など）の対応範囲を拡張する（静的パス以外の実用ケース）
- [ ] 正規表現ファミリ（`test`/`match`/`capture`/`scan`/`sub`/`gsub`）を最小互換で実装する
- [ ] CLI `-R`/`-s` の入力セマンティクス差分を縮小する（line/slurp境界のjq互換）

## P1: 互換性の精度と回帰検知を強化する

- [x] jq公式テストをコピー方式でvendorする基盤を追加する（`third_party/jq-tests`, `scripts/update_jq_tests.*`）
- [x] vendored jq tests（`*.test`）から `jq_diff` 用ケースJSONを自動生成する importer を実装する（`scripts/jq_upstream_import.*`）
- [x] upstream importerで生成したケース群のうち、安定パス集合（stage1）を選定してCIに段階導入する
- [x] upstream stage1 subsetをallowlistベースで自動生成し、CIで生成物ドリフトを検知する
- [x] upstream stage1 subsetを拡張する（安定性を維持しつつ59→76件に増やす）
- [ ] upstream stage1 subsetをさらに拡張する（安定性を維持しつつ79件超へ段階追加）
- [x] Objectキー順の扱いを安定化する方針を決めて実装する（辞書順正規化で安定化）
- [ ] エラーメッセージ差分を縮小する（`expect_error` ケース追加は進捗あり、正規化改善を継続）
- [x] differentialケースを拡張する（`reduce`/`foreach`/`try-catch`/演算の境界系を11件追加、smoke 169→180）
- [ ] differentialケースをさらに拡張する（upstream pass群からの段階取り込み）

## P1: JS/TS公開に向けた仕上げ

- [ ] npm向け公開エントリポイントを確定する（`import { ... } from \"jqx\"` の最終設計）
- [ ] Zod/Yup/Valibotの実ランタイム接続例をdocsに追加する（mockではない配線例）
- [ ] Typed DSLコンビネータを拡張し、compile-time推論テストを追加する

## P2: CI/運用の底上げ

- [ ] differentialテストの実行対象OSを拡張する（Linux専用からの段階的拡張）
- [ ] カバレッジ可視化（`moon coverage analyze`）をCIに組み込む
