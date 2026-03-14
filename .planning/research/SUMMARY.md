# Project Research Summary

**Project:** jqx
**Domain:** MoonBit-based jq-compatible runtime and multi-surface packaging
**Researched:** 2026-03-12
**Confidence:** MEDIUM

## Executive Summary

This project is best treated as one shared semantic runtime with three thin public surfaces: a native jq-compatible CLI, a MoonBit library, and an npm package. The research strongly supports keeping jq 1.8.1 as a fixed oracle while using MoonBit as the implementation language across native and JS targets, because the project's real question is whether MoonBit can carry a credible multi-surface product rather than only a demo.

The strongest recommendation is to front-load compatibility discipline and public API stabilization before release work. If semantic drift, JSON fidelity drift, or alias-heavy APIs are left until the end, packaging success on npm or mooncakes will not matter because users will not trust the behavior.

## Key Findings

### Recommended Stack

The stack should stay close to what the repo is already converging toward: MoonBit as the shared core, jq 1.8.1 as the compatibility oracle, Node 24 LTS for npm verification and release automation, and the current `@typescript/native-preview` plus `esbuild`/`tsgo` TS workspace toolchain for package development and typings. Keep optional schema integrations in separate TS packages so the runtime package remains runtime-first.

**Core technologies:**
- MoonBit: shared parser, compiler, runtime, native CLI, and JS-target build
- jq 1.8.1: compatibility oracle for semantics and CLI behavior
- Node 24 LTS: npm packaging, tests, and release verification
- `@typescript/native-preview` + `tsgo`: current type surface and declaration-emission path for npm packages and adapters

### Expected Features

The must-have feature set is narrower than it first appears. Users need jq-compatible semantics, CLI parity for the common option set, value-lane and JSON-text-lane APIs, compiled-filter reuse, and consistent error behavior across surfaces. Practical extensions such as schema adapters matter, but they should not be allowed to reshape the compatibility core or the CLI contract.

**Must have (table stakes):**
- Full jq-compatible filter semantics against jq 1.8.1
- Publishable native CLI with common jq workflows
- Publishable MoonBit and JS/TS runtime APIs with value and text lanes
- Compiled filters and cross-surface error/result contracts

**Should have (competitive):**
- Schema adapter packages
- Runtime binding helpers
- Clear, aligned examples across all three public surfaces

**Defer (v2+):**
- Additional helper layers unrelated to the runtime-first core

### Architecture Approach

The architecture should remain layered: public surfaces at the top, a compatibility/API boundary in the middle, one semantic core underneath, and a dedicated verification/release layer around all of it. The most important architectural rule is that wrappers adapt I/O and naming only; they do not own jq semantics.

**Major components:**
1. Parser/compiler core - turns jq source into executable internal form
2. Runtime/builtin core - evaluates filters over the shared JSON model
3. Compatibility boundary - preserves JSON-text fidelity, option behavior, and error classes
4. Public surface wrappers - expose CLI, MoonBit, JS/TS, and adapter APIs
5. Verification/release harness - compares against jq and validates package artifacts

### Critical Pitfalls

1. **Surface semantic drift** - fix semantics in core, not in wrappers
2. **JSON fidelity loss** - keep a first-class JSON-text lane and test it directly
3. **Hidden compatibility exceptions** - document every skip and keep jq 1.8.1 as the fixed oracle
4. **Public API debt** - settle canonical names before release
5. **Release packaging drift** - dry-run npm and CLI releases before calling the project publishable

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Semantic Core and Compatibility Harness
**Rationale:** Everything else depends on trustworthy jq semantics.
**Delivers:** Core compatibility fixes, oracle tests, and explicit exception handling.
**Addresses:** jq parity, JSON-text fidelity, and the largest drift risks.
**Avoids:** Surface semantic drift and hidden compatibility exceptions.

### Phase 2: Public API Stabilization
**Rationale:** Package release work is wasted until the public boundaries are stable.
**Delivers:** Canonical MoonBit and JS/TS runtime APIs, compiled-filter surface cleanup, and `.mbti` review discipline.
**Uses:** The already-correct semantic core.
**Implements:** The dual-lane public API boundary.

### Phase 3: Surface Packaging Completion
**Rationale:** Once semantics and APIs are stable, package outputs can be hardened with less churn.
**Delivers:** Native CLI packaging, npm package outputs, adapter packaging, and documentation alignment.
**Uses:** Node 24 LTS, `@typescript/native-preview`, `esbuild`, `tsgo`, and existing package boundaries.

### Phase 4: Release Rehearsal and Publication Prep
**Rationale:** Publishable means artifact-level confidence, not only passing local tests.
**Delivers:** Dry-run npm and CLI releases, mooncakes publication decision, and final release documentation.

### Phase Ordering Rationale

- Compatibility comes before ergonomics because every public surface depends on it.
- Public API cleanup comes before package hardening so declaration files, docs, and examples do not churn twice.
- Release rehearsal is last because it depends on stable semantics and stable package boundaries.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3:** npm packaging and adapter release details may need package-by-package verification
- **Phase 4:** mooncakes publication readiness still has an open decision in repo guidance

Phases with standard patterns:
- **Phase 1:** jq oracle testing and semantic-core hardening are straightforward, even if large
- **Phase 2:** API stabilization follows clear repo guidance on canonical names and `Json` boundaries

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Strong official sources for jq, Node, TS, and MoonBit docs, but MoonBit remains pre-1.0 |
| Features | HIGH | The repo and jq contract make table stakes very clear |
| Architecture | HIGH | The package boundaries and shared-core rule are already explicit |
| Pitfalls | HIGH | The main failure modes are already visible in repo guidance and compatibility constraints |

**Overall confidence:** MEDIUM

### Gaps to Address

- Mooncakes publication should be either fully prepared or explicitly removed from user-facing "planned" language.
- Release artifact checks should be made concrete per surface during roadmap planning, not left as a generic final step.

## Sources

### Primary (HIGH confidence)
- https://docs.moonbitlang.com/en/latest/ - current MoonBit docs and package guidance
- https://docs.moonbitlang.com/en/latest/package/package-manager.html - `moon publish` and package workflow
- https://nodejs.org/en/about/previous-releases - Node LTS status
- `ts/jqx/package.json`, `ts/adapter-core/package.json`, `ts/yup-adapter/package.json`, `ts/zod-adapter/package.json`, `ts/valibot-adapter/package.json` - current TS workspace toolchain pins and scripts
- https://jqlang.org/manual/ - jq behavior model
- https://github.com/jqlang/jq/releases/tag/jq-1.8.1 - jq 1.8.1 release target

### Primary (repo context)
- `AGENTS.md` - compatibility rules, API direction, package boundaries, and release priorities
- `README.mbt.md` - advertised surfaces and example APIs
- `ts/jqx/package.json` - current npm packaging structure and tool versions

---
*Research completed: 2026-03-12*
*Ready for roadmap: yes*
