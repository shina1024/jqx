# jqx

A jq-compatible executable and JS/TS library written in MoonBit.

## Install

- CLI executable: `jqx` (download from GitHub Releases)
- npm package: `@shina1024/jqx`
- mooncakes.io package: planned

```bash
npm install @shina1024/jqx
```

Optional validator packages:

```bash
npm install zod
# or: npm install yup
# or: npm install valibot
```

## CLI Quick Start

Assuming `jqx` is in your `PATH`:

```bash
# stdin
echo '{"foo": 1}' | jqx ".foo"

# argument input
jqx ".foo" '{"foo": 1}'
```

Common options:

```bash
# Raw string output (no JSON quotes)
jqx -r ".foo" '{"foo":"bar"}'

# Raw input mode (line-based strings)
jqx -R "." "a\nb"

# Raw input slurp
jqx -R -s "." "a\nb\n"

# Null input
jqx -n "."

# Slurp inputs into one array
jqx -s "." "1"

# jq -e style exit status
jqx -e ".ok" '{"ok": false}'
```

## npm Quick Start

Entry points:
- `import { createJqx, createQueryJqx } from "@shina1024/jqx"`
- `import { createAdapter } from "@shina1024/jqx/zod"`
- `import { createAdapter } from "@shina1024/jqx/yup"`
- `import { createAdapter } from "@shina1024/jqx/valibot"`

Runtime binding example (`createJqx`):

```ts
import { createJqx } from "@shina1024/jqx";

const jqx = createJqx({
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
});

const out = await jqx.run(".", { x: 1 });
```

Query lane example (`createQueryJqx` + `QueryAst`):

```ts
import { createQueryJqx, type QueryAst } from "@shina1024/jqx";

const jqx = createQueryJqx<QueryAst>({
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
  async runQueryJsonText(query, input) {
    return { ok: true as const, value: [input] };
  },
});

const out = await jqx.query({ kind: "identity" }, { x: 1 });
```

Backend runtime contract:
- `createJqx`: implement `runJsonText(filter: string, input: string)` and return `JqxResult<string[], JqxRuntimeError>`
- `createQueryJqx`: additionally implement `runQueryJsonText(query: QueryAst, input: string)`
- `runJsonText`/`runQueryJsonText` outputs are JSON texts (`string[]`), one entry per jq output

Error handling guideline:

```ts
import { createJqx, runtimeErrorToMessage } from "@shina1024/jqx";

const jqx = createJqx({
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
});

const result = await jqx.run(".foo", { foo: 1 });
if (!result.ok) {
  console.error(runtimeErrorToMessage(result.error));
}
```

Schema adapter example (Zod):

```ts
import { z } from "zod";
import { createAdapter, type JqxRuntime } from "@shina1024/jqx/zod";

const runtime: JqxRuntime = {
  async run(filter, input) {
    return { ok: true as const, value: ["alice", "bob"] };
  },
};

const adapter = createAdapter(runtime);
const result = await adapter.filter({
  filter: ".users[].name",
  input: { users: [{ name: "alice" }, { name: "bob" }] },
  inputSchema: z.object({ users: z.array(z.object({ name: z.string() })) }),
  outputSchema: z.string(),
});
```
