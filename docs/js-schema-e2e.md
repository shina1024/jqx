# JS/TS E2E Examples (Schema + jq String + Output Validation)

Updated: 2026-02-10

This document shows end-to-end usage for:

1. schema-validated input
2. jq string execution
3. schema-validated output

All examples use the same runtime shape:

```ts
type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

interface JqxDynamicRuntime {
  run(filter: string, input: string): JqxResult<string[]> | Promise<JqxResult<string[]>>;
}
```

In real apps, `runtime.run(...)` should call your actual `jqx` JS runtime entrypoint.

## Zod Adapter

```ts
import { z } from "zod";
import { createAdapter } from "@shina1024/jqx-zod-adapter";

const runtime = {
  async run(filter: string, input: string) {
    // Replace this with the actual jqx runtime call:
    // return jqx.run(filter, input);
    return { ok: true as const, value: ['"alice"', '"bob"'] };
  },
};

const inputSchema = z.object({
  users: z.array(z.object({ name: z.string() })),
});

const outputSchema = z.string();

const adapter = createAdapter(runtime);
const result = await adapter.filter({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }, { name: "bob" }] },
  inputSchema,
  outputSchema,
});

if (!result.ok) {
  // result.error.kind: input_validation | runtime | output_parse | output_validation
  console.error(result.error);
} else {
  // result.value: string[]
  console.log(result.value);
}
```

## Yup Adapter

```ts
import * as yup from "yup";
import { createAdapter } from "@shina1024/jqx-yup-adapter";

const runtime = {
  async run(filter: string, input: string) {
    return { ok: true as const, value: ['{"id":1}', '{"id":2}'] };
  },
};

const inputSchema = yup
  .object({
    items: yup
      .array(yup.object({ id: yup.number().required() }).required())
      .required(),
  })
  .required();

const outputSchema = yup
  .object({
    id: yup.number().required(),
  })
  .required();

const adapter = createAdapter(runtime);
const result = await adapter.filter({
  filter: ".items[]",
  input: { items: [{ id: 1 }, { id: 2 }] },
  inputSchema,
  outputSchema,
});

if (!result.ok) {
  console.error(result.error);
} else {
  // result.value: Array<{ id: number }>
  console.log(result.value);
}
```

## Valibot Adapter

```ts
import * as v from "valibot";
import { createAdapter } from "@shina1024/jqx-valibot-adapter";

const runtime = {
  async run(filter: string, input: string) {
    return { ok: true as const, value: ["1", "2", "3"] };
  },
};

const inputSchema = v.object({
  values: v.array(v.number()),
});

const outputSchema = v.number();

const adapter = createAdapter(runtime);
const result = await adapter.filter({
  filter: ".values[]",
  input: { values: [1, 2, 3] },
  inputSchema,
  outputSchema,
});

if (!result.ok) {
  console.error(result.error);
} else {
  // result.value: number[]
  console.log(result.value);
}
```

## Optional: jq String Partial Inference + Schema Validation

If you want type hints from the jq string itself (best-effort), use `adapter.inferred`.
Then keep schema validation for runtime safety in production.

```ts
import { createAdapter } from "@shina1024/jqx-zod-adapter";

const adapter = createAdapter(runtime);
const inferred = await adapter.inferred({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }] },
});

// inferred.value is inferred as string[] for the supported subset.
```

Inference is partial and conservative; unsupported syntax falls back to `unknown`
by default (or `Json` with `fallback: "json"`).
