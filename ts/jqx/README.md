# @shina1024/jqx

npm-facing JS/TS entrypoint for `@shina1024/jqx`.

## Exports

- `@shina1024/jqx`:
  - runtime/result/core types
  - `createJqx(backend)`
  - Typed DSL combinators (`identity`, `field`, `pipe`, `map`, `select`, ...)
- `@shina1024/jqx/zod`: re-exports `@shina1024/jqx-zod-adapter`
- `@shina1024/jqx/yup`: re-exports `@shina1024/jqx-yup-adapter`
- `@shina1024/jqx/valibot`: re-exports `@shina1024/jqx-valibot-adapter`

## Runtime Bridge (`runRaw -> run`)

```ts
import { createJqx } from "@shina1024/jqx";

const jqx = createJqx({
  runRaw(filter, input) {
    // connect to MoonBit-generated JS runtime here
    return { ok: true, value: [input] };
  },
});

const out = await jqx.run(".", { x: 1 }); // Json[] output
```

## Typed DSL (compile-time inference)

```ts
import { field, identity, pipe } from "@shina1024/jqx";

type Input = { user: { name: string } };
const q = pipe(identity<Input>(), pipe(field("user"), field("name")));
// q: Query<Input, string>
```

## Typed Runtime Bridge (`runQueryRaw -> query`)

```ts
import { createJqx, field, identity, pipe, type QueryAst } from "@shina1024/jqx";

const jqx = createJqx({
  runRaw(filter: string, input: string) {
    return { ok: true as const, value: [input] };
  },
  runQueryRaw(query: QueryAst, input: string) {
    // connect to a runtime lane that accepts QueryAst
    return { ok: true as const, value: [input] };
  },
});

const q = pipe(identity<{ user: { name: string } }>(), pipe(field("user"), field("name")));
const out = await jqx.query(q, { user: { name: "alice" } });
// passing QueryAst is also supported: jqx.query({ kind: "identity" }, input)
// (Query direct input is available when backend query type is QueryAst)
```

## Scripts

```bash
pnpm build
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
```
