# Agent TODO

- [x] Typed lane を `Query[I, O]` で実用化する（`identity` / `field` / `index` / `pipe` / `map` 以外の型付きコンビネータを追加）
- [x] Zod/Yup/Valibot アダプタの compile-time 型アサーションテストを追加する（`tsd` または `expectTypeOf`）
- [x] jq 文字列 API 向けに「部分推論 + `unknown`/`Json` フォールバック」の型推論レイヤを追加する
- [x] jq 文字列からの型推論は完全推論を目指さず、推論不能箇所の明示ルールをドキュメント化する
- [x] スキーマ入力 + jq 文字列実行 + 出力スキーマ検証の end-to-end 利用例を docs に追加する
