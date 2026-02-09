# JS/TS Zod Integration (Status + Plan)

Updated: 2026-02-09

## Goal

Provide a practical, type-safe integration path between `jqx` and Zod for JS/TS users.

The architecture keeps MoonBit `core/` pure and places Zod coupling in a TS adapter layer.

## Current Status

Implemented in `ts/zod-adapter`:

1. Adapter entrypoint:
   - `ts/zod-adapter/src/index.ts`
2. Dynamic/typed runtime APIs:
   - `safeRunWithZod`
   - `safeExecuteWithZod`
3. Helper/aliases:
   - `withZod`, `withZ`
   - `runWithZod`, `executeWithZod`
   - `runWithZ`, `executeWithZ`
4. Tests:
   - runtime tests: `ts/zod-adapter/test/index.test.ts`
   - static check: `pnpm typecheck`
5. CI:
   - Linux CI executes `pnpm lint`, `pnpm typecheck`, `pnpm test` in `ts/zod-adapter`

Still pending:

1. Final npm runtime binding and import design (`import { ... } from "jqx"`).
2. Dedicated compile-time assertion tests for inference behavior (for example `tsd` or `expectTypeOf`).

## Design Principles

1. Keep MoonBit runtime independent from JS validation libraries.
2. Validate unknown input at the TS boundary using Zod.
3. Prefer safe/result APIs over exception-first flows.
4. Use `unknown`/`Json` fallback where static inference is unsound.

## Runtime Shape

Current adapter API is runtime-injected and async by design:

```ts
import { z } from "zod";

type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

interface JqxDynamicRuntime {
  run(filter: string, input: string): JqxResult<string[]> | Promise<JqxResult<string[]>>;
}

interface JqxTypedRuntime<Q = unknown> {
  runQuery(query: Q, input: string): JqxResult<string[]> | Promise<JqxResult<string[]>>;
}

export async function safeRunWithZod<
  InSchema extends z.ZodTypeAny,
  OutSchema extends z.ZodTypeAny,
>(
  runtime: JqxDynamicRuntime,
  options: {
    filter: string;
    input: unknown;
    inputSchema: InSchema;
    outputSchema: OutSchema;
  },
): Promise<JqxResult<Array<z.output<OutSchema>>>>;

export async function safeExecuteWithZod<
  Q,
  InSchema extends z.ZodTypeAny,
  OutSchema extends z.ZodTypeAny,
>(
  runtime: JqxTypedRuntime<Q>,
  options: {
    query: Q;
    input: unknown;
    inputSchema: InSchema;
    outputSchema: OutSchema;
  },
): Promise<JqxResult<Array<z.output<OutSchema>>>>;
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

Use either lane:

1. Dynamic lane:
   - run with `run`/`safe*`
   - treat values as `unknown`/`Json`
2. Typed lane:
   - validate input with `inputSchema`
   - execute query
   - validate outputs with `outputSchema`

## Next Steps

1. Add compile-time type assertion tests for adapter and typed query composition.
2. Finalize npm package layout and runtime binding so users can import from the stable public entrypoint.
3. Add docs/examples that show end-to-end usage with real `jqx` runtime wiring.

## Naming Guidance

Primary names:

1. `safeRunWithZod`
2. `safeExecuteWithZod`

Convenience aliases:

1. `runWithZod`, `executeWithZod`
2. `runWithZ`, `executeWithZ`
