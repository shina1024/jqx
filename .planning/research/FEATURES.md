# Feature Research

**Domain:** jq-compatible runtime with CLI, JS/TS, and MoonBit public surfaces
**Researched:** 2026-03-12
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| jq-compatible filter semantics | A jq-compatible project is only credible if filters behave like jq, not approximately like jq | HIGH | This includes parser, compiler, evaluator, builtin behavior, and error cases against jq 1.8.1 |
| CLI parity for common jq workflows | CLI users expect stdin, arg input, raw mode, slurp, null input, and jq-style exit behavior | HIGH | The README already documents these as expected surface behavior |
| Value lane APIs for JS/TS and MoonBit | Library users expect direct object or `Json` inputs, not forced shell-style text plumbing | MEDIUM | Must still share the same compiled core as the CLI |
| JSON-text compatibility lane | jq compatibility breaks if large numbers, formatting-sensitive outputs, or raw text are normalized too early | HIGH | Keep text-preserving APIs first-class on every library surface |
| Compiled filter reuse | Library users expect to compile once and run many times | MEDIUM | Needed for both performance and API credibility |
| Cross-surface error reporting and testable contracts | Public packages need predictable result/error forms and docs | MEDIUM | Surface wrappers may differ in shape, but semantics and failure classes must match |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Schema-validator adapters (`zod`, `yup`, `valibot`) | Makes the library surfaces practical in real JS/TS apps instead of being only a jq port | MEDIUM | Keep adapters optional and outside the CLI contract |
| Runtime binding helpers | Lets consumers plug jqx semantics into custom backends or runtimes | MEDIUM | Already aligned with the repo's `bindRuntime` and `bindQueryRuntime` direction |
| Separate query DSL/document package | Keeps the main package runtime-first while allowing richer authoring tools elsewhere | MEDIUM | This is already a near-term priority in repo guidance |
| Consistent docs and examples across all three surfaces | Shows that MoonBit can support a coherent multi-surface product, not only a working core | LOW | Important for release readiness and adoption |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| CLI-only jqx extensions | Feels like a quick way to add differentiation | Weakens the jq contract and makes compatibility status ambiguous | Keep extensions in library-only packages or clearly separated packages |
| Surface-specific semantics | Tempting when one surface makes a shortcut easy | Users lose trust once the same filter behaves differently by entry point | Keep one semantic core and adapt only I/O boundaries |
| Early expansion into unrelated query languages | Looks like leverage after building a parser/runtime | Dilutes the MoonBit-via-jq evaluation and delays complete compatibility | Finish jq compatibility and package release discipline first |

## Feature Dependencies

```text
jq 1.8.1 oracle compatibility
    -> parser / compiler / runtime correctness
        -> CLI parity
        -> JS/TS value lane
        -> MoonBit value lane
        -> JSON-text compatibility lane
            -> schema adapters and binding helpers

release packaging
    -> stable public APIs
    -> docs and examples
```

### Dependency Notes

- **CLI parity requires runtime correctness:** CLI behavior cannot be verified independently from evaluator and builtin semantics.
- **Value lane depends on JSON-text lane discipline:** If text fidelity is lost in the core boundary, large-number and raw-output behavior will drift.
- **Adapters enhance public APIs, but depend on stable runtime APIs:** They should not shape the compatibility core.
- **Release packaging depends on canonical names:** Public API alias churn blocks credible documentation and publish steps.

## MVP Definition

### Launch With (v1)

- [ ] Full jq 1.8.1 compatibility target, with explicit and removable exceptions only
- [ ] Publishable native CLI with jq-compatible behavior
- [ ] Publishable MoonBit package with canonical runtime APIs and compiled-filter methods
- [ ] Publishable npm package with `run`, `runJsonText`, `compile`, and compiled-filter methods
- [ ] Cross-surface documentation and verification proving the shared core story

### Add After Validation (v1.x)

- [ ] Stabilize and document schema adapter packages after the main runtime package is clearly publishable
- [ ] Split query DSL and query document helpers into a dedicated package when the main runtime surface is stable

### Future Consideration (v2+)

- [ ] Non-essential helper layers beyond the runtime-first core
- [ ] Additional integrations that add maintenance burden without helping jq compatibility or package adoption

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| jq compatibility core | HIGH | HIGH | P1 |
| CLI parity and packaging | HIGH | HIGH | P1 |
| MoonBit public API hardening | HIGH | MEDIUM | P1 |
| JS/TS package hardening | HIGH | MEDIUM | P1 |
| Release workflow dry runs | HIGH | MEDIUM | P1 |
| Schema adapter polish | MEDIUM | MEDIUM | P2 |
| Query DSL package split | MEDIUM | MEDIUM | P2 |
| Extra convenience helpers | LOW | LOW | P3 |

## Sources

- https://jqlang.org/manual/ - baseline jq feature expectations
- https://github.com/jqlang/jq/releases/tag/jq-1.8.1 - fixed compatibility target
- `README.mbt.md` - currently exposed CLI and library feature expectations
- `AGENTS.md` - explicit public API direction, package boundaries, and near-term priorities

---
*Feature research for: jq-compatible runtime with CLI, JS/TS, and MoonBit public surfaces*
*Researched: 2026-03-12*
