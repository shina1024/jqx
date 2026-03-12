# jqx

## What This Is

`jqx` is a MoonBit implementation of a `jq`-compatible query engine intended to ship as three equal public surfaces: a native CLI, a JS/TS library, and a MoonBit library. The project exists primarily to evaluate MoonBit's practical viability by proving that one shared implementation can deliver real `jq` compatibility and publishable library APIs, rather than only a narrow demo or single-surface tool.

## Core Value

A single MoonBit-based core can deliver full `jq` compatibility and publishable CLI, JS/TS, and MoonBit packages without splitting behavior by surface.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] `jq 1.8.1` compatibility is complete, with any exceptions made explicit and removable.
- [ ] The native CLI is publishable and behaves as a `jq`-compatible surface without CLI-only feature expansion beyond `jq`.
- [ ] The JS/TS package is publishable and provides practical runtime and compiled-filter APIs on top of the shared core.
- [ ] The MoonBit package is publishable and uses standard `Json` as the public boundary while preserving a JSON-text compatibility lane.
- [ ] Shared semantics remain aligned across CLI, JS/TS, and MoonBit, including the JSON value model and object key input/update order.
- [ ] Library surfaces can expose practical integrations, such as schema-validator adapters, without compromising the shared compatibility model.
- [ ] npm and CLI release workflows are dry-run and verified before the first public release.

### Out of Scope

- CLI-specific extensions beyond `jq` compatibility — the CLI is the compatibility surface, not the place for product differentiation.
- Treating any one surface as complete while the others lag materially behind — the project only succeeds when all three surfaces are credible public packages.
- API cleanup that knowingly introduces semantic divergence between CLI, JS/TS, and MoonBit — ergonomics cannot override shared behavior.
- Skipping compatibility or release validation before publication — release readiness is part of the goal, not follow-up work.

## Context

The primary motivation is to evaluate MoonBit's practical usefulness through a real, moderately sized target with both CLI and library value. `jq` was chosen because it is small enough to be tractable while still demanding meaningful compatibility, runtime behavior, and package design across multiple surfaces.

This repository already has meaningful partial functionality. Project initialization here is not starting from zero; it is defining the target quality bar and release expectations for turning the existing work into a complete, publishable system. The current repository structure is a starting point, not a fixed contract.

Library-side practicality matters in addition to strict compatibility. The project already includes integrations with `zod`, `yup`, and `valibot`, and similar extensions are acceptable when they remain outside the CLI compatibility surface and do not fracture the shared runtime semantics.

Architecture and API shape are not locked yet. If a better structure, naming scheme, or usage model is found for either public or internal APIs, it is acceptable to make breaking changes before versioning as long as those changes reduce long-term API debt and improve the consistency of the shared core and package surfaces.

The current package layout direction is:
- `shina1024/jqx` as the primary MoonBit public package
- `shina1024/jqx/core` as the lower-level jq-compatible engine
- `shina1024/jqx/cmd` as the native CLI
- `shina1024/jqx/js` as the MoonBit JS-target-facing package
- `ts/jqx` and `ts/*` as the npm public surface and schema-adapter workspace

This layout may change before release if a different package split, module structure, or boundary arrangement better supports the shared-core design, reduces API debt, or makes the three public surfaces more coherent.

## Constraints

- **Compatibility**: Target `jq 1.8.1` behavior, and make any jq-version-specific exceptions explicit in code, tests, or docs.
- **API Boundary**: MoonBit-facing public APIs use standard `Json`, while public surfaces keep both a value lane and a JSON-text compatibility lane.
- **Shared Model**: Preserve one shared JSON value model across CLI, JS/TS, and MoonBit, including object key input/update order.
- **Packaging**: All three surfaces must be credible public packages; none are optional or merely internal.
- **Release Readiness**: The first public release requires dry runs for npm and CLI release workflows.
- **Validation**: Code changes are gated by `moon info`, `moon fmt`, `moon check`, and `moon test`; public API changes require `.mbti` diff review.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One shared MoonBit core powers CLI, JS/TS, and MoonBit | The project is evaluating MoonBit's real cross-surface practicality, not separate implementations | — Pending |
| The CLI remains strictly `jq`-compatible | CLI compatibility is the clearest external contract and should not be diluted by custom surface-specific features | — Pending |
| Library surfaces may add practical extensions | Real library utility matters, and adapters such as `zod`, `yup`, and `valibot` support that without changing the CLI contract | — Pending |
| The MoonBit public boundary uses standard `Json` plus a JSON-text compatibility lane | This keeps MoonBit APIs idiomatic while still supporting jq-style compatibility workflows | — Pending |
| Architecture and API naming may change before versioning if a better design is found | The project is still pre-versioning, so preserving weak names or structure would only lock in avoidable debt | — Pending |
| Current package and directory structure may be reorganized before release | The existence of one shared semantic core matters more than preserving the present repository layout | — Pending |
| Before `1.0`, breaking changes are acceptable when they reduce long-term API debt | Canonical public names and package boundaries should be cleaned up before release rather than preserved as aliases | — Pending |

---
*Last updated: 2026-03-12 after initialization*
