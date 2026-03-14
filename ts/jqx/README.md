# @shina1024/jqx

Direct-use JS/TS runtime for `jqx`, plus typed query helpers and schema-adapter entrypoints.

## Exports

- `@shina1024/jqx`
  - direct runtime: `run`, `runJsonText`, `compile`
  - JSON helpers: `parseJson`, `isValidJson`
  - query lane: `query`, `queryJsonText`
  - adapter-ready runtime objects: `runtime`, `queryRuntime`
  - typed DSL/query helpers: `identity`, `field`, `pipe`, `map`, `select`, `toAst`, ...
- `@shina1024/jqx/bind`
  - `bindRuntime`
  - `bindQueryRuntime`
  - binding-specific runtime/client types
- `@shina1024/jqx/zod`
- `@shina1024/jqx/yup`
- `@shina1024/jqx/valibot`

## Direct Runtime

`@shina1024/jqx` is the main end-user surface. It bundles the MoonBit runtime and runs synchronously.

```ts
import { run, runJsonText } from "@shina1024/jqx";

const values = run(".foo", { foo: 1 });
// { ok: true, value: [1] }

const compat = runJsonText(".", "9007199254740993");
// { ok: true, value: ["9007199254740993"] }
```

Use the value lane when native JS values are convenient, and the JSON text lane when jq-style text fidelity matters.

## Compiled Filters

```ts
import { compile } from "@shina1024/jqx";

const compiled = compile(".items[]");
if (compiled.ok) {
  const result = compiled.value.run({ items: [1, 2, 3] });
  const compat = compiled.value.runJsonText('{"items":[1,2,3]}');
}
```

Compiled filters expose `.run(...)` for JSON values and `.runJsonText(...)` for the compatibility lane.

## Query DSL

```ts
import { field, query } from "@shina1024/jqx";

const result = query(field("user"), { user: { name: "alice" } });
// { ok: true, value: [{ name: "alice" }] }
```

`query` accepts either a typed DSL `Query` or a plain `QueryAst`. `queryJsonText` is the compatibility lane equivalent.

## Schema Adapters

The main package exports `runtime` and `queryRuntime`, so adapters can consume the built-in runtime directly.

```ts
import { z } from "zod";
import { runtime } from "@shina1024/jqx";
import { createAdapter } from "@shina1024/jqx/zod";

const adapter = createAdapter(runtime);

const result = await adapter.filter({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }, { name: "bob" }] },
  inputSchema: z.object({ users: z.array(z.object({ name: z.string() })) }),
  outputSchema: z.string(),
});
```

## Binding API

Use `@shina1024/jqx/bind` only when you need to connect a custom backend, such as a remote worker, RPC service, or a separately managed MoonBit runtime.

```ts
import { bindRuntime } from "@shina1024/jqx/bind";

const jqx = bindRuntime({
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
});

const result = await jqx.run(".", { x: 1 });
```

Use `bindQueryRuntime` when the backend also implements `runQueryJsonText`.

## Error Model

Runtime operations return `JqxRuntimeError`:

- `{ kind: "backend_runtime", message, details? }`
- `{ kind: "input_stringify", message }`
- `{ kind: "output_parse", message, index }`

Helpers:

- `runtimeErrorToMessage(error)`
- `isJqxRuntimeError(value)`
- `toJqxRuntimeError(value)`

## Scripts

```bash
pnpm build
pnpm format
pnpm format:check
pnpm lint
pnpm lint:typeaware
pnpm typecheck
pnpm test
```

`pnpm build` bundles ESM/CJS with `esbuild` and emits declarations with `tsgo`. `pnpm typecheck` also uses `tsgo`.
The workspace pins `@typescript/native-preview` for `tsgo` and type-aware linting, so TS package verification follows the checked-in native-preview toolchain rather than a separately installed stock `typescript`.
