# Phase 3: JS/TS Runtime Surface - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the canonical JS/TS runtime and binding surface on top of the shared jq-compatible core. This phase covers the npm-facing direct runtime, compiled-filter surface, binding helpers, package entrypoints, and their cross-surface semantic alignment. It does not add new end-user capabilities beyond stabilizing and packaging the JS/TS runtime surface.

</domain>

<decisions>
## Implementation Decisions

### Call shape
- `@shina1024/jqx` is the synchronous direct-use runtime surface.
- `@shina1024/jqx/bind` is the asynchronous client and backend-binding surface.
- Main-package docs and examples should stay function-centric: `run`, `compile`, `parseJson`, `isValidJson`, `query`, and their JSON-text counterparts are the primary public entrypoints.
- The normal on-ramp is `run(filter, input)`; `compile(...).run(...)` is the explicit reuse path rather than the first thing users should see.
- The value lane is the default story for JS/TS users; `runJsonText(...)`, `queryJsonText(...)`, and compiled `.runJsonText(...)` are the formal compatibility lane when jq-style text fidelity matters.

### Failure contract
- JS/TS should align with MoonBit on failure meaning and lane separation, but not on the exact transport mechanism.
- The canonical JS/TS failure contract is `JqxResult<..., JqxRuntimeError>`, not throw-driven control flow for ordinary runtime failures.
- `run`, `compile`, `parseJson`, and `query` should present one coherent failure story whose categories correspond to the matching MoonBit entrypoints.
- JS boundary failures such as input stringify and output parse remain distinct structured error kinds instead of being collapsed into generic backend failures.

### Query positioning
- `query(...)` and typed query DSL helpers remain part of the main `@shina1024/jqx` package.
- Typed query support is a secondary lane after string-filter runtime usage, not a competing primary story.
- `query(...)` should accept both typed DSL `Query` values and lower-level `QueryAst` values through one public entrypoint.
- `queryJsonText(...)` is the fidelity-sensitive counterpart to `query(...)`, analogous to `runJsonText(...)`.

### Runtime objects and adapter integration
- `runtime` and `queryRuntime` remain exported from the main package, but as secondary adapter and integration helpers rather than the normal first-step API.
- Quick-start docs should not present `runtime.run(...)` or `queryRuntime.query(...)` alongside the first direct-use examples.
- Adapter-oriented docs and packages should use `runtime` and `queryRuntime` as the standard built-in runtime handles.
- `queryRuntime` remains separate from `runtime`; query-aware integrations opt into it explicitly rather than inflating the base runtime object.

### Claude's Discretion
- Exact README ordering, example count, and wording within the chosen call-shape and lane hierarchy.
- Exact helper/type export ordering needed to keep the public API legible without introducing alias debt.
- Exact internal refactors needed to preserve the chosen public story while keeping semantics delegated to the shared MoonBit core.

</decisions>

<specifics>
## Specific Ideas

- Cross-surface consistency should preserve semantics, not force identical host-language ergonomics.
- JS/TS should feel lightweight for ordinary direct use, with async and streaming concerns isolated to `/bind`.
- Typed query support should read as a practical TS convenience lane inside the main package, not as the new primary narrative for jqx.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ts/jqx/src/direct_runtime.ts`: already provides synchronous `run`, `runJsonText`, `compile`, `parseJson`, `query`, `queryJsonText`, and an opaque `CompiledFilter` wrapper over the MoonBit runtime.
- `ts/jqx/src/bind.ts`: already provides the asynchronous binding surface with `bindRuntime`, `bindQueryRuntime`, Promise-returning methods, and streaming fallbacks.
- `ts/jqx/src/index.ts`: already re-exports the direct runtime, query DSL helpers, and runtime objects from one main package entrypoint.
- `ts/jqx/src/moonbit_runtime.ts`: already defines the build seam for bundling the generated MoonBit JS runtime into the npm package.
- `ts/jqx/package.json`: already defines the main `.` and `./bind` entrypoints plus ESM/CJS/types export targets.

### Established Patterns
- The JS/TS direct runtime already wraps the MoonBit compatibility lane and decodes value-lane outputs on the TS side.
- The binding surface already distinguishes direct-use sync APIs from async backend-connected APIs.
- The package currently colocates direct runtime, query DSL helpers, runtime objects, and adapter subpaths under `@shina1024/jqx`.
- Tests already cover direct runtime behavior, binding behavior, and type-level expectations for the current public shape.

### Integration Points
- Public-surface shaping will primarily touch `ts/jqx/src/index.ts`, `ts/jqx/src/direct_runtime.ts`, `ts/jqx/src/bind.ts`, `ts/jqx/package.json`, and `ts/jqx/README.md`.
- JS/TS runtime decisions must stay aligned with `js/jqx_js.mbt` and the generated MoonBit JS runtime bridge rather than re-implement semantics in TypeScript.
- Phase 5 schema adapters will consume the runtime-object decisions made here, especially `runtime` and `queryRuntime`.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-js-ts-runtime-surface*
*Context gathered: 2026-03-14*
