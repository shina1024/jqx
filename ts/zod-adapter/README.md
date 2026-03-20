# @shina1024/jqx-zod-adapter

Zod adapter for the stable `@shina1024/jqx` JS/TS runtime contract.

## Install

```bash
pnpm add @shina1024/jqx @shina1024/jqx-zod-adapter zod
```

Use this package when you want Zod to validate jqx inputs and outputs without coupling application code to jqx runtime internals.

## Quick Start

`createAdapter(runtime).filter(...)` is the primary on-ramp:

```ts
import { runtime } from "@shina1024/jqx";
import { createAdapter } from "@shina1024/jqx-zod-adapter";
import { z } from "zod";

const adapter = createAdapter(runtime);

const result = await adapter.filter({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }, { name: "bob" }] },
  inputSchema: z.object({
    users: z.array(z.object({ name: z.string() })),
  }),
  outputSchema: z.string(),
});
```

## Stable Runtime Contract

This adapter sits on the stable jqx runtime contract. Most applications pass `runtime` from `@shina1024/jqx`, but any compatible `JqxRuntime` or `JqxQueryRuntime` implementation works.

## Secondary APIs

### `infer(...)`

Use `infer(...)` when you want filter-based type inference without schema validation:

```ts
const inferred = await adapter.infer({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }] },
});
```

### `createQueryAdapter(runtime).query(...)`

Use the query adapter only when you are already working with jqx query AST helpers:

```ts
import { field, queryRuntime, toAst } from "@shina1024/jqx";
import { createQueryAdapter } from "@shina1024/jqx-zod-adapter";

const queryAdapter = createQueryAdapter(queryRuntime);

const result = await queryAdapter.query({
  query: toAst(field("user")),
  input: { user: { name: "alice" } },
  inputSchema: z.object({
    user: z.object({ name: z.string() }),
  }),
  outputSchema: z.object({ name: z.string() }),
});
```

## Error Model

Adapter errors keep the stable jqx top-level contract:

- `input_validation`
- `runtime`
- `output_validation`

The top-level `message` is jqx-owned for logging and control flow. `issues` stays native to Zod as `z.ZodIssue[]`.

## Scripts

```bash
pnpm build
pnpm format
pnpm format:check
pnpm lint
pnpm lint:typeaware
pnpm lint:fix
pnpm typecheck
pnpm test
```

`pnpm build` bundles ESM/CJS with `tsdown` and emits declarations with `tsgo`. `pnpm typecheck` uses `tsgo`.

## Related Docs

- Runtime and bind surface: [`../jqx/README.md`](../jqx/README.md)
- Root cross-surface overview: [`../../README.mbt.md`](../../README.mbt.md)
