# Phase 2: MoonBit Public API - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn `shina1024/jqx` into the primary MoonBit public package for parse, validation, compile, and execution. This phase stabilizes the MoonBit-facing API boundary over the shared core, including standard-`Json` value-lane execution, compiled-filter reuse, the JSON-text compatibility lane, and public error shaping. It does not add typed query DSL scope or other new user-facing capabilities.

</domain>

<decisions>
## Implementation Decisions

### Primary usage model
- The standard MoonBit entrypoint is `run(filter, input : Json)`.
- `compile(filter)` followed by `CompiledFilter::run(...)` is the explicit next step for filter reuse or precompiled execution, not the first thing normal users should see.
- Public docs and examples should present the value lane first, then compiled execution, then the JSON-text compatibility lane.
- `parse_json` and `is_valid_json` remain in the public package, but as supporting boundary helpers rather than the primary happy path.

### Value lane and compatibility lane
- The main public value lane uses MoonBit's standard `Json` type from `moonbitlang/core/json`.
- The public package must still support a first-class JSON-text compatibility lane via `run_json_text(...)` and `CompiledFilter::run_json_text(...)`.
- When jq-style numeric or output fidelity matters, docs should direct users to the JSON-text lane before suggesting any internal-value escape hatch.
- Typed query DSL work must not block this phase and stays outside the required MoonBit public API surface.

### Conversion boundary
- `@core.Value` is an internal shared-core representation, not the normal MoonBit public boundary.
- Explicit `Json` <-> internal-value conversion helpers may exist as advanced escape hatches, but they are not part of the main user journey.
- Advanced conversion helpers can live on the top-level package if necessary, but should be documented quietly and kept out of normal quick-start flows.
- Normal MoonBit usage should stay within `Json`, `run`, `compile`, and the JSON-text lane.

### Public surface size and opacity
- `shina1024/jqx` should stay intentionally small: canonical parse/validate/compile/run operations plus the `CompiledFilter` abstraction.
- `CompiledFilter` should remain fully opaque; MoonBit users should not need access to `@core.Filter`.
- Normal docs and examples should use `shina1024/jqx` only and avoid routing users through `shina1024/jqx/core`.
- Breaking changes are acceptable in Phase 2 if they remove API debt, aliases, or internal-type leakage from the public boundary.

### Error contract
- Keep the leaf public error types `JsonParseError`, `CompileError`, and `RuntimeError`, with structured payloads such as positions, diagnostics arrays, and `Thrown(Json)`.
- Remove the broad `JqxError`-style catch-all contract in favor of narrower entrypoint-specific composite errors that reflect only failures that can actually happen.
- Preferred public naming is entrypoint-oriented:
  `RunError` for `run(filter, input : Json)` with compile/runtime failures.
  `JsonTextRunError` for `run_json_text(...)` with parse/compile/runtime failures.
  `CompiledJsonTextRunError` for `CompiledFilter::run_json_text(...)` with parse/runtime failures.
- User guidance should be: branch on typed errors in program logic, and use string rendering for human-facing output.

### Claude's Discretion
- Exact naming or placement of advanced conversion helpers, as long as they stay clearly secondary to the `Json` lane and text lane.
- Exact doc ordering, example count, and helper wording needed to make the public package feel small and idiomatic.
- Exact file or module rearrangements needed to keep `CompiledFilter` opaque and stop public leakage of core-only types.
- Exact implementation details for replacing `JqxError` with narrower composite errors while preserving structured payload information.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `jqx.mbt`: already exposes the canonical top-level names `parse_json`, `is_valid_json`, `compile`, `run`, and `run_json_text`, plus `CompiledFilter` methods, so Phase 2 can refine this surface instead of inventing a new one.
- `jqx_public_types.mbt`: already defines the public error structs/suberrors and the opaque `CompiledFilter` wrapper over `@core.Filter`; this is the starting point for narrowing error contracts and removing catch-all API debt.
- `core/jqx.mbt`: already contains shared helpers for `parse_json`, `execute_json`, `run_json`, `run_json_text`, `Value::from_json`, `Value::to_json`, `values_to_json`, and `values_to_json_text`, so the public package can stay thin and delegate semantics inward.
- `jqx_test.mbt`: already proves public-surface `Json` execution, compiled execution, JSON-text fidelity, and object-order behavior; these tests can anchor contract changes.

### Established Patterns
- The top-level MoonBit package already delegates into `core` rather than re-implementing jq semantics.
- The repo already distinguishes a value lane and a JSON-text compatibility lane on both MoonBit and JS/TS surfaces.
- Current public names are already close to the desired canonical naming, so Phase 2 is mainly about tightening the boundary, docs, and error contracts.

### Integration Points
- Public API work will primarily touch `jqx.mbt`, `jqx_public_types.mbt`, `jqx_test.mbt`, `README.mbt.md`, and the generated `.mbti` surface.
- Boundary decisions must stay consistent with `core/jqx.mbt` delegation and avoid moving semantics back out into wrappers.
- Phase 3 JS/TS surface work will inherit the MoonBit naming and lane decisions from this phase, so docs and method naming here set the downstream pattern.

</code_context>

<specifics>
## Specific Ideas

- The first example MoonBit users see should be `run(filter, Json)` rather than compiled execution.
- `run_json_text(...)` is a formal compatibility lane, not an implementation detail or deprecated escape hatch.
- The public package should feel like one obvious API, not a menu of equal-weight wrappers and internal helpers.
- Advanced helpers may remain on the same top-level package surface if necessary, but they should read as secondary rather than alternative main flows.

</specifics>

<deferred>
## Deferred Ideas

- Typed query DSL work should not block Phase 2 and can follow after the canonical string-filter API and compiled-filter boundary are stable.
- Any broader MoonBit-facing helper expansion beyond the small canonical runtime surface is deferred unless it clearly reduces long-term API debt.

</deferred>

---

*Phase: 02-moonbit-public-api*
*Context gathered: 2026-03-14*
