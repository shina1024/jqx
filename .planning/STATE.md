---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: planning
stopped_at: Phase 5 context gathered
last_updated: "2026-03-20T06:44:51.738Z"
last_activity: 2026-03-20 - Completed Phase 4 CLI Workflow Parity
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 11
  completed_plans: 11
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-20)

**Core value:** A single MoonBit-based core can deliver full `jq` compatibility and publishable CLI, JS/TS, and MoonBit packages without splitting behavior by surface.
**Current focus:** Phase 5 - Schema Adapter Packages

## Current Position

Phase: 5 of 6 (Schema Adapter Packages)
Plan: 0 of 2 in current phase
Status: Ready to plan
Last activity: 2026-03-20 - Completed Phase 4 CLI Workflow Parity

Progress: [███████░░░] 67%

## Performance Metrics

**Velocity:**

- Total plans completed: 11
- Average duration: 22 min
- Total execution time: 4.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1 | 3 | 152 min | 51 min |
| 2 | 3 | 30 min | 10 min |
| 3 | 3 | 45 min | 15 min |
| 4 | 2 | 13 min | 7 min |

**Recent Trend:**

- Last 5 plans: 04-02 (8 min), 04-01 (5 min), 03-03 (10 min), 03-02 (10 min), 03-01 (25 min)
- Trend: Improving
- Latest metric: Phase 04 Plan 02 — 8 min across 2 tasks and 3 files

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Initialization: Keep one shared semantic core even if package and module boundaries are reorganized before versioning.
- Initialization: Allow breaking API and architecture cleanup before versioning when it reduces long-term debt.
- Initialization: Keep the CLI strictly jq-compatible and put practical extensions on library surfaces instead.
- Initialization: First release needs npm and CLI dry-run readiness; MoonBit package must be publication-ready even if `mooncakes.io` publish is deferred.
- [Phase 01]: Compatibility exceptions must stay explicit in both the maintained corpus and the shared ledger; Phase 1 exits with zero temporary exceptions.
- [Phase 01]: Shared run-lane orchestration now lives in core for `Json`, `Value`, and JSON-text paths, leaving wrappers to adapt I/O and public errors.
- [Phase 01]: Fidelity-sensitive regressions are now proven at core, top-level MoonBit, JS wrapper, and native CLI differential layers rather than in core-only tests.
- [Phase 01]: Linux CI is the authoritative full differential proof path; local Windows verification remains useful for MoonBit, TS, and native `-e` smoke runs.
- [Phase 02]: The MoonBit public API defaults to the standard `Json` value lane, while `run_json_text` remains the formal compatibility lane.
- [Phase 02]: `run(filter, Json)` is the default public entrypoint; `compile(...).run(...)` is the explicit reuse path.
- [Phase 02]: `CompiledFilter` stays opaque, and normal MoonBit docs should keep users on `shina1024/jqx` rather than routing them through `core`.
- [Phase 02]: Broad `JqxError`-style public errors should be replaced by narrower entrypoint-specific composite errors while preserving structured leaf error payloads.
- [Phase 02]: The generated MoonBit contract now exposes `RunError`, `JsonTextRunError`, and `CompiledJsonTextRunError` instead of a broad public `JqxError`.
- [Phase 03]: Root JS/TS exports now lead with canonical direct runtime entrypoints — The main package should read as a direct-use runtime first rather than a mixed utility barrel.
- [Phase 03]: README and proof keep query and integration helpers as secondary lanes — Query helpers remain on the root package, but the quick start should stay centered on run(filter, input).
- [Phase 03]: Direct and bound runtimes now share one internal helper path for JSON value-lane conversion and typed-query normalization.
- [Phase 03]: Compiled filters stay on the direct runtime; `/bind` remains an explicit JSON-text backend integration surface instead of implying a second compiled contract.
- [Phase 03]: Package builds now repair missing current-platform tool shims before emitting artifacts so local verification survives cross-OS package reinstalls.
- [Phase 03]: Package-name smoke tests and declaration fixtures must run against fresh `dist/` artifacts instead of source-file fallbacks.
- [Phase 04]: User-facing CLI help and first-step docs now present `jqx` as the canonical command name instead of a contributor-oriented `moon run --target native cmd -- ...` invocation.
- [Phase 04]: Focused CLI wbtests now pin direct-input precedence, raw direct-input slurp, and jqx usage text while compile and execute remain delegated to the shared core.
- [Phase 04]: Maintained jq differential cases now name direct-input raw output, raw slurp, module-path imports, and runtime-error output ordering explicitly.
- [Phase 04]: Fast wbtests and native wbtests now mirror the maintained CLI parity corpus instead of describing a separate proof story.

### Pending Todos

None yet.

### Blockers/Concerns

- Local `bash ./scripts/jq_diff.sh` and `bash ./scripts/jq_upstream_ledger.sh --verify` are still not reliable final authorities in this Windows/WSL-like environment, so full differential proof currently depends on Linux CI.
- Decide in a later release-prep phase whether `mooncakes.io` publish stays deferred or becomes part of the first public release.

## Session Continuity

Last session: 2026-03-20T06:44:51.734Z
Stopped at: Phase 5 context gathered
Resume file: .planning/phases/05-schema-adapter-packages/05-CONTEXT.md
