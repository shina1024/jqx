# Agent TODO

Updated: 2026-02-14

## P0: jq互換の未実装/部分実装を埋める

- [x] `def`（ユーザー定義関数）の最小実装を追加する（top-level の parser lowering + 引数付き `def f(a;b)` + differential case）
- [x] `def` の対応範囲を拡張する（ネスト定義の配置対応・arity解決改善）
- [ ] `def` の対応範囲をさらに拡張する（再帰、filter引数セマンティクス、import連携）
- [ ] update assignment（`|=`, `+=` など）の対応範囲を拡張する（静的パス以外の実用ケース）
- [ ] 正規表現ファミリ（`test`/`match`/`capture`/`scan`/`sub`/`gsub`）を最小互換で実装する
- [ ] CLI `-R`/`-s` の入力セマンティクス差分を縮小する（line/slurp境界のjq互換）

## P1: 互換性の精度と回帰検知を強化する

- [x] jq公式テストをコピー方式でvendorする基盤を追加する（`third_party/jq-tests`, `scripts/update_jq_tests.*`）
- [x] vendored jq tests（`*.test`）から `jq_diff` 用ケースJSONを自動生成する importer を実装する（`scripts/jq_upstream_import.*`）
- [x] upstream importerで生成したケース群のうち、安定パス集合（stage1）を選定してCIに段階導入する
- [x] upstream stage1 subsetをallowlistベースで自動生成し、CIで生成物ドリフトを検知する
- [x] upstream stage1 subsetを拡張する（安定性を維持しつつ59→76件に増やす）
- [x] upstream stage1 subsetをさらに拡張する（安定性を維持しつつ76→84件へ段階追加）
- [x] upstream stage1 subsetをさらに拡張する（安定性を維持しつつ84→92件へ段階追加）
- [x] upstream stage1 subsetをさらに拡張する（安定性を維持しつつ92→95件へ段階追加）
- [x] upstream stage1 subsetをさらに拡張する（安定性を維持しつつ95→110件へ段階追加）
- [x] upstream失敗ケースをカテゴリ集計して台帳化する（`docs/upstream-failure-backlog.md` + snapshot）
- [x] upstream parser失敗クラスタの第1段を実施する（188→147、`=`/`%`/単項`-`/`."..."`/`foreach`2句/object shorthand/`.[1,2]`）
- [x] upstream parser失敗クラスタの第2段を実施する（145→108、`if/elif/else/end`拡張・`else`省略・任意式`[]`後置・配列/オブジェクト値で比較式）
- [x] upstream parser失敗クラスタの第3段を実施する（108→80、`as`配列/オブジェクトパターン束縛と`?//` destructuring fallback）
- [x] upstream parser失敗クラスタの第4段を実施する（80→75、`reduce/foreach` の `as` パターン束縛対応）
- [x] upstream parser失敗クラスタの第5段を実施する（75→60、動的ブラケット添字/数値添字拡張/一般式の`.field`後置）
- [x] upstream parser失敗クラスタを段階的に潰す（`parser-invalid-character` 62→0）
- [x] upstream unknown-functionクラスタの第1段を実施する（127→87、`range`/`limit`/`skip`/`IN`/`nth(i; expr)`）
- [x] upstream unknown-functionクラスタの第2段を実施する（87→77、`path`/`del`/再帰下降 `..`）
- [x] upstream unknown-function上位クラスタを潰す（77→0、`have_decnum`/`abs`/`isempty`/`trimstr`/`trim`系を実装）
- [x] upstream unknown-functionホットスポットを追加で縮小する（21→18、`pow`/`fabs`/`log2`/`round`）
- [x] upstream unknown-functionホットスポットを追加で縮小する（18→15、`IN`/`INDEX`）
- [x] upstream unknown-functionクラスタを実質解消する（15→0、`split/splits`+`combinations`+`fromdate`+`env`+`tostream/fromstream/truncate_stream`）
- [x] upstream unknown-variableクラスタを解消する（8→0、`as`スコープ修正+`?//`変数初期化+`$ENV`/`$__loc__`最小互換）
- [x] Objectキー順の扱いを安定化する方針を決めて実装する（辞書順正規化で安定化）
- [ ] エラーメッセージ差分を縮小する（`expect_error` ケース追加は進捗あり、正規化改善を継続）
- [x] differentialケースを拡張する（`reduce`/`foreach`/`try-catch`/演算の境界系を11件追加、smoke 169→180）
- [x] differentialケースをさらに拡張する（upstream pass群から `def` 系3件を取り込み、smoke 180→185）
- [x] differentialケースをさらに拡張する（`pow`/`fabs`/`log2` 3件を追加、smoke 185→188）
- [x] differentialケースをさらに拡張する（`IN`/`INDEX` 2件を追加、smoke 188→190）
- [x] differentialケースをさらに拡張する（`split/splits`+`combinations`+`fromdate`+`env`+stream系を9件追加、smoke 190→199）
- [x] differentialケースをさらに拡張する（`as`束縛/スコープ回帰の4件を追加、smoke 199→203）

## P1: JS/TS公開に向けた仕上げ

- [ ] npm向け公開エントリポイントを確定する（`import { ... } from \"jqx\"` の最終設計）
- [ ] Zod/Yup/Valibotの実ランタイム接続例をdocsに追加する（mockではない配線例）
- [ ] Typed DSLコンビネータを拡張し、compile-time推論テストを追加する

## P2: CI/運用の底上げ

- [ ] differentialテストの実行対象OSを拡張する（Linux専用からの段階的拡張）
- [ ] カバレッジ可視化（`moon coverage analyze`）をCIに組み込む
