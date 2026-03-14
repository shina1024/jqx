# Phase 2: MoonBit Public API - Research

**Researched:** 2026-03-14
**Domain:** MoonBit public runtime boundary, compiled-filter ergonomics, and public error contract stabilization
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- The standard MoonBit entrypoint is `run(filter, input : Json)`.
- `compile(filter)` plus `CompiledFilter::run(...)` is the explicit reuse path, not the first example normal users should see.
- The main public value lane uses standard `Json`, while `run_json_text(...)` and `CompiledFilter::run_json_text(...)` remain formal compatibility lanes.
- `@core.Value` is an internal shared-core representation, not the normal MoonBit public boundary.
- Explicit `Json` <-> internal-value conversion helpers may exist only as advanced escape hatches, and docs should point users to the JSON-text lane before those helpers when jq-style fidelity matters.
- `shina1024/jqx` should stay intentionally small, `CompiledFilter` should stay opaque, and normal docs should avoid routing users through `shina1024/jqx/core`.
- Broad `JqxError`-style public catch-all errors should be replaced by narrower entrypoint-specific composite errors while preserving structured leaf error payloads.

### Claude's Discretion
- Exact naming or placement of advanced conversion helpers, as long as they stay clearly secondary.
- Exact doc ordering and example structure needed to make the public package feel small and idiomatic.
- Exact file or module rearrangements needed to keep `CompiledFilter` opaque and remove core-type leakage.
- Exact implementation details for replacing `JqxError` with narrower composite errors while preserving structured payload information.

### Deferred Ideas (OUT OF SCOPE)
- Typed query DSL work should not block this phase and can follow after the canonical string-filter API and compiled-filter boundary are stable.
- Broader MoonBit helper expansion beyond the small canonical runtime surface is deferred unless it clearly reduces long-term API debt.
</user_constraints>

<research_summary>
## Summary

Phase 2 is not a greenfield API design problem. The repository already exposes most of the target MoonBit surface in `jqx.mbt`: `parse_json`, `is_valid_json`, `compile`, `run`, `run_json_text`, and `CompiledFilter` methods over an opaque wrapper. The main work is to harden and simplify that surface so the public contract matches the intended long-term design without leaking `@core.Value`, `@core.Filter`, or broad error unions that include impossible failure modes.

The most important planning implication is that Phase 2 should stay wrapper-focused. Phase 1 already moved shared run-lane orchestration and fidelity-sensitive logic into `core/jqx.mbt`. Reopening core semantics would create unnecessary risk and duplicate the completed compatibility work. This phase should instead focus on:

1. tightening public naming and entrypoint semantics in `jqx.mbt`
2. reshaping public error types in `jqx_public_types.mbt`
3. making the generated `.mbti` surface and docs match the intended canonical boundary
4. proving the boundary with top-level tests rather than only core tests

