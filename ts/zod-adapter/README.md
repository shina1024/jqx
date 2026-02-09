# @shina1024/jqx-zod-adapter

Zod integration helpers for `jqx` JS/TS runtime.

## Status

This package is an adapter layer.
It accepts a runtime implementation via dependency injection.

## Scripts

```bash
pnpm format
pnpm format:check
pnpm lint
pnpm lint:fix
pnpm typecheck
pnpm test
```

## Core APIs

- `safeRunWithZod(runtime, options)`
- `safeExecuteWithZod(runtime, options)`
- `withZod(runtime)` / `withZ(runtime)` helper

See `src/index.ts` for full types.
