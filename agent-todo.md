# Agent TODO

Updated: 2026-03-03

## Current baseline (2026-02-28)

- `moon test`: 256/256 pass
- `moon test --target native --package core`: 196/196 pass
- differential smoke (`scripts/jq_compat_cases.json`): total 242 / passed 242 / failed 0 / skipped 0
- differential upstream full (`scripts/jq_compat_cases.upstream.json`): total 843 / passed 843 / failed 0 / skipped 0

## P0: 理論上の完全互換に向けた追跡

- [x] upstream compile-fail の `%%FAIL IGNORE MSG` を含め strict 比較へ統一する（`expect_error_mode: any` を 0 件にする）
- [x] native の `strftime`/`strflocaltime` で `%A`/`%B` を locale 依存出力に寄せる（C `strftime` 連携）
- [x] locale/timezone 依存ケースの差分検証を OS/タイムゾーン matrix で追加する（`scripts/jq_compat_cases.tz_matrix.json` + CI `differential-smoke-matrix`）
- [x] jq upstream 更新時の差分台帳（新規 fail / 振る舞い変更）を自動生成する（`scripts/jq_upstream_ledger.*` + `scripts/jq_upstream_diff_ledger.md`）

## P0: jq互換の未実装/部分実装を埋める

- [x] `def`（ユーザー定義関数）の最小実装を追加する（top-level の parser lowering + 引数付き `def f(a;b)` + differential case）
- [x] `def` の対応範囲を拡張する（ネスト定義の配置対応・arity解決改善）
- [x] `def` の対応範囲をさらに拡張する（前方参照/相互再帰の抑止、レキシカルcapture、`def x: .[1,2]; x=10` 等の代入LHS解決を追加）
- [x] `import` / `include` の filesystem 解決を追加する（検索パス + native実読み込みの最小互換）
- [x] update assignment（`|=`, `+=` など）の対応範囲を拡張する（`def`由来LHS、optional path、iter/select系の実用ケースを追加）
- [x] 正規表現ファミリ（`test`/`match`/`capture`/`scan`/`sub`/`gsub`）を最小互換で実装する
- [x] CLI `-R`/`-s` の入力セマンティクス差分を縮小する（line/slurp境界のjq互換）
- [x] Windows CLI の UTF-8 引数経路を追加し、Unicode 正規表現ケースの文字化け差分を解消する
- [x] `strftime`/`strflocaltime` の locale依存分岐を整理し、曜日/月名フォーマットを決定化する

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
- [x] upstream失敗ケースをカテゴリ集計して台帳化する（`scripts/jq_upstream_failures.snapshot.json` + AGENTS backlog notes）
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
- [x] upstream runtime-error-vs-jq-success クラスタを解消する（10→0、string `/` 互換・`abs` 互換・`path` 変数束縛追跡）
- [x] Objectキー順の扱いをjq互換へ寄せる（入力/更新順保持。`keys` は辞書順、`keys_unsorted` は入力順）
- [x] upstream skip件数を追加で縮小する（92→90、`@base64d` lax padding対応 + `io-control` 誤検知1件をunskip）
- [x] upstream skip件数を追加で縮小する（90→88、`input`/`debug` 最小互換 + 2件unskip）
- [x] upstream full differential の skip を解消する（88→0、total 843 / failed 0 / skipped 0）
- [x] エラーメッセージ差分を解消する（compile-fail を strict 比較へ移行、`expect_error_mode: any` を撤廃）
- [x] differentialケースを拡張する（`reduce`/`foreach`/`try-catch`/演算の境界系を11件追加、smoke 169→180）
- [x] differentialケースをさらに拡張する（upstream pass群から `def` 系3件を取り込み、smoke 180→185）
- [x] differentialケースをさらに拡張する（`pow`/`fabs`/`log2` 3件を追加、smoke 185→188）
- [x] differentialケースをさらに拡張する（`IN`/`INDEX` 2件を追加、smoke 188→190）
- [x] differentialケースをさらに拡張する（`split/splits`+`combinations`+`fromdate`+`env`+stream系を9件追加、smoke 190→199）
- [x] differentialケースをさらに拡張する（`as`束縛/スコープ回帰の4件を追加、smoke 199→203）
- [x] differentialケースをさらに拡張する（runtime互換回帰の7件を追加、smoke 203→210）
- [x] differentialケースをさらに拡張する（smoke 210→233、failed 0 / skipped 0 を維持）

## P1: JS/TS公開に向けた仕上げ

