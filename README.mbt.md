# jqx

A jq-compatible executable and JS/TS library written in MoonBit.

## Install

- CLI executable: `jqx` (download from GitHub Releases)
- npm package: `@shina1024/jqx`
- MoonBit package on `mooncakes.io`: planned

```bash
npm install @shina1024/jqx
```

Optional validator packages:

```bash
npm install zod
# or: npm install yup
# or: npm install valibot
```

## MoonBit Quick Start

MoonBit users should use the top-level `shina1024/jqx` package API.

Value lane example:

```mbt check
///|
test "moonbit run on standard Json" {
  let input : Json = { "foo": 41.0 }
  let outputs = run(".foo + 1", input) catch { err => fail(err.to_string()) }
  assert_eq(outputs.length(), 1)
  assert_eq(outputs[0].stringify(), "42")
}
```

Compiled execution:

```mbt check
///|
test "moonbit compile and run_compiled" {
  let filter = compile(".items[]") catch { err => fail(err.to_string()) }
  let input : Json = { "items": [1.0, 2.0, 3.0] }
  let outputs = run_compiled(filter, input) catch {
    err => fail(err.to_string())
  }
  assert_eq(outputs.map(v => v.stringify()), ["1", "2", "3"])
}
```

Compatibility lane:

```mbt check
///|
test "moonbit run_json_text preserves output text" {
  let outputs = run_json_text(".", "9007199254740993") catch {
    err => fail(err.to_string())
  }
  assert_eq(outputs, ["9007199254740993"])
}
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
- `import { createRuntime, createQueryRuntime } from "@shina1024/jqx"`
- `import { createAdapter } from "@shina1024/jqx/zod"`
- `import { createAdapter } from "@shina1024/jqx/yup"`
- `import { createAdapter } from "@shina1024/jqx/valibot"`

Runtime binding example (`createRuntime`):

```ts
import { createRuntime } from "@shina1024/jqx";

const jqx = createRuntime({
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
});

const out = await jqx.run(".", { x: 1 });
```

Query lane example (`createQueryRuntime` + `QueryAst`):

```ts
import { createQueryRuntime, type QueryAst } from "@shina1024/jqx";

const jqx = createQueryRuntime<QueryAst>({
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
- `createRuntime`: implement `runJsonText(filter: string, input: string)` and return `JqxResult<string[], JqxRuntimeError>`
- `createQueryRuntime`: additionally implement `runQueryJsonText(query: QueryAst, input: string)`
- `runJsonText`/`runQueryJsonText` outputs are JSON texts (`string[]`), one entry per jq output

Error handling guideline:

```ts
import { createRuntime, runtimeErrorToMessage } from "@shina1024/jqx";

const jqx = createRuntime({
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
