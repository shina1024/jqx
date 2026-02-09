# JS/TS Zod Integration Plan

Updated: 2026-02-10

## Goal

Provide a practical, type-safe integration path between `jqx` and Zod for JS/TS users.

This plan keeps MoonBit core pure and puts Zod coupling in a TS wrapper layer.

## Current Implementation

Implemented scaffold:

1. `ts/zod-adapter/src/index.ts`
2. Runtime-injected APIs:
   - `safeRunWithZod`
   - `safeExecuteWithZod`
   - `withZod` / `withZ`
3. Runtime and typecheck tests:
   - `ts/zod-adapter/test/index.test.ts`

Not implemented yet:

1. Binding this adapter to the final published `jqx` npm runtime package.
2. CI job for TypeScript adapter tests in this repository workflow.

## Design Principles

1. Keep `core/` and MoonBit `js/` package free from JS library dependencies.
2. Use Zod at the boundary where unknown input enters the system.
3. Prefer safe APIs (`Result`/`safe*`) over exception-first APIs in JS/TS.
4. Fall back to `unknown` where static inference is not sound.

## Layering

1. MoonBit core/runtime layer:
   - Parse/eval runtime (`parseJson`, `safeParseJson`, `execute`, `safeExecute`, `run`)
   - Typed DSL scaffold (`Query[I, O]`) for composition semantics
2. TS adapter layer (new):
   - Accepts Zod schemas
   - Validates input/output
   - Exposes fully typed helper APIs

## Proposed TS Adapter APIs

The APIs below are in the TS wrapper package (not MoonBit source files).

```ts
import type { ZodTypeAny, infer as Infer } from "zod";

type JqxResult<T> = { ok: true; value: T } | { ok: false; error: string };

export function safeRunWithZod<
  InSchema extends ZodTypeAny,
  OutSchema extends ZodTypeAny,
>(
  filter: string,
  input: unknown,
  options: {
    inputSchema: InSchema;
    outputSchema: OutSchema;
  },
): JqxResult<Array<Infer<OutSchema>>>;

export function safeExecuteWithZod<
  InSchema extends ZodTypeAny,
  OutSchema extends ZodTypeAny,
>(
  filter: unknown, // runtime filter object, adapter-owned
  input: unknown,
  options: {
    inputSchema: InSchema;
    outputSchema: OutSchema;
  },
): JqxResult<Array<Infer<OutSchema>>>;
```

## Unknown JSON Strategy

When input shape is unknown, `jqx` cannot infer strong types from jq/filter text alone.

Use one of these:

1. Dynamic lane:
   - Use `run` / `safe*` APIs
   - Treat values as `unknown`/`Json`
2. Typed lane:
   - Validate with `inputSchema` (Zod)
   - Then run typed operations
   - Optionally validate outputs with `outputSchema`

## Error Model

TS adapter should normalize errors into one union:

1. `InputValidationError` (Zod input parse failed)
2. `RuntimeError` (`jqx` parse/eval failure)
3. `OutputValidationError` (Zod output parse failed)

For compatibility with current APIs, expose a string-based shorthand (`error: string`) first.

## Phased Rollout

1. Phase 1 (done):
   - Introduce TS adapter package with `safeRunWithZod` (dynamic path)
2. Phase 2 (done):
   - Add `safeExecuteWithZod` for compiled/typed query path
3. Phase 3:
   - Type tests (`tsd` or `vitest` + `expectTypeOf`)
   - Runtime tests with real Zod schemas
4. Phase 4:
   - Publish npm package and document import path (`import { ... } from "jqx"`)

## Naming Notes

Recommended public names:

1. `safeRunWithZod`
2. `safeExecuteWithZod`

Optional aliases:

1. `runWithZod`
2. `executeWithZod`
3. `runWithZ` / `executeWithZ` (short aliases, not primary docs names)
