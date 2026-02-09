# @shina1024/jqx-yup-adapter

Yup integration helpers for `jqx` JS/TS runtime.

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

- `safeRunWithYup(runtime, options)`
- `safeExecuteWithYup(runtime, options)`
- `withYup(runtime)` / `withY(runtime)` helper

See `src/index.ts` for full types.