**Primary recommendation:** Treat `jqx.mbt`, `jqx_public_types.mbt`, `pkg.generated.mbti`, `README.mbt.md`, and `jqx_test.mbt` as the Phase 2 center of gravity, with `core/jqx.mbt` remaining the semantic backend rather than the direct user-facing surface.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries and tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Top-level MoonBit package in `jqx.mbt` | repo current | Primary MoonBit runtime API surface | This is already where the canonical names live, so Phase 2 should harden it rather than create a new surface |
| `jqx_public_types.mbt` | repo current | Public types, errors, and `CompiledFilter` boundary | This is the main place where internal leakage and error-shape debt currently surface |
| `core/jqx.mbt` | repo current | Shared semantic backend and `Json`/text helpers | Phase 1 established this as the semantic center; Phase 2 should delegate into it, not compete with it |
| `pkg.generated.mbti` | generated | Observable MoonBit public contract | Public API changes in this phase must be checked against generated surface diffs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jqx_test.mbt` | repo current | Top-level MoonBit API proof | Use to prove value-lane execution, compiled execution, text-lane fidelity, and public error mapping |
| `README.mbt.md` | repo current | User-facing MoonBit docs and examples | Use to align docs with the canonical value lane, compiled lane, and compatibility lane ordering |
| `moon info`, `moon fmt`, `moon check`, `moon test` | toolchain current | Required quality gate | Use in repo order for every public API change |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hardening the existing top-level surface | Introduce a separate new MoonBit package facade | Adds avoidable churn and another surface to migrate before 1.0 |
| Narrow entrypoint-specific composite errors | Keep one broad `JqxError` | Simpler naming, but it weakens the value of MoonBit's typed error contracts |
| Keeping conversion helpers secondary | Expose `@core.Value`-centric APIs directly | Easier to wire internally, but it violates the desired public boundary and would freeze avoidable API debt |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Thin public wrapper over the shared core
**What:** Public API functions should delegate to `core/jqx.mbt` for parse, compile, execute, and JSON-text fidelity behavior.
**When to use:** For all top-level runtime operations and compiled-filter methods.
**Example:**
```mbt
// Source: jqx.mbt
pub fn run(filter : StringView, input : Json) -> Array[Json] raise JqxError {
  @core.run_json(filter, input) catch {
    err => raise jqx_error_from_core(err)
  }
}
```

### Pattern 2: Dual-lane public API
**What:** Keep one standard-`Json` value lane and one explicit JSON-text compatibility lane.
**When to use:** For direct execution and compiled execution paths.
**Example:**
```mbt
pub fn run(filter : StringView, input : Json) -> Array[Json] raise ...
pub fn run_json_text(filter : StringView, input : StringView) -> Array[String] raise ...
```

### Pattern 3: Opaque compiled-filter abstraction
**What:** `CompiledFilter` is the public reusable execution handle; the underlying `@core.Filter` remains private.
**When to use:** For all compiled execution and any advanced helper design in this phase.
**Example:**
```mbt
pub struct CompiledFilter {
  priv filter : @core.Filter
}
```

### Pattern 4: Public-boundary proof via generated surface and tests
**What:** Validate public API changes through `.mbti` review and top-level tests, not only by checking internals.
**When to use:** After any rename, error-shape change, or helper addition/removal.

## Validation Architecture

Phase 2 validation should emphasize public-boundary correctness rather than jq oracle expansion:

- **Fast loop:** `moon check -d && moon test`
- **Phase gate:** `moon info && moon fmt --check && moon check -d && moon test`
- **Public contract review:** inspect `pkg.generated.mbti` after every public API change
- **Required proof focus:**
  - direct `run(filter, Json)` behavior
  - `CompiledFilter::run(Json)` behavior
  - `run_json_text(...)` and `CompiledFilter::run_json_text(...)` fidelity-sensitive outputs
  - public error mapping and narrowing
  - absence of `@core.Value` / `@core.Filter` leakage from the generated public surface
  - object key order preservation through the `Json` lane

The planner should assume that every plan in this phase needs verification steps that touch both behavior and generated public API shape.
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but already have the right repo-level solution:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Public-value conversion semantics | A new public value model | Standard `Json` at the top-level package plus `core` conversion helpers underneath | The project has already chosen `Json` as the MoonBit boundary and text as the fidelity lane |
| Compiled execution reuse | Public access to `@core.Filter` | The existing `CompiledFilter` abstraction | This keeps the public API small and avoids leaking internals |
| API proof | Ad hoc manual inspection only | `pkg.generated.mbti` review plus `jqx_test.mbt` | Phase 2 is about the observable contract, not just implementation convenience |
| Fidelity-sensitive guidance | Promoting core-value helpers to normal usage | `run_json_text(...)` as the formal compatibility lane | Text is the repo's designated fidelity-preserving lane across surfaces |
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Public errors that describe impossible failures
**What goes wrong:** A function raises a wide union that includes parse or compile failures that cannot occur on that code path.
**Why it happens:** It is easy to keep one reused umbrella type instead of shaping errors per entrypoint.
**How to avoid:** Design composite errors around actual failure modes per API, and preserve leaf errors separately.

### Pitfall 2: Docs that keep `core` as a parallel normal path
**What goes wrong:** The implementation technically hides internals, but examples keep encouraging users to route through `shina1024/jqx/core`.
**Why it happens:** Existing internal knowledge bleeds into docs during refactors.
**How to avoid:** Make `README.mbt.md` and examples consistently start at the top-level package and demote advanced helpers.

### Pitfall 3: Conversion helpers becoming the new primary API
**What goes wrong:** Adding conversion helpers solves an internal need, but they become as prominent as `run(...)` and `compile(...)`.
**Why it happens:** Helper placement and naming make them look like first-class alternatives.
**How to avoid:** Keep them clearly secondary and direct repr-sensitive users to text lanes first.

### Pitfall 4: Treating `.mbti` as a byproduct
**What goes wrong:** The implementation looks clean in source, but the generated public surface still exposes broad errors or core internals.
**Why it happens:** Public contract review is deferred until after coding.
**How to avoid:** Make `.mbti` inspection part of every plan verification step in this phase.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Existing top-level canonical names
```mbt
// Source: jqx.mbt
pub fn parse_json(...)
pub fn compile(...)
pub fn is_valid_json(...)
pub fn run(...)
pub fn run_json_text(...)
```

### Opaque compiled-filter wrapper
```mbt
// Source: jqx_public_types.mbt
pub struct CompiledFilter {
  priv filter : @core.Filter
}
```

### Shared `Json` / text helpers already live in core
```mbt
// Source: core/jqx.mbt
pub fn parse_json(...)
pub fn execute_json(...)
pub fn run_json(...)
pub fn run_json_text(...)
pub fn values_to_json(...)
pub fn values_to_json_text(...)
```
</code_examples>

<open_questions>
## Open Questions

1. **Where should advanced conversion helpers live if exposed at all?**
   - What we know: they must stay secondary to the standard `Json` lane.
   - What is unclear: whether top-level placement is acceptable with light docs, or whether a more explicit advanced namespace is cleaner.
   - Recommendation: planner should choose the smallest option that does not make helpers look like the normal path.

2. **How many composite public error types are the right amount?**
   - What we know: one broad `JqxError` is too loose for the target API.
   - What is unclear: whether entrypoint-specific names for both direct and compiled text execution are the right tradeoff.
   - Recommendation: prefer narrower entrypoint-oriented names as long as the resulting surface still feels small.

3. **How much internal cleanup belongs in this phase versus later phases?**
   - What we know: Phase 2 may break APIs to reduce debt.
   - What is unclear: whether all internal-type leakage can be removed here without destabilizing later JS/TS alignment work.
   - Recommendation: remove any leakage visible from the MoonBit public surface now, and defer purely internal cleanup that does not affect the contract.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `jqx.mbt` - current MoonBit public runtime surface
- `jqx_public_types.mbt` - public errors and opaque `CompiledFilter` boundary
- `jqx_test.mbt` - top-level MoonBit API proof
- `core/jqx.mbt` - shared semantic backend and `Json`/text helpers
- `pkg.generated.mbti` - generated observable public contract
- `README.mbt.md` - advertised MoonBit usage patterns
- `AGENTS.md` - canonical naming, lane split, public boundary, and phase guidance
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/phases/02-moonbit-public-api/02-CONTEXT.md` - project-level goals and locked decisions

### Secondary (MEDIUM confidence)
- `.planning/ROADMAP.md` - roadmap framing for Phase 2 and its three plan slots
</sources>

<metadata>
## Metadata

**Research scope:**
- Public API boundary: top-level MoonBit runtime surface
- Supporting modules: public types, core delegation helpers, docs, and generated `.mbti`
- Validation: MoonBit quality gate and public-surface proof

**Confidence breakdown:**
- Public boundary direction: HIGH
- Validation strategy: HIGH
- Exact helper placement: MEDIUM
- Exact error naming details: MEDIUM

**Research date:** 2026-03-14
**Valid until:** 2026-04-13
</metadata>

---

*Phase: 02-moonbit-public-api*
*Research completed: 2026-03-14*
*Ready for planning: yes*
