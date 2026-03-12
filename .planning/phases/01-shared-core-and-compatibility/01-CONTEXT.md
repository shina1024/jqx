# Phase 1: Shared Core and Compatibility - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Make one refactorable shared semantic core match `jq 1.8.1` with explicit temporary exceptions only, while preserving JSON-text fidelity and cross-surface semantic consistency. This phase is about proving and tightening the compatibility core, not adding new user-facing capabilities.

</domain>

<decisions>
## Implementation Decisions

### Compatibility exceptions
- Temporary compatibility exceptions are acceptable during Phase 1, including during breaking refactors.
- Every temporary exception must be visible from both tests and user-facing documentation.
- Each exception must record not only the reason it exists, but also the condition that would allow it to be removed.
- Temporary CI failures caused by breaking changes are acceptable during the phase, but Phase 1 must end with CI passing again.

### Proof and CI
- Phase 1 completion requires both green CI and explainable jq-difference results.
- The compatibility oracle should use both the maintained repository cases and upstream jq-derived cases.
- Pushes are allowed and expected at meaningful milestones so CI can be checked during the phase.
- The current CI shape is not fixed. If a workflow is excessive it may be removed or reduced; if verification is missing it should be added.

### Reorganization policy
- Large architectural or package/module reorganization is allowed in Phase 1 if it improves the shared-core design.
- Package names, module names, and public/private placement may change when needed to clarify the shared semantic core.
- During the migration, temporary surface-side adjustments are acceptable for practicality.
- The end state must still converge back to one shared semantic core, with surface-specific layers limited to I/O, packaging, and ergonomic adaptation rather than semantic divergence.

### Claude's Discretion
- Exact CI changes to remove over-checking or add missing verification.
- Exact sequencing of compatibility fixes versus structural refactors.
- Exact package, module, and file moves needed to clarify the shared core.
- Exact format and placement of compatibility ledgers, exception docs, and supporting test metadata.

</decisions>

<specifics>
## Specific Ideas

- Phase 1 may temporarily break CI during breaking cleanup, but should restore CI before the phase closes.
- Compatibility exceptions should not be hidden in ad hoc notes; they should be traceable from both automated checks and human-readable documentation.
- CI is allowed to evolve during the phase rather than being treated as a fixed contract.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `core/jqx.mbt`: shared JSON value model, parser, numeric representation preservation, and object-key ordering logic that already act like the semantic center.
- `jqx.mbt`: current MoonBit public wrapper exposing value-lane and JSON-text execution paths.
- `scripts/jq_diff.sh` and `scripts/jq_diff_native.sh`: jq oracle comparison scripts that can remain the backbone of compatibility proof.
- `scripts/jq_compat_cases.json`, `scripts/jq_compat_cases.upstream.json`, `third_party/jq-tests/`: maintained and imported compatibility corpora already present in the repo.

### Established Patterns
- Shared semantics already mostly live under `core/`, with CLI, JS/TS, and MoonBit wrappers layered around it.
- The project already distinguishes a value lane and a JSON-text compatibility lane.
- Compatibility verification is already script-driven and jq-oracle-based rather than snapshot-only.

### Integration Points
- Shared-core refactors will affect `core/`, then flow into `jqx.mbt`, `cmd/main.mbt`, and `ts/jqx/src/direct_runtime.ts`.
- CI and local proof paths currently route through GitHub Actions workflows and the `scripts/jq_diff*` harness.
- Any Phase 1 compatibility ledger or documentation should connect to existing case files and differential scripts rather than starting a separate tracking system.

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-shared-core-and-compatibility*
*Context gathered: 2026-03-12*
