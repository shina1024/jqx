# @shina1024/jqx-zod-adapter

Zod integration helpers for `jqx` JS/TS runtime.

## Status

This package is an adapter layer.
It accepts a runtime implementation via dependency injection.
Core runtime/result/inference helpers are shared via
`@shina1024/jqx-adapter-core`.
If you use the unified entrypoint package, import this adapter from `@shina1024/jqx/zod`.
Install `zod` in the consumer project when using this adapter.

## Scripts

```bash
pnpm build
pnpm format
pnpm format:check
pnpm lint
pnpm lint:fix
pnpm typecheck
pnpm test
```

## Core APIs

- `createAdapter(runtime).filter(options)`
- `createAdapter(runtime).inferred(options)`
- `createQueryAdapter(runtime).query(options)`

See `src/index.ts` for full types.
