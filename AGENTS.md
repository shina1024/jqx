# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg.json` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, this is a `moon.mod.json` file listing about the
  module and some meta information.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check the test is passed. MoonBit supports snapshot
  testing, so when your changes indeed change the behavior of the code, you
  should run `moon test --update` to update the snapshot.

- You can run `moon check` to check the code is linted correctly.

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

- agent-todo.md has some small tasks that are easy for AI to pick up, agent is
  welcome to finish the tasks and check the box when you are done

## JSON Parser First: Design Notes

- 最優先はJSONパーサー。jq互換ツール/JS・TSライブラリとして共通に使える
  「純粋コア」を最初に固める。
- CLI/JS/TSから同一のパーサーAPIを使えるようにする。

### Core Data Model

- jq互換を見据え、JSON値は以下の最小型で表現する。
  - `Null`, `Bool`, `Number`, `String`, `Array`, `Object`
- `Number`はjq互換を優先して整数/浮動の区別を保持する方針
  (将来: `Int`/`Float`または`Decimal`相当の拡張を検討)

### Parser API (Core)

- 文字列入力のパースを最初に提供する。
  - `parse_json(text: String) -> Result[Json, JsonError]`
- 位置情報を含むエラー型を用意する。
  - `JsonError`には `line`, `column`, `offset`, `message`
- 将来のストリーミングや大規模入力を見据えて
  `Cursor`/`Reader` 抽象を準備しておく。

### jq互換・評価器への接続

- 解析結果は将来のjqフィルタ評価器でそのまま使える形にする。
- Objectのキー順は入力順保持を基本とし、必要ならソートは別レイヤで扱う。

### JS/TS対応の考慮

- JS/TSライブラリ向けに、MoonBitのJSバックエンドで
  直接利用できるAPIを設計する。
- APIは小さく安定させ、後でTS定義を追加しやすい形にする。
- 数値はJS互換（IEEE754 Double）を優先し、精度限界は仕様として明記する。

### Implementation Steps (First Pass)

1. JSON値型 `Json` を定義
2. パーサー `parse_json` を実装
3. エラー型 `JsonError` に位置情報を付与
4. 代表的な単体テストを追加 (スナップショット中心)
5. jq評価器側に接続しやすいAPIを維持する

## Package Split

- `core/` にJSONパーサー等のコア実装を置く（CLI/JS/TS共通）
- `cmd/jqx` は `shina1024/jqx/core` を参照
- ルートパッケージは core への薄いラッパーにし、実装は core に集約する
- CLI はネイティブターゲット想定（stdin対応のため）

## Number Semantics (JS-first)

- `Json::Number` は `Double` を基本とする（JS互換優先）
- 巨大整数の厳密性は保証しない（JS制約）
- stringify時は入力表現の保持を優先する設計を検討する（必要なら `repr` を保持）

## CLI Notes

- jq互換のCLIはネイティブ前提で動作確認する
- 実行例:
  - `echo '{"foo": 1}' | moon run --target native cmd/jqx -- ".foo"`
  - `moon run --target native cmd/jqx -- ".foo" '{"foo": 1}'`
- オプション:
  - `-r` は文字列を raw 出力（`"..."` を外す）
  - `-n` は入力を無視して null を与える

## jq Compatibility Notes

- `Object` のキー順は `Map` 依存で未保証（順序保持が必要なら改善予定）
- `Array`/`Object` リテラルや比較/算術は **最初の出力のみ**を使う簡略化実装
- `+` は数値/文字列/配列/オブジェクトに対応（オブジェクトは右優先でマージ）
- `?` のオプショナルアクセスは `.foo?`, `.[0]?`, `.[]?` に対応
- `expr?` はエラーを empty に変換する最小実装
- `try expr catch expr` は最小実装（エラー時に handler を評価）
- `reduce`/`foreach` はストリーム対応の最小実装（累積/抽出は複数出力を許容）
- `as` と `$var` を最小実装（`.expr as $x | ...` で束縛）
- 非有限数（Infinity/NaN）の扱いは未整理（現状は `Double` 依存）
- `contains`/`startswith`/`endswith` は文字列/配列の最小実装
- `empty` と `//` は最小実装（出力が空かどうかでフォールバック）

## Build (Native)

### Windows

- Visual Studio Build Tools (C++ build tools) と Windows 10/11 SDK が必要
- Developer Command Prompt for VS を使う（`INCLUDE`/`LIB`/`PATH` が通る）
- 例:
  - `moon test --target native --package core`
  - `moon run --target native cmd/jqx -- ".foo" '{"foo": 1}'`
  - `moon build --target native cmd/jqx`（ビルド後 `_build/native/release` から `jqx.exe` を実行）

### macOS

- Xcode Command Line Tools が必要
- 例:
  - `moon test --target native --package core`
  - `moon run --target native cmd/jqx -- ".foo" '{"foo": 1}'`
  - `moon build --target native cmd/jqx`（ビルド後 `_build/native/release` の `jqx` を実行）

### Linux

- gcc/clang などの C toolchain が必要
- 例:
  - `moon test --target native --package core`
  - `moon run --target native cmd/jqx -- ".foo" '{"foo": 1}'`
  - `moon build --target native cmd/jqx`（ビルド後 `_build/native/release` の `jqx` を実行）

## CI

- GitHub Actions で Windows/macOS/Linux の native テストを実行する
- Windows は `vcvars64.bat` 経由で実行（`INCLUDE`/`LIB`/`PATH` を通す）
