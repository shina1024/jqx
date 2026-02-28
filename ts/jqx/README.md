# @shina1024/jqx

npm-facing JS/TS entrypoint for `@shina1024/jqx`.

## Exports

- `@shina1024/jqx`:
  - runtime/result/core types
  - `bindRuntime(runtime)` / `createRuntime(runtime)`
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

## Scripts

```bash
pnpm build
pnpm format:check
pnpm lint
pnpm typecheck
pnpm test
```
