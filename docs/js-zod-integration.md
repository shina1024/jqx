# JS/TS Schema Integration (Zod/Yup/Valibot)

Updated: 2026-02-10

## Goal

Provide practical, type-safe integration paths between `jqx` and popular JS/TS validators.

The architecture keeps MoonBit `core/` pure and places validator coupling in TS adapter layers.

## Current Status

Implemented adapters:

1. `ts/zod-adapter`
   - API: `createAdapter(runtime)` with `.filter(...)`, `.query(...)`, `.inferred(...)`
2. `ts/yup-adapter`
   - API: `createAdapter(runtime)` with `.filter(...)`, `.query(...)`, `.inferred(...)`
3. `ts/valibot-adapter`
   - API: `createAdapter(runtime)` with `.filter(...)`, `.query(...)`, `.inferred(...)`

Each adapter includes runtime tests, `pnpm typecheck`, `expectTypeOf`-based compile-time assertions, and Linux CI coverage.
Each adapter also provides jq-string partial inference via:
- `InferJqOutput<Input, Filter, Mode>`
- `createAdapter(runtime).inferred({ filter, input, fallback? })`

Still pending:

1. Final npm runtime binding and import design (`import { ... } from "jqx"`).
2. Keep expanding end-to-end usage examples for app integration patterns.

## Design Principles

1. Keep MoonBit runtime independent from JS validation libraries.
2. Validate unknown input at the TS boundary using a chosen validator.
3. Prefer safe/result APIs over exception-first flows.
4. Use `unknown`/`Json` fallback where static inference is unsound.

## Runtime Shape

All adapters use runtime injection and async-safe APIs:

```ts
export type JqxResult<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

interface JqxDynamicRuntime {
  run(filter: string, input: string): JqxResult<string[]> | Promise<JqxResult<string[]>>;
}

interface JqxTypedRuntime<Q = unknown> {
  runQuery(query: Q, input: string): JqxResult<string[]> | Promise<JqxResult<string[]>>;
}
```

## Error Model

Adapter errors are normalized into a discriminated union:

1. `input_validation`
2. `runtime`
3. `output_parse`
4. `output_validation`

This keeps call sites explicit and stable for app-level error handling.

## Unknown JSON Strategy

When input shape is unknown, jq/filter text alone cannot provide strong static types.

1. Dynamic lane:
   - run with `adapter.filter(...)`
   - treat values as `unknown`/`Json`
2. Typed lane:
   - validate input with schema
   - run `adapter.query(...)`
   - validate outputs with schema

## jq String Partial Inference Rules

The inference layer is intentionally conservative. It infers only a safe subset
of jq filter strings and falls back for the rest.

Inferable subset:

1. `.`
2. `.foo`
3. `.foo.bar`
4. `.[n]` (`n` is an integer literal)
5. `.[]`
6. simple combinations of the above (for example `.items[].name`)

Fallback behavior:

1. Default fallback is `unknown` for non-inferable syntax.
2. `fallback: "json"` switches non-inferable outputs to `Json`.
3. Non-inferable examples include operators/pipes/functions/conditionals and
   other complex jq forms such as:
   `.a | .b`, `.a + 1`, `map(.)`, `if ... then ... else ... end`, `.foo?`.

Type-level examples:

```ts
type A = InferJqOutput<{ user: { name: string } }, ".user.name">; // string
type B = InferJqOutput<{ user: { name: string } }, ".user | .name">; // unknown
type C = InferJqOutput<{ user: { name: string } }, ".user | .name", "json">; // Json
```

## End-to-End Usage Examples

Practical E2E examples (schema input validation + jq string execution + output
schema validation) are documented in:

- `docs/js-schema-e2e.md`

## Next Steps

1. Expand compile-time assertions from adapter surfaces to richer typed-query composition scenarios.
2. Finalize npm package layout and runtime binding so users can import from the stable public entrypoint.
3. Add docs/examples showing end-to-end runtime wiring for each validator.
