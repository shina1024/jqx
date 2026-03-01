# @shina1024/jqx

npm-facing JS/TS entrypoint for `@shina1024/jqx`.

## Exports

- `@shina1024/jqx`:
  - runtime/result/core types
  - `bindRuntime(runtime)` / `createRuntime(runtime)`
  - Typed DSL combinators (`identity`, `field`, `pipe`, `map`, `select`, ...)
- `@shina1024/jqx/zod`: re-exports `@shina1024/jqx-zod-adapter`
- `@shina1024/jqx/yup`: re-exports `@shina1024/jqx-yup-adapter`
- `@shina1024/jqx/valibot`: re-exports `@shina1024/jqx-valibot-adapter`

## Runtime Binding

```ts
import { bindRuntime } from "@shina1024/jqx";

const runtime = bindRuntime({
  run(filter, input) {
    // connect to MoonBit-generated JS runtime here
    return { ok: true, value: [input] };
  },
});

const out = await runtime.run(".", '{"x":1}');
```

## Typed DSL (compile-time inference)

```ts
import { field, identity, pipe } from "@shina1024/jqx";

type Input = { user: { name: string } };
const q = pipe(identity<Input>(), pipe(field("user"), field("name")));
// q: Query<Input, string>
```

## Typed DSL Runtime Bridge (`QueryAst -> runtime`)

```ts
import { field, identity, pipe, runTypedQuery, type QueryAst } from "@shina1024/jqx";

const runtime = {
  runQuery(query: QueryAst, input: string) {
    // connect to a runtime lane that accepts QueryAst
    return { ok: true as const, value: [input] };
  },
};

const q = pipe(identity<{ user: { name: string } }>(), pipe(field("user"), field("name")));
const out = await runTypedQuery(runtime, q, '{"user":{"name":"alice"}}');
```

## Scripts

```bash
pnpm build
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
```
