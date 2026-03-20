# @shina1024/jqx-valibot-adapter

Valibot adapter for the stable `@shina1024/jqx` JS/TS runtime contract.

## Install

```bash
pnpm add @shina1024/jqx @shina1024/jqx-valibot-adapter valibot
```

Use this package when you want Valibot to validate jqx inputs and outputs without depending on jqx runtime internals.

## Quick Start

`createAdapter(runtime).filter(...)` is the primary on-ramp:

```ts
import { runtime } from "@shina1024/jqx";
import { createAdapter } from "@shina1024/jqx-valibot-adapter";
import * as v from "valibot";

const adapter = createAdapter(runtime);

const result = await adapter.filter({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }, { name: "bob" }] },
  inputSchema: v.object({
    users: v.array(
      v.object({
        name: v.string(),
      }),
    ),
  }),
  outputSchema: v.string(),
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
import { createQueryAdapter } from "@shina1024/jqx-valibot-adapter";

const queryAdapter = createQueryAdapter(queryRuntime);

const result = await queryAdapter.query({
  query: toAst(field("user")),
  input: { user: { name: "alice" } },
  inputSchema: v.object({
    user: v.object({
      name: v.string(),
    }),
  }),
  outputSchema: v.object({
    name: v.string(),
  }),
});
```

## Error Model

Adapter errors keep the stable jqx top-level contract:

- `input_validation`
- `runtime`
- `output_validation`

The top-level `message` is jqx-owned for logging and control flow. `issues` stays native to Valibot as `BaseIssue<unknown>[]`.

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
