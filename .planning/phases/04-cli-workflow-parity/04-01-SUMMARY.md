---
phase: 04-cli-workflow-parity
plan: 01
subsystem: cli
tags: [cli, moonbit, jq, docs, testing]
requires:
  - phase: 01-02
    provides: shared-core compile and execute entrypoints consumed by the CLI adapter
  - phase: 01-03
    provides: release-profile CLI parity proof and regression expectations for observable output behavior
provides:
  - jqx-first CLI usage text and README quick-start examples
  - focused wbtests for direct-input precedence, raw direct-input slurp, and jqx usage text
  - explicit proof that CLI transport stays in `cmd` while compile and execute stay in the shared core
affects: [04-02, phase-6-release-readiness-and-docs, cli]
tech-stack:
  added: []
  patterns:
    - jqx-first public CLI contract shared between help text and README examples
    - wbtests that pin CLI transport behavior without moving semantics out of the shared core
key-files:
  created: []
  modified:
    - cmd/main_cli.mbt
    - README.mbt.md
    - cmd/main_wbtest.mbt
key-decisions:
  - "User-facing CLI help and docs now present `jqx` as the only canonical command name; contributor `moon run --target native cmd -- ...` workflows stay out of public CLI text."
  - "Direct-input precedence, raw direct-input slurp, and raw string output remain regression-proofed at the CLI adapter boundary while compile and execute stay on `@lib.compile(...)` and `@lib.execute_for_cli(...)`."
patterns-established:
  - "Keep CLI help text and README quick-start examples in lockstep around the public `jqx` command."
  - "Strengthen CLI behavior with wbtests over `usage_lines()`, `parse_cli_inputs(...)`, and `run_cli(...)` before considering transport-layer code changes."
requirements-completed: [CLI-01]
duration: 5 min
completed: 2026-03-20
---

# Phase 4 Plan 01: CLI Workflow Contract Summary

**jqx-first CLI usage text with focused wbtests that pin direct-input precedence, raw/slurp transport behavior, and shared-core execution flow**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-20T14:28:00+09:00
- **Completed:** 2026-03-20T14:33:28+09:00
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Switched the public CLI usage summary and examples in `cmd/main_cli.mbt` to the canonical `jqx` command name and reduced the option list to the explicit Phase 4 surface.
- Aligned the README CLI quick-start wording with the same jqx-first public contract for stdin and direct input.
- Added focused wbtests for jqx usage text, direct-input precedence over stdin, raw direct-input slurp, and raw string output formatting while keeping compile and execute routed through the shared core.

## Task Commits

Each task was committed atomically:

1. **Task 1: Canonicalize the public `jqx` usage and example text** - `4dba761` (feat)
2. **Task 2: Tighten focused regression proof for direct input and observable output behavior** - `052bef3` (test)

**Plan metadata:** pending in follow-up docs commit

## Files Created/Modified
- `cmd/main_cli.mbt` - presents the canonical jqx usage summary, examples, and option list while keeping the CLI on shared-core compile and execute entrypoints.
- `README.mbt.md` - keeps the public CLI quick start phrased around stdin and direct input through the `jqx` executable.
- `cmd/main_wbtest.mbt` - adds focused regressions for jqx usage text, direct-input precedence, raw direct-input slurp, and raw string output behavior.

## Decisions Made
- Treated `jqx` as the only public command identity in CLI help and first-step docs, keeping `moon run --target native cmd -- ...` as contributor-only context outside the user-facing contract.
- Tightened proof in wbtests instead of rewriting runtime code because the existing CLI adapter logic already satisfied the required direct-input, raw/slurp, and partial-output behavior while delegating semantics to the shared core.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase `04-02` can focus on the remaining common-option parity and error-path hardening with the public jqx command identity already locked in.
- The CLI workflow surface now has fast wbtest coverage for the direct-input and raw/slurp transport cases most likely to drift during follow-up parity work.

## Self-Check: PASSED

- Found `.planning/phases/04-cli-workflow-parity/04-01-SUMMARY.md`
- Found task commits `4dba761` and `052bef3` in git history

---
*Phase: 04-cli-workflow-parity*
*Completed: 2026-03-20*
