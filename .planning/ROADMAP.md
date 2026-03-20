# Roadmap: jqx

## Overview

This roadmap turns jqx from a partially working prototype into a release-ready shared-core system. The order follows the hard dependencies in the requirements: first make one refactorable semantic core trustworthy against `jq 1.8.1`, then stabilize canonical public APIs, then harden each public surface, and finally dry-run releases and align docs so the project is publishable without semantic drift.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Shared Core and Compatibility** - Make one refactorable semantic core match `jq 1.8.1` with explicit exceptions only.
- [x] **Phase 2: MoonBit Public API** - Turn the MoonBit surface into a small canonical runtime API over the shared core.
- [x] **Phase 3: JS/TS Runtime Surface** - Ship the canonical npm runtime and binding surface on top of the same semantics.
- [x] **Phase 4: CLI Workflow Parity** - Finish end-to-end jq-compatible CLI workflows without turning CLI into an extension surface.
- [x] **Phase 5: Schema Adapter Packages** - Make Zod, Yup, and Valibot integrations work on the stable JS/TS runtime.
- [x] **Phase 6: Release Readiness and Docs** - Validate publishable artifacts, MoonBit package readiness, and surface-consistent docs.
- [ ] **Phase 7: Nyquist Validation Completion** - Close remaining validation-process debt and bring partial phase validations to compliant status.

## Phase Details

### Phase 1: Shared Core and Compatibility
**Goal**: Users can rely on one shared semantic core that matches `jq 1.8.1` and can be reorganized without creating surface-specific behavior.
**Depends on**: Nothing (first phase)
**Requirements**: COMP-01, COMP-02, COMP-03, COMP-04, ARCH-01, ARCH-03, ARCH-04
**Success Criteria** (what must be TRUE):
  1. User can run the maintained jq compatibility corpus and get `jq 1.8.1`-matching results from the shared core, except for explicitly documented temporary exceptions.
  2. User can observe preserved JSON-text fidelity for large-number and raw-output-sensitive cases through compatibility-sensitive paths.
  3. User can observe consistent object key order and shared JSON semantics across surfaces exercising the same core behavior.
  4. Maintainer can reorganize internal modules or package boundaries while keeping semantics owned by one shared core.
**Plans**: 3 plans

Plans:
- [x] 01-01: Tighten compatibility corpus coverage and exception tracking against `jq 1.8.1`
- [x] 01-02: Refactor runtime boundaries around one shared semantic core
- [x] 01-03: Add cross-surface fidelity and ordering checks

### Phase 2: MoonBit Public API
**Goal**: MoonBit users get a small, idiomatic, canonical API for both value-lane and JSON-text execution without leaking internal types.
**Depends on**: Phase 1
**Requirements**: ARCH-02, MBT-01, MBT-02, MBT-03, MBT-04, MBT-05
**Success Criteria** (what must be TRUE):
  1. MoonBit user can parse, validate, compile, and run filters from a small canonical top-level runtime API.
  2. MoonBit user can reuse compiled filters through clear value-lane and JSON-text methods.
  3. MoonBit user does not need `@core.Value` to consume the public package.
  4. Maintainer can rename or reorganize the MoonBit public surface before versioning without weakening the shared-core contract.
**Plans**: 3 plans

Plans:
- [x] 02-01: Canonicalize MoonBit runtime entry points and naming
- [x] 02-02: Harden compiled-filter methods and lane separation
- [x] 02-03: Remove or isolate internal-type leakage from the public boundary

### Phase 3: JS/TS Runtime Surface
**Goal**: JS/TS users can use a canonical runtime and binding package that stays aligned with the MoonBit and CLI semantics.
**Depends on**: Phase 2
**Requirements**: TS-01, TS-02, TS-03, TS-04, TS-05
**Success Criteria** (what must be TRUE):
  1. JS/TS user can parse, validate, compile, and run filters from a small canonical runtime API.
  2. JS/TS user can execute compiled filters through separate structured-input and JSON-text methods.
  3. JS/TS user can import runtime and binding entry points with working ESM, CJS, and type declaration outputs.
  4. Maintainer can rename or reorganize JS/TS public and helper APIs before versioning without drifting from shared semantics.
