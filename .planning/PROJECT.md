# jqx

## What This Is

`jqx` is a MoonBit implementation of a `jq`-compatible query engine that now ships as three aligned public surfaces: a native CLI, a JS/TS library surface, and a MoonBit library surface. The project exists to prove that one shared MoonBit implementation can deliver real `jq` compatibility and credible release artifacts across all three surfaces without semantic drift.

## Core Value

A single MoonBit-based core can deliver full `jq` compatibility and publishable CLI, JS/TS, and MoonBit packages without splitting behavior by surface.

## Requirements

### Validated

- [x] Shared-core compatibility against the maintained `jq 1.8.1` corpus, including explicit exception handling, compatibility-lane fidelity, and cross-surface object-order proof. Shipped in `v0.1.0`.
- [x] Canonical MoonBit public APIs over standard `Json`, plus a JSON-text compatibility lane and compiled-filter reuse path that do not expose `@core.Value` as the primary boundary. Shipped in `v0.1.0`.
- [x] Canonical JS/TS runtime and `/bind` surfaces in `@shina1024/jqx`, with working ESM, CJS, and declaration outputs. Shipped in `v0.1.0`.
- [x] jq-compatible CLI stdin, direct-input, and common option workflows implemented through the shared core. Shipped in `v0.1.0`.
- [x] Standalone Zod, Yup, and Valibot adapter packages built on stable runtime contracts rather than internal runtime details. Shipped in `v0.1.0`.
- [x] Auditable npm and CLI release dry-runs, MoonBit package readiness, cross-surface doc alignment, and full Nyquist validation coverage. Shipped in `v0.1.0`.

### Active

- [ ] Turn MoonBit publish to `mooncakes.io` from a readiness proof into a routine release action.
- [ ] Split typed query and query-document helpers into a dedicated `@shina1024/jqx/query` surface without muddying the runtime-first package story.
- [ ] Define the first post-`v0.1.0` milestone from release feedback rather than pre-release cleanup assumptions.

### Out of Scope

- CLI-specific extensions beyond `jq` compatibility.
- Surface-specific semantic shortcuts that diverge from the shared core.
- Hidden compatibility skips or undocumented release exceptions.
- Reopening pre-`0.1.0` API-cleanup churn without a concrete post-release milestone goal.

## Context

Milestone `v0.1.0` is now shipped and archived. The repository has:

- a shared compatibility-tested core with canonical MoonBit, JS/TS, and CLI surfaces
- aligned `0.1.0` manifests across the MoonBit package and npm workspace packages
- archived milestone planning artifacts in `.planning/milestones/`
- a complete milestone audit with no remaining Nyquist validation debt

Known environment caveat: Linux CI remains the authoritative full jq differential proof path because local Windows shell wrappers for `jq_diff` and upstream-ledger verification are still less reliable.

## Current State

`v0.1.0` is the release baseline. The shared semantic core, CLI, JS/TS runtime, standalone adapters, and MoonBit package are all in a release-shaped state, and the milestone archive captures the shipped scope and verification trail.

## Next Milestone Goals

- Decide whether the next milestone is release-operations-focused, query-surface-focused, or post-release hardening.
- Start a fresh `.planning/REQUIREMENTS.md` through `$gsd-new-milestone`.
- Keep post-`0.1.0` changes semver-disciplined instead of relying on pre-release cleanup freedom.

## Constraints

- **Compatibility**: Target `jq 1.8.1` behavior, and make any jq-version-specific exceptions explicit in code, tests, or docs.
- **API Boundary**: MoonBit-facing public APIs use standard `Json`, while public surfaces keep both a value lane and a JSON-text compatibility lane.
- **Shared Model**: Preserve one shared JSON value model across CLI, JS/TS, and MoonBit, including object key input/update order.
- **Packaging**: All three surfaces must be credible public packages; none are optional or merely internal.
- **Release Readiness**: Public releases require auditable dry runs for npm and CLI packaging, plus MoonBit package verification.
- **Validation**: Code changes are gated by `moon info`, `moon fmt`, `moon check`, and `moon test`; public API changes require `.mbti` diff review.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One shared MoonBit core powers CLI, JS/TS, and MoonBit | The project is evaluating MoonBit's real cross-surface practicality, not separate implementations | ✓ Confirmed in `v0.1.0` |
| The CLI remains strictly `jq`-compatible | CLI compatibility is the clearest external contract and should not be diluted by custom surface-specific features | ✓ Confirmed in `v0.1.0` |
| Library surfaces may add practical extensions | Real library utility matters, and adapters such as `zod`, `yup`, and `valibot` support that without changing the CLI contract | ✓ Confirmed in `v0.1.0` |
| The MoonBit public boundary uses standard `Json` plus a JSON-text compatibility lane | This keeps MoonBit APIs idiomatic while still supporting jq-style compatibility workflows | ✓ Confirmed in `v0.1.0` |
| Architecture and API naming may change before versioning if a better design is found | The project was pre-versioning and needed room to remove avoidable API debt | ✓ Applied before `v0.1.0`; future changes must follow semver |
| Current package and directory structure may be reorganized before release | The shared semantic core mattered more than preserving the initial repository layout | ✓ Applied selectively before `v0.1.0` |
| Before `1.0`, breaking changes are acceptable when they reduce long-term API debt | Canonical public names and package boundaries should be cleaned up before release rather than preserved as aliases | ✓ Applied before `v0.1.0`; now closed |

---
*Last updated: 2026-03-21 after v0.1.0 milestone archive*
