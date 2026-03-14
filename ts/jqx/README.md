# @shina1024/jqx

Direct-use JS/TS runtime for `jqx`. Start with `run(filter, input)` from `@shina1024/jqx`, and use `@shina1024/jqx/bind` only when you need to connect a custom backend.

## Quick Start

`@shina1024/jqx` is the main end-user surface. It bundles the MoonBit runtime and runs synchronously.

```ts
import { isValidJson, parseJson, run } from "@shina1024/jqx";

const values = run(".users[].name", {
  users: [{ name: "alice" }, { name: "bob" }],
});
// { ok: true, value: ["alice", "bob"] }

const parsed = parseJson('{"users":[{"name":"alice"}]}');
// { ok: true, value: { users: [{ name: "alice" }] } }

const valid = isValidJson('{"users":[{"name":"alice"}]}');
// true
```

Use the value lane when native JS values are convenient.

## Compatibility Lane

`runJsonText(...)` is the fidelity-sensitive lane when jq-style JSON text matters:

```ts
import { runJsonText } from "@shina1024/jqx";

const compat = runJsonText(".", "9007199254740993");
// { ok: true, value: ["9007199254740993"] }
```

## Compiled Reuse

```ts
import { compile } from "@shina1024/jqx";

const compiled = compile(".items[]");
if (compiled.ok) {
  const result = compiled.value.run({ items: [1, 2, 3] });
  const compat = compiled.value.runJsonText('{"items":[1,2,3]}');
}
```

Compiled filters are the explicit reuse path. They expose `.run(...)` for JSON values and `.runJsonText(...)` for the compatibility lane.

Compiled filters stay on the synchronous direct runtime. `@shina1024/jqx/bind` remains a JSON-text backend integration surface instead of implying a second compiled-filter transport.

## Secondary Root Exports

The root package also keeps a secondary query lane:

- `query(...)` and `queryJsonText(...)`
- typed DSL and AST helpers such as `field`, `pipe`, `select`, and `toAst`
- adapter-facing runtime objects: `runtime` and `queryRuntime`

Use those when you need typed query composition or adapter integration, but the normal on-ramp stays `run(filter, input)`.

### Query DSL

```ts
import { field, query } from "@shina1024/jqx";

const result = query(field("user"), { user: { name: "alice" } });
// { ok: true, value: [{ name: "alice" }] }
```

`query` accepts either a typed DSL `Query` or a plain `QueryAst`. `queryJsonText` is the compatibility-lane equivalent.

### Adapter Integration

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

Backends implement `runJsonText(...)` and optionally `runQueryJsonText(...)` or streaming methods. `bindRuntime` and `bindQueryRuntime` lift that JSON-text backend contract into value-lane and streaming helpers; they do not add compiled-filter methods.

Use `bindQueryRuntime` when the backend also implements `runQueryJsonText`.

## Package Entry Points

- `@shina1024/jqx`
  - canonical direct runtime: `run`, `runJsonText`, `compile`, `parseJson`, `isValidJson`
  - secondary query lane: `query`, `queryJsonText`, typed DSL and AST helpers
  - secondary integration helpers: `runtime`, `queryRuntime`
- `@shina1024/jqx/bind`
  - `bindRuntime`
  - `bindQueryRuntime`
  - binding-specific runtime and client types
- `@shina1024/jqx/zod`
- `@shina1024/jqx/yup`
- `@shina1024/jqx/valibot`

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
