# jqx

jq-compatible JSON processor written in MoonBit with a CLI and TypeScript bindings

## Install

CLI:
- Download the `jqx` executable from GitHub Releases.

MoonBit:

```bash
moon add shina1024/jqx
```

JS/TS runtime:

```bash
npm install @shina1024/jqx
```

Optional standalone adapters:

```bash
npm install @shina1024/jqx-zod-adapter zod
npm install @shina1024/jqx-yup-adapter yup
npm install @shina1024/jqx-valibot-adapter valibot
```

The root README is the cross-surface entrypoint. Detailed JS/TS runtime and validator-specific adapter guidance lives in the package READMEs under [`ts/jqx/README.md`](ts/jqx/README.md), [`ts/zod-adapter/README.md`](ts/zod-adapter/README.md), [`ts/yup-adapter/README.md`](ts/yup-adapter/README.md), and [`ts/valibot-adapter/README.md`](ts/valibot-adapter/README.md).

## CLI Quick Start

Use the `jqx` executable once it is available from GitHub Releases:

```bash
# stdin input
echo '{"foo": 1}' | jqx ".foo"

# direct input argument
jqx ".foo" '{"foo": 1}'
```

Common jq-compatible flags:

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

The CLI stays on the shared jq-compatible core. Use it when you want the release artifact surface rather than an embedded library API.

## MoonBit Quick Start

MoonBit users should use the top-level `shina1024/jqx` package API.
The normal path is standard `Json` via `run(filter, input)`. Reach for `compile(...)` when you want to reuse a filter, and use `run_json_text(...)` when jq-style text fidelity matters.

Add the package to your `moon.pkg` imports with an alias:

```moonbit
import {
  "moonbitlang/core/json",
  "shina1024/jqx" @jqx,
}
```

Value lane example:

```mbt nocheck
///|
test "moonbit run on standard Json" {
  let input : Json = { "foo": 41.0 }
  let outputs = @jqx.run(".foo + 1", input) catch { err => fail(err.to_string()) }
  assert_eq(outputs.length(), 1)
  assert_eq(outputs[0].stringify(), "42")
}
```

Compiled execution:

```mbt nocheck
///|
test "moonbit compile and run through a compiled filter" {
  let filter = @jqx.compile(".items[]") catch { err => fail(err.to_string()) }
  let input : Json = { "items": [1.0, 2.0, 3.0] }
  let outputs = filter.run(input) catch { err => fail(err.to_string()) }
  assert_eq(outputs.map(v => v.stringify()), ["1", "2", "3"])
}
```

Compiled filters expose `run(...)` for the value lane and `run_json_text(...)` for the compatibility lane.

Compatibility lane:

```mbt nocheck
///|
test "moonbit run_json_text preserves output text" {
  let outputs = @jqx.run_json_text(".", "9007199254740993") catch {
    err => fail(err.to_string())
  }
  assert_eq(outputs, ["9007199254740993"])
}
```

Boundary helpers:
- `@jqx.is_valid_json(...)` and `@jqx.parse_json(...)` are input-boundary helpers, not the main happy path.
- When jq-style numeric or output fidelity matters, use `@jqx.run_json_text(...)` or `CompiledFilter::run_json_text(...)` before reaching for any advanced helper.
- Normal MoonBit usage should stay on `shina1024/jqx`; you should not need `shina1024/jqx/core`, `@core.Value`, or `@core.Filter`.
- Release-readiness audit commands: `moon package --list --manifest-path moon.mod.json` should exclude development-only files and directories such as `scripts`, `third_party`, `ts`, and test files; `moon publish --dry-run --manifest-path moon.mod.json` requires `moon login`.

## JS/TS Quick Start

Start with the direct runtime from `@shina1024/jqx`:

```ts
import { run, runJsonText } from "@shina1024/jqx";

const values = run(".foo", { foo: 1 });
const compat = runJsonText(".", "9007199254740993");
```

In JS/TS, the value lane is intentionally stricter than jq itself. `run(...)`, `parseJson(...)`, and `isValidJson(...)` only accept values that remain representable as plain JS JSON values, so non-finite numbers such as `Infinity`, `-Infinity`, and `NaN` are rejected. When jq-compatible numeric fidelity matters, stay on `runJsonText(...)`.

Reuse a compiled filter when you expect to run the same jq program repeatedly:

```ts
import { compile } from "@shina1024/jqx";

const compiled = compile(".items[]");
if (compiled.ok) {
  const valueLane = compiled.value.run({ items: [1, 2, 3] });
  const textLane = compiled.value.runJsonText('{"items":[1,2,3]}');
}
```

`@shina1024/jqx/bind` is the backend-integration lane for custom JSON-text runtimes:

```ts
import { bindRuntime, type JqxJsonTextRuntime } from "@shina1024/jqx/bind";

const backend: JqxJsonTextRuntime = {
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
};

const jqx = bindRuntime(backend);
const result = await jqx.run(".", { x: 1 });
```

The detailed runtime, query, and binding contracts live in [`ts/jqx/README.md`](ts/jqx/README.md).

## Schema Adapter Example

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

Standalone adapter packages are:

- `@shina1024/jqx-zod-adapter`
- `@shina1024/jqx-yup-adapter`
- `@shina1024/jqx-valibot-adapter`

Each package keeps `createAdapter(runtime).filter(...)` as the primary on-ramp and owns its validator-specific details in its own README.

## Documentation Ownership

- Root README: cross-surface install story and one quick start per public surface.
- [`ts/jqx/README.md`](ts/jqx/README.md): detailed JS/TS runtime, compiled-filter, query, and `/bind` documentation.
- [`ts/zod-adapter/README.md`](ts/zod-adapter/README.md): Zod-specific adapter usage.
- [`ts/yup-adapter/README.md`](ts/yup-adapter/README.md): Yup-specific adapter usage.
- [`ts/valibot-adapter/README.md`](ts/valibot-adapter/README.md): Valibot-specific adapter usage.

That split keeps the root docs concise while the package READMEs own the detailed runtime and adapter guidance that changes more often.

When release-audit details change, update the package README that owns the surface first and then keep this root overview consistent with it.
That prevents the root docs from drifting back into a second source of truth for runtime-specific or validator-specific behavior.