- [x] npm向け公開エントリポイントを確定する（`import { ... } from \"@shina1024/jqx\"` の最終設計）
- [x] Zod/Yup/Valibotの実ランタイム接続例をREADMEに追加する（mockではない配線例）
- [x] Typed DSLコンビネータを拡張し、compile-time推論テストを追加する（`ts/adapter-core/src/typed_query.ts` + `ts/adapter-core/test/typecheck.ts` + `ts/jqx/test/typecheck.ts`）

## P1: JS/TSライブラリ価値最大化

- [x] Typed lane の最適UXを確定する（`JqxTypedClient<Q>` は `Q` を厳密受理、`QueryAst` backend 向けに `JqxAstClient` で `Query` 直渡しを許可）
- [x] 入出力モデルを最適化する（コア実行APIの `input` を `Json` 契約に統一、`runRaw/queryRaw` を文字列境界として分離）
- [x] エラーモデルを利用者中心に再設計する（`JqxRuntimeError` を判別可能 union 化し、`toJqxRuntimeError` / `isJqxRuntimeError` / `runtimeErrorToMessage` を追加）
- [x] `QueryAst` を外部連携向けに仕様化する（v1 document envelope: `format/version/ast` を導入、import/export helper と strict version check を追加）
- [x] 大規模データ向けレーンを設計する（`AsyncIterable` ベースの streaming API を追加し、`Json[]` バッファ前提を緩和）
- [x] capability 表現を改善する（`hasTypedRuntime` 依存を減らし、factory段階で機能差を明示）
- [ ] 公開APIの型テストを強化する（`expect-type` で主要ユースケースを固定し、DX回 regressions を即検知）
- [ ] 利用者導線を強化する（README に backend 実装契約 + 実運用レシピ + エラーハンドリング指針を追加）

## P1: コードベース保守性（リファクタリング）

- [x] 公開API命名をjq寄せに揃える（`compile`/`execute` を主、旧名は互換alias）
- [x] 内部API命名をjq寄せに揃える（`builtin_call_*` への統一と `parser*` / `builtin*` 命名への統一を反映）
- [x] `core/execute_test.mbt` の第1分割を実施する（collections系を `core/execute_collections_test.mbt` へ切り出し）
- [x] `core/execute_test.mbt` を機能別に分割する（`execute_test_support` 導入 + 挙動不変）
- [x] `core/parser.mbt` を `cursor/atom/expr/lowering` に段階分割する（挙動不変、`cursor` / `atom` / `expr` / `lowering` の分割完了）
- [x] `core/execute.mbt` を `core/json_ops/path_ops/collection_ops` に段階分割する（挙動不変）
- [x] `core/builtin_dispatch.mbt` を責務別（numeric/string/path/stream）に段階分割する（挙動不変、path/string/collection/numeric/stream 分割完了）
- [x] 段階分割ガイドを維持する（`AGENTS.md` の分割進捗と命名方針に追従更新）
- [x] テスト命名方針を明文化する（`source_stem_test` と `execute_topic_test` の使い分けを `AGENTS.md` に追記）
- [x] parser テストを source 対応へ揃える（`core/filter_test.mbt` → `core/parser_test.mbt`）
- [x] テストファイル先頭に source 対応コメントを追加する（`Source under test` ヘッダ）

## P2: CI/運用の底上げ

- [x] differentialテストの実行対象OSを拡張する（`differential-smoke-matrix` で ubuntu/macos/windows × `TZ={UTC,Asia/Tokyo}`）
- [x] full differential の cross-OS 定期実行を追加する（`.github/workflows/differential-nightly.yml`: `schedule` + `workflow_dispatch`）
- [x] カバレッジ可視化（`moon coverage analyze`）をCIに組み込む（Linux CIで `uncovered.log` をartifact保存）

## Next Queue (2026-03-01)

- [ ] Differential Nightly の運用確認を完了する（`workflow_dispatch` 初回ドライラン + 手順明文化）
- [ ] jq upstream fixtures 更新の定期運用を自動化する
- [x] npm パッケージ公開ワークフローを追加する（`.github/workflows/release-npm.yml`）

## Done (2026-03-01)

- [x] Typed DSL の実行レーン（QueryAst -> runtime）を標準化する（`ts/jqx` に `runTypedQuery` / `runTypedQueryAst` を追加）
- [x] regex translator の `TODO: merge sequences` を解消する（`core/internal/regex_engine/translate.mbt` で先頭 `Char` 共通分岐の merge を実装）

## Done (2026-03-03)

- [x] JS/TS runtime API を `createJqx` 中心へ再設計する（`run/query` は JSON 入出力、`runRaw/queryRaw` は backend 契約として分離）
