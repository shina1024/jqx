# Requirements: jqx

**Defined:** 2026-03-12
**Core Value:** A single MoonBit-based core can deliver full `jq` compatibility and publishable CLI, JS/TS, and MoonBit packages without splitting behavior by surface.

## v1 Requirements

### Compatibility

- [x] **COMP-01**: User can run filters whose results match `jq 1.8.1` for the maintained compatibility corpus.
- [x] **COMP-02**: User can identify every known compatibility exception from docs or tests, and each exception is explicit, narrow, and removable.
- [x] **COMP-03**: User can preserve JSON-text fidelity, including large-number and raw-output-sensitive cases, through compatibility-lane APIs.
- [x] **COMP-04**: User can observe consistent shared JSON semantics, including object key input/update order, across CLI, JS/TS, and MoonBit surfaces.

### Architecture

- [x] **ARCH-01**: Maintainer can evolve the internal architecture to a clearer shared-core design when that improves semantic consistency across surfaces.
- [x] **ARCH-02**: Maintainer can change internal or public API structure before versioning when the result reduces long-term API debt and improves overall usability.
- [x] **ARCH-03**: User can rely on one shared semantic core, with surface-specific layers limited to I/O, packaging, and ergonomic adaptation rather than semantic divergence.
- [x] **ARCH-04**: Maintainer can reorganize package boundaries, module layout, or repository structure before versioning when that better supports the shared core and the three public surfaces.

### CLI

- [x] **CLI-01**: User can execute jq-compatible filters against JSON from stdin or direct input arguments.
- [x] **CLI-02**: User can use the common jq options `-r`, `-R`, `-s`, `-n`, and `-e` with jq-compatible behavior.
- [ ] **CLI-03**: User can install and run published CLI artifacts from project releases.

### MoonBit API

- [x] **MBT-01**: MoonBit user can call a small canonical top-level runtime API from `shina1024/jqx` for parse, validation, compile, and direct execution.
- [x] **MBT-02**: MoonBit user can execute a compiled filter through canonical compiled-filter methods for the value lane.
- [x] **MBT-03**: MoonBit user can execute a compiled filter through canonical compiled-filter methods for the JSON-text compatibility lane.
- [x] **MBT-04**: MoonBit user can consume the public API without depending on `@core.Value`.
- [x] **MBT-05**: Maintainer can rename or restructure MoonBit public APIs before versioning if the result is more idiomatic and clearer for users.
- [ ] **MBT-06**: Maintainer can verify that the MoonBit package is publication-ready for `mooncakes.io`, even if first release defers the actual publish action.

### JS/TS API

- [x] **TS-01**: JS/TS user can call a small canonical runtime API from `@shina1024/jqx` for parse, validation, compile, and direct execution.
- [x] **TS-02**: JS/TS user can execute a compiled filter through canonical compiled-filter methods for structured inputs.
- [x] **TS-03**: JS/TS user can execute a compiled filter through canonical compiled-filter methods for JSON text inputs.
- [x] **TS-04**: JS/TS user can import the documented runtime and binding entry points with working ESM, CJS, and type declaration outputs.
- [x] **TS-05**: Maintainer can rename or restructure JS/TS public or helper APIs before versioning if the result is clearer and reduces long-term surface debt.

### Adapters

- [x] **ADPT-01**: JS/TS user can use the Zod adapter package to validate jqx runtime input and output contracts.
- [x] **ADPT-02**: JS/TS user can use the Yup adapter package to validate jqx runtime input and output contracts.
- [x] **ADPT-03**: JS/TS user can use the Valibot adapter package to validate jqx runtime input and output contracts.

### Release and Docs

- [ ] **REL-01**: Maintainer can dry-run the npm release workflow and inspect the produced package artifacts before first publication.
- [ ] **REL-02**: Maintainer can dry-run the CLI release workflow and inspect the produced native artifacts before first publication.
- [ ] **REL-03**: User can follow consistent documentation and examples for CLI, JS/TS, and MoonBit surfaces using canonical public names.

## v2 Requirements

### Packaging and Ergonomics

- **PKG-01**: Maintainer can publish the MoonBit package to `mooncakes.io` as part of a routine release workflow.
- **PKG-02**: JS/TS user can import query DSL and query document helpers from `@shina1024/jqx/query` instead of the main runtime package.

## Out of Scope

| Feature | Reason |
|---------|--------|
| CLI-only extensions beyond `jq` | The CLI is the strict compatibility surface |
| Surface-specific semantic shortcuts | Shared behavior across CLI, JS/TS, and MoonBit is a core project goal |
| Broad or undocumented compatibility skips | Hidden exceptions would undermine the jq compatibility claim |
| Extra helper layers unrelated to the runtime-first core | Defer until compatibility, package stability, and release discipline are complete |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| COMP-01 | Phase 1 | Complete |
| COMP-02 | Phase 1 | Complete |
| COMP-03 | Phase 1 | Complete |
| COMP-04 | Phase 1 | Complete |
| ARCH-01 | Phase 1 | Complete |
| ARCH-02 | Phase 2 | Complete |
| ARCH-03 | Phase 1 | Complete |
| ARCH-04 | Phase 1 | Complete |
| CLI-01 | Phase 4 | Complete |
| CLI-02 | Phase 4 | Complete |
| CLI-03 | Phase 6 | Pending |
| MBT-01 | Phase 2 | Complete |
| MBT-02 | Phase 2 | Complete |
| MBT-03 | Phase 2 | Complete |
| MBT-04 | Phase 2 | Complete |
| MBT-05 | Phase 2 | Complete |
| MBT-06 | Phase 6 | Pending |
| TS-01 | Phase 3 | Complete |
| TS-02 | Phase 3 | Complete |
| TS-03 | Phase 3 | Complete |
| TS-04 | Phase 3 | Complete |
| TS-05 | Phase 3 | Complete |
| ADPT-01 | Phase 5 | Complete |
| ADPT-02 | Phase 5 | Complete |
| ADPT-03 | Phase 5 | Complete |
| REL-01 | Phase 6 | Pending |
| REL-02 | Phase 6 | Pending |
| REL-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---
*Requirements defined: 2026-03-12*
*Last updated: 2026-03-20 after Phase 05 Plan 01 completion*
