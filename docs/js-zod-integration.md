# JS/TS Schema Integration (Zod/Yup/Valibot)

Updated: 2026-02-09

## Goal

Provide practical, type-safe integration paths between `jqx` and popular JS/TS validators.

The architecture keeps MoonBit `core/` pure and places validator coupling in TS adapter layers.

## Current Status

Implemented adapters:

1. `ts/zod-adapter`
   - APIs: `safeRunWithZod`, `safeExecuteWithZod`
   - Helpers/aliases: `withZod`, `withZ`, `runWithZod`, `executeWithZod`, `runWithZ`, `executeWithZ`
2. `ts/yup-adapter`
   - APIs: `safeRunWithYup`, `safeExecuteWithYup`
   - Helpers/aliases: `withYup`, `withY`, `runWithYup`, `executeWithYup`, `runWithY`, `executeWithY`
3. `ts/valibot-adapter`
   - APIs: `safeRunWithValibot`, `safeExecuteWithValibot`
   - Helpers/aliases: `withValibot`, `withV`, `runWithValibot`, `executeWithValibot`, `runWithV`, `executeWithV`

Each adapter includes runtime tests, `pnpm typecheck`, and Linux CI coverage.

Still pending:

1. Final npm runtime binding and import design (`import { ... } from "jqx"`).
2. Dedicated compile-time assertion tests for inference behavior (for example `tsd` or `expectTypeOf`).

## Design Principles

1. Keep MoonBit runtime independent from JS validation libraries.
2. Validate unknown input at the TS boundary using a chosen validator.
3. Prefer safe/result APIs over exception-first flows.
4. Use `unknown`/`Json` fallback where static inference is unsound.

## Runtime Shape

All adapters use runtime injection and async-safe APIs:

```ts
export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

interface JqxDynamicRuntime {
  run(filter: string, input: string): JqxResult<string[]> | Promise<JqxResult<string[]>>;
}

interface JqxTypedRuntime<Q = unknown> {
  runQuery(query: Q, input: string): JqxResult<string[]> | Promise<JqxResult<string[]>>;
}
```

## Error Model

Adapter errors are normalized into a discriminated union:

1. `input_validation`
2. `runtime`
3. `output_parse`
4. `output_validation`

This keeps call sites explicit and stable for app-level error handling.

## Unknown JSON Strategy

When input shape is unknown, jq/filter text alone cannot provide strong static types.

1. Dynamic lane:
   - run with `run`/`safe*`
   - treat values as `unknown`/`Json`
2. Typed lane:
   - validate input with schema
   - execute query
   - validate outputs with schema

## Next Steps

1. Add compile-time type assertion tests for adapter and typed query composition.
2. Finalize npm package layout and runtime binding so users can import from the stable public entrypoint.
3. Add docs/examples showing end-to-end runtime wiring for each validator.