**Plans**: 3 plans

Plans:
- [x] 03-01: Canonicalize JS/TS runtime exports and direct-use API
- [x] 03-02: Align compiled-filter and binding helper surfaces
- [x] 03-03: Verify package output formats and type declarations

### Phase 4: CLI Workflow Parity
**Goal**: CLI users can complete the common jq workflows against the same shared core used by the library surfaces.
**Depends on**: Phase 1
**Requirements**: CLI-01, CLI-02
**Success Criteria** (what must be TRUE):
  1. User can execute jq-compatible filters against JSON from stdin and direct input arguments through the CLI.
  2. User can use `-r`, `-R`, `-s`, `-n`, and `-e` with jq-compatible behavior.
  3. CLI behavior comes from the shared semantic core rather than surface-local semantic patches.
**Plans**: 2 plans

Plans:
- [x] 04-01: Normalize CLI input and output behavior around the shared core
- [x] 04-02: Finish common jq option parity and error-path behavior

### Phase 5: Schema Adapter Packages
**Goal**: JS/TS users can apply schema adapters on top of the stable runtime surface without coupling adapters to internal runtime details.
**Depends on**: Phase 3
**Requirements**: ADPT-01, ADPT-02, ADPT-03
**Success Criteria** (what must be TRUE):
  1. JS/TS user can use the Zod adapter package to validate jqx runtime inputs and outputs.
  2. JS/TS user can use the Yup adapter package to validate jqx runtime inputs and outputs.
  3. JS/TS user can use the Valibot adapter package to validate jqx runtime inputs and outputs.
  4. Adapter packages rely on stable runtime contracts instead of internal core details.
**Plans**: 2 plans

Plans:
- [x] 05-01: Stabilize adapter-core contracts and package boundaries
- [x] 05-02: Harden and document Zod, Yup, and Valibot adapters

### Phase 6: Release Readiness and Docs
**Goal**: Users and maintainers can trust release artifacts and canonical docs across CLI, JS/TS, and MoonBit surfaces.
**Depends on**: Phases 2, 3, 4, and 5
**Requirements**: CLI-03, MBT-06, REL-01, REL-02, REL-03
**Success Criteria** (what must be TRUE):
  1. User can install and run CLI artifacts from project releases.
  2. Maintainer can dry-run npm and CLI release workflows and inspect the produced artifacts before first publication.
  3. Maintainer can verify that the MoonBit package is publication-ready for `mooncakes.io`, even if actual first-release publish is deferred.
  4. User can follow consistent CLI, JS/TS, and MoonBit docs and examples that use canonical names.
**Plans**: 3 plans

Plans:
- [x] 06-01: Dry-run npm and CLI release workflows and audit artifacts
- [x] 06-02: Finalize MoonBit package readiness and publication metadata
- [x] 06-03: Align docs and examples across all public surfaces

### Phase 7: Nyquist Validation Completion
**Goal**: Bring the remaining partial VALIDATION artifacts to Nyquist-compliant status so milestone v1.0 can close without validation-process debt.
**Depends on**: Phase 6
**Requirements**: None (validation debt closure)
**Gap Closure**: Closes the `tech_debt` items from `.planning/v1.0-MILESTONE-AUDIT.md` for phases 03, 04, 05, and 06.
**Plans**: 0 plans

Plans:
- [ ] TBD (run `$gsd-plan-phase 7` to break down the Nyquist validation closure work)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Shared Core and Compatibility | 3/3 | Complete | 2026-03-13 |
| 2. MoonBit Public API | 3/3 | Complete | 2026-03-14 |
| 3. JS/TS Runtime Surface | 3/3 | Complete | 2026-03-14 |
| 4. CLI Workflow Parity | 2/2 | Complete | 2026-03-20 |
| 5. Schema Adapter Packages | 2/2 | Complete | 2026-03-20 |
| 6. Release Readiness and Docs | 3/3 | Complete | 2026-03-20 |
| 7. Nyquist Validation Completion | 0/0 | Not started | - |
