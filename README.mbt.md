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
The normal path is standard `Json` via `run(filter, input)`.

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
test "moonbit compile and run through a compiled filter" {
  let filter = compile(".items[]") catch { err => fail(err.to_string()) }
  let input : Json = { "items": [1.0, 2.0, 3.0] }
  let outputs = filter.run(input) catch { err => fail(err.to_string()) }
  assert_eq(outputs.map(v => v.stringify()), ["1", "2", "3"])
}
```

Compiled filters expose `run(...)` for the value lane and `run_json_text(...)` for the compatibility lane.

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

Boundary helpers:
- `is_valid_json(...)` and `parse_json(...)` are input-boundary helpers, not the main happy path.
- When jq-style numeric or output fidelity matters, use `run_json_text(...)` or `CompiledFilter::run_json_text(...)` before reaching for any advanced helper.
- Normal MoonBit usage should stay on `shina1024/jqx`; you should not need `shina1024/jqx/core`, `@core.Value`, or `@core.Filter`.

## CLI Quick Start

Use the `jqx` executable once it is in your `PATH`:

```bash
# stdin input
echo '{"foo": 1}' | jqx ".foo"

# direct input argument
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
- `import { run, runJsonText, compile, query } from "@shina1024/jqx"`
- `import { bindRuntime, bindQueryRuntime } from "@shina1024/jqx/bind"`
- `import { createAdapter } from "@shina1024/jqx/zod"`
- `import { createAdapter } from "@shina1024/jqx/yup"`
- `import { createAdapter } from "@shina1024/jqx/valibot"`

Direct-use runtime example:

```ts
import { run, runJsonText } from "@shina1024/jqx";

const values = run(".foo", { foo: 1 });
const compat = runJsonText(".", "9007199254740993");
```

Compiled / query example:

```ts
import { compile, field, query } from "@shina1024/jqx";

const compiled = compile(".items[]");
if (compiled.ok) {
  const out = compiled.value.run({ items: [1, 2, 3] });
}

const selected = query(field("user"), { user: { name: "alice" } });
```

Binding example (`@shina1024/jqx/bind`):

```ts
import { bindRuntime, type JqxJsonTextRuntime } from "@shina1024/jqx/bind";

const backend: JqxJsonTextRuntime = {
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
};

const jqx = bindRuntime(backend);
const out = await jqx.run(".", { x: 1 });
```

Backend runtime contract:
- `bindRuntime`: implement `runJsonText(filter: string, input: string)` and return `JqxResult<string[], JqxRuntimeError>`
- `bindQueryRuntime`: additionally implement `runQueryJsonText(query: QueryAst, input: string)`
- `runJsonText`/`runQueryJsonText` outputs are JSON texts (`string[]`), one entry per jq output

Error handling guideline:

```ts
import { run, runtimeErrorToMessage } from "@shina1024/jqx";

const result = run(".foo", { foo: 1 });
if (!result.ok) {
  console.error(runtimeErrorToMessage(result.error));
}
```

Schema adapter example (Zod):

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
