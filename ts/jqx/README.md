# @shina1024/jqx

npm-facing JS/TS entrypoint for `@shina1024/jqx`.

## Exports

- `@shina1024/jqx`:
  - runtime/result/core types
  - `createJqx(backend)` (dynamic lane)
  - `createQueryJqx(backend)` (query lane)
  - Typed DSL combinators (`identity`, `field`, `pipe`, `map`, `select`, ...)
- `@shina1024/jqx/zod`: re-exports `@shina1024/jqx-zod-adapter`
- `@shina1024/jqx/yup`: re-exports `@shina1024/jqx-yup-adapter`
- `@shina1024/jqx/valibot`: re-exports `@shina1024/jqx-valibot-adapter`

## Factory Choice

- Use `createJqx` when you only need jq-string filters (`run` / `runJsonText`).
- Use `createQueryJqx` when runtime also supports `runQueryJsonText`.
- With `createQueryJqx`, Typed DSL `Query` input is accepted when `Q` is `QueryAst`.

## Runtime Bridge (`runJsonText -> run`)

```ts
import { createJqx } from "@shina1024/jqx";

const jqx = createJqx({
  runJsonText(filter, input) {
    // connect to MoonBit-generated JS runtime here
    return { ok: true, value: [input] };
  },
});

const out = await jqx.run(".", { x: 1 }); // Json[] output
// `run` / `query` inputs are Json values.
```

## Streaming Lane (`AsyncIterable`)

All client factories expose stream methods:

- `runJsonTextStream(filter, input): AsyncIterable<JqxResult<string, JqxRuntimeError>>`
- `runStream(filter, input): AsyncIterable<JqxResult<Json, JqxRuntimeError>>`
- `queryJsonTextStream(query, input): AsyncIterable<JqxResult<string, JqxRuntimeError>>` (query backend)
- `queryStream(query, input): AsyncIterable<JqxResult<Json, JqxRuntimeError>>` (query backend)

Backend contract (optional):

- `runJsonTextStream(filter, input) -> JqxResult<AsyncIterable<string>, JqxRuntimeError>`
- `runQueryJsonTextStream(query, input) -> JqxResult<AsyncIterable<string>, JqxRuntimeError>`

If backend stream methods are absent, client falls back to `runJsonText` / `runQueryJsonText` and emits each array element as stream items.

Error behavior:

- backend/runtime failure: emits one `{ ok: false, error }` item and ends
- `runStream` / `queryStream` output JSON parse failure: emits `{ kind: "output_parse", index, ... }` and ends

## Runtime Error Model

`run` / `query` / `runJsonText` / `queryJsonText` return `JqxRuntimeError` as a discriminated union:

- `{ kind: "backend_runtime", message, details? }`
- `{ kind: "input_stringify", message }`
- `{ kind: "output_parse", message, index }`

Helpers:

- `runtimeErrorToMessage(error)`
- `isJqxRuntimeError(value)`
- `toJqxRuntimeError(value)`

## Typed DSL (compile-time inference)

```ts
import { field, identity, pipe } from "@shina1024/jqx";

type Input = { user: { name: string } };
const q = pipe(identity<Input>(), pipe(field("user"), field("name")));
// q: Query<Input, string>
```

## QueryAst Interop

External interchange uses a versioned document envelope:

```json
{
  "format": "jqx-query-ast",
  "version": 1,
  "ast": { "kind": "field", "name": "user" }
}
```

Helpers:

- `exportQueryAstDocument(ast)`
- `exportTypedQueryDocument(query)`
- `importQueryAstDocument(value)`
- `parseQueryAstDocument(text)`
- `stringifyQueryAstDocument(ast)`

Compatibility rule:

- importer accepts only the document envelope (`format/version/ast`)
- unknown `version` is rejected as `unsupported_version`

## Query Runtime Bridge (`runQueryJsonText -> query`)

```ts
import { createQueryJqx, field, identity, pipe, type QueryAst } from "@shina1024/jqx";

const jqx = createQueryJqx({
  runJsonText(filter: string, input: string) {
    return { ok: true as const, value: [input] };
  },
  runQueryJsonText(query: QueryAst, input: string) {
    // connect to a runtime lane that accepts QueryAst
    return { ok: true as const, value: [input] };
  },
});

const q = pipe(identity<{ user: { name: string } }>(), pipe(field("user"), field("name")));
const out = await jqx.query(q, { user: { name: "alice" } });
// passing QueryAst is also supported: jqx.query({ kind: "identity" }, input)
// Typed DSL query input is available when backend query type is QueryAst.
```

## Scripts

```bash
pnpm build
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
```
