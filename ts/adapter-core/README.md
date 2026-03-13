# @shina1024/jqx-adapter-core

Shared runtime/result/inference utilities for jqx TypeScript adapters.

This package is an internal building block for adapter packages such as:

- `@shina1024/jqx-zod-adapter`
- `@shina1024/jqx-yup-adapter`
- `@shina1024/jqx-valibot-adapter`

## Scripts

```bash
pnpm build
pnpm format
pnpm format:check
pnpm lint
pnpm lint:typeaware
pnpm typecheck
```

`pnpm build` bundles ESM/CJS with `esbuild` and emits declarations with `tsgo`. `pnpm typecheck` uses `tsgo`.
