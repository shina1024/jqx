# @shina1024/jqx-yup-adapter

Yup adapter for the stable `@shina1024/jqx` JS/TS runtime contract.

## Install

```bash
pnpm add @shina1024/jqx @shina1024/jqx-yup-adapter yup
```

Use this package when you want Yup to validate jqx inputs and outputs without depending on jqx runtime internals.

## Quick Start

`createAdapter(runtime).filter(...)` is the primary on-ramp:

```ts
import { runtime } from "@shina1024/jqx";
import { createAdapter } from "@shina1024/jqx-yup-adapter";
import * as yup from "yup";

const adapter = createAdapter(runtime);

const result = await adapter.filter({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }, { name: "bob" }] },
  inputSchema: yup
    .object({
      users: yup
        .array(
          yup
            .object({
              name: yup.string().defined(),
            })
            .defined(),
        )
        .defined(),
    })
    .defined(),
  outputSchema: yup.string().defined(),
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
import { createQueryAdapter } from "@shina1024/jqx-yup-adapter";

const queryAdapter = createQueryAdapter(queryRuntime);

const result = await queryAdapter.query({
  query: toAst(field("user")),
  input: { user: { name: "alice" } },
  inputSchema: yup
    .object({
      user: yup
        .object({
          name: yup.string().defined(),
        })
        .defined(),
    })
    .defined(),
  outputSchema: yup
    .object({
      name: yup.string().defined(),
    })
    .defined(),
});
```

## Error Model

Adapter errors keep the stable jqx top-level contract:

- `input_validation`
- `runtime`
- `output_validation`

The top-level `message` is jqx-owned for logging and control flow. `issues` stays native to Yup as `yup.ValidationError[]`.

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
