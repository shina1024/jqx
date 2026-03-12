# Architecture Research

**Domain:** Shared-core jq-compatible runtime delivered as CLI, JS/TS library, and MoonBit library
**Researched:** 2026-03-12
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    Public Surface Layer                      │
├─────────────────────────────────────────────────────────────┤
│  CLI (`cmd`)   JS runtime (`ts/jqx`)   MoonBit API (`jqx`) │
│  Adapter pkgs (`ts/*`)                                     │
├─────────────────────────────────────────────────────────────┤
│                 Compatibility / API Boundary                │
├─────────────────────────────────────────────────────────────┤
│  JSON text lane   Value lane   Error mapping   Option map   │
├─────────────────────────────────────────────────────────────┤
│                    Shared Semantic Core                     │
├─────────────────────────────────────────────────────────────┤
│  Lexer / Parser -> Compiler / IR -> Evaluator / Builtins   │
│  Shared JSON value model -> Serializer / text preservation │
├─────────────────────────────────────────────────────────────┤
│                Verification and Release Layer               │
│  jq oracle tests   MoonBit tests   TS tests   packaging    │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Parser and compiler | Turn jq source into an executable internal representation | MoonBit modules in the shared core package |
| Runtime and builtins | Evaluate filters over the shared JSON model | MoonBit evaluator plus builtin library owned by the core |
| Compatibility boundary | Preserve JSON-text fidelity, exit semantics, and error classes | Thin wrappers around the core, not separate evaluators |
| Public packages | Present idiomatic surface APIs for CLI, JS/TS, and MoonBit | Small adapters in `cmd`, `jqx`, `js`, and `ts/*` |
| Verification harness | Detect drift against jq and across package surfaces | Oracle tests plus surface-specific smoke and release checks |

## Recommended Project Structure

```text
core/                  # jq-compatible parser, compiler, runtime, builtins
cmd/                   # native CLI entrypoint and jq option surface
js/                    # MoonBit JS-target-facing package
jqx.mbt / helpers      # top-level MoonBit public API
ts/jqx/                # npm runtime package
ts/adapter-core/       # shared TS adapter utilities
ts/*-adapter/          # optional schema adapter packages
.planning/             # project, requirements, roadmap, research
```

### Structure Rationale

- **`core/`:** Owns semantics and must remain the only place where jq behavior is implemented.
- **`cmd/`:** Owns CLI argument parsing and process-level behavior only.
- **Top-level MoonBit package:** Owns the canonical public MoonBit API and standard `Json` boundary.
- **`js/` plus `ts/*`:** Own npm-facing packaging and adapter ergonomics without mutating the semantic core.

## Architectural Patterns

### Pattern 1: Shared semantic core with thin surface adapters

**What:** One evaluator, many entry points.
**When to use:** Always. This is the project's main hypothesis.
**Trade-offs:** Strong consistency, but surface wrappers must resist the urge to patch behavior locally.

### Pattern 2: Dual-lane public API

**What:** Expose both a value lane and a JSON-text compatibility lane.
**When to use:** On all library surfaces where callers need either idiomatic structured values or exact jq-compatible text behavior.
**Trade-offs:** Slightly larger API, but much lower risk of number or serialization drift.

### Pattern 3: Oracle-based compatibility verification

**What:** Compare jqx behavior to jq 1.8.1 for representative filters, errors, and CLI modes.
**When to use:** Continuously, not only before release.
**Trade-offs:** More test harness work up front, but catches semantic drift before it reaches package surfaces.

## Data Flow

### Request Flow

```text
Filter source + input
    -> surface adapter (CLI / JS / MoonBit)
    -> parse input as value lane or JSON-text lane
    -> compiler
    -> runtime evaluator
    -> output serializer / result mapper
    -> surface-specific return value or process exit status
```

### Key Data Flows

1. **CLI flow:** argv/stdin -> CLI option parser -> compatibility lane -> compiler/runtime -> stdout/stderr + exit code
2. **MoonBit value flow:** `Json` input -> public API wrapper -> compiler/runtime -> `Json` outputs
3. **JS/TS text flow:** string input -> runtime wrapper -> compiler/runtime -> string outputs for compatibility-sensitive consumers
4. **Adapter flow:** schema adapter -> runtime wrapper -> validation/inference -> user-facing typed result

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Early compatibility build-out | Keep everything in one semantic core and optimize for test coverage |
| Broad package surface hardening | Add stronger API boundary modules so CLI, JS/TS, and MoonBit cannot drift |
| Large compatibility corpus and release matrix | Separate oracle tests, surface smoke tests, and release rehearsals so failures localize quickly |

### Scaling Priorities

1. **First bottleneck:** Semantic drift across surfaces. Fix with shared adapters and traceable oracle tests.
2. **Second bottleneck:** Release drift across packages. Fix with rehearsed publish flows and artifact-level checks.

## Anti-Patterns

### Anti-Pattern 1: Surface-local behavior patches

**What people do:** Fix a mismatch only in CLI or only in TS wrappers.
**Why it's wrong:** The same filter then behaves differently by surface.
**Do this instead:** Fix semantics in the shared core or make the exception explicit and temporary.

### Anti-Pattern 2: Treating serialization as a wrapper concern

**What people do:** Convert through host-language JSON objects too early.
**Why it's wrong:** Number fidelity and ordering rules drift before tests notice.
**Do this instead:** Preserve JSON-text and shared value semantics as first-class runtime concepts.

### Anti-Pattern 3: Release logic embedded in package-specific scripts only

**What people do:** Let each public surface invent its own release checklist.
**Why it's wrong:** Documentation and artifacts drift even if the runtime is correct.
**Do this instead:** Centralize release rehearsal expectations and keep package outputs traceable to the same semantic core.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| jq 1.8.1 executable | Oracle comparison in compatibility tests | Needed to make "jq-compatible" measurable |
| npm registry | Publish `ts/jqx` and adapter packages from built JS artifacts | Verify ESM, CJS, and `.d.ts` outputs together |
| GitHub Releases | Publish native CLI artifacts | Release workflow should validate platform packaging before launch |
| mooncakes.io | Publish MoonBit package once the release path is confirmed | The repo guidance says this publication decision still needs to be finalized |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `core` <-> `cmd` | Direct API | `cmd` should not reimplement jq semantics |
| `core` <-> top-level MoonBit API | Value and text wrapper methods | Public boundary uses standard `Json` |
| `js` <-> `ts/jqx` | Generated JS-target runtime plus TS packaging | Keep packaging concerns out of the semantic core |
| `ts/jqx` <-> adapter packages | Stable runtime and type contracts | Adapters should depend on runtime contracts, not internal core details |

## Sources

- https://jqlang.org/manual/ - jq behavior model and CLI expectations
- https://docs.moonbitlang.com/en/latest/ - MoonBit project and package structure guidance
- `AGENTS.md` - explicit package boundaries and public API direction
- `README.mbt.md` - current surface layout and exported entry points

---
*Architecture research for: Shared-core jq-compatible runtime delivered as CLI, JS/TS library, and MoonBit library*
*Researched: 2026-03-12*
