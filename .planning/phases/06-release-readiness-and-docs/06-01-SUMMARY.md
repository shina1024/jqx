---
phase: 06-release-readiness-and-docs
plan: 01
subsystem: infra
tags: [github-actions, release, npm, cli, moonbit, docs]
requires:
  - phase: 03-js-ts-runtime-surface
    provides: publishable root and adapter package surfaces verified by ts_packages tooling
  - phase: 04-cli-workflow-parity
    provides: native jqx build and packaging contract for jqx and jqx.exe archives
  - phase: 05-schema-adapter-packages
    provides: standalone npm package identities and stable runtime export boundaries
provides:
  - npm dry-run workflow audit artifact generated from the publishable package list
  - CLI workflow_dispatch dry-run path that uploads packaged archives without publishing a GitHub Release
  - repository-tracked release audit ledger for npm, CLI, and MoonBit readiness evidence
affects: [06-02, 06-03, release-readiness, docs]
tech-stack:
  added: []
  patterns:
    - release proof paths produce auditable artifacts before any public publish step
    - release ledgers record package names, archive names, smoke commands, and publication prerequisites in-repo
key-files:
  created:
    - .planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md
    - .planning/phases/06-release-readiness-and-docs/06-01-SUMMARY.md
  modified:
    - .github/workflows/release-npm.yml
    - .github/workflows/release-cli.yml
key-decisions:
  - "The npm dry-run path should upload an audit artifact generated from `scripts/ts_packages.mjs list` so release evidence stays aligned with the repo's publishable package source of truth."
  - "CLI packaging and GitHub Release publication stay in one workflow, but `workflow_dispatch` now exposes `dry_run` so maintainers can inspect uploaded archives without publishing."
patterns-established:
  - "Release workflows should keep non-publishing proof paths explicit and artifact-backed."
  - "Phase-level release audit documents should pre-list package identities, asset names, and exact smoke commands for each public surface."
requirements-completed: [CLI-03, REL-01, REL-02]
duration: 9 min
completed: 2026-03-20
---

# Phase 06 Plan 01: Release Readiness and Docs Summary

**Auditable npm and CLI dry-run workflows with a tracked Phase 6 release ledger for npm, CLI, and MoonBit readiness evidence**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-20T13:38:30Z
- **Completed:** 2026-03-20T13:47:21Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added an npm workflow audit step that records each publishable package, its version, `dist/` contents, and exported runtime entrypoints, then uploads that audit as a workflow artifact before publish.
- Added a CLI `dry_run` dispatch input and prepare output so maintainers can build and upload Linux, macOS, and Windows archives without publishing a GitHub Release.
- Created a repository-tracked Phase 6 release ledger that pre-lists the npm packages, CLI asset names, MoonBit package identity, and exact smoke commands expected during release audits.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add explicit non-publishing audit paths to the npm and CLI release workflows** - `755dae7` (feat)
2. **Task 2: Create the tracked Phase 6 release audit ledger with concrete evidence fields** - `36902be` (docs)

## Files Created/Modified

- `.github/workflows/release-npm.yml` - adds the package-surface audit artifact while preserving version checks, frozen-lockfile verification, and npm dry-run publish behavior.
- `.github/workflows/release-cli.yml` - adds `workflow_dispatch` `dry_run` support and skips GitHub Release publication when maintainers are only auditing packaged artifacts.
- `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md` - records the concrete npm, CLI, and MoonBit evidence fields maintainers should fill in after each release-readiness run.

## Decisions Made

- Kept the repo's publishable-package source of truth in `scripts/ts_packages.mjs list` and reused it inside the npm workflow audit step instead of hard-coding package names in GitHub Actions.
- Kept CLI packaging and publication in a single workflow so archive names and build steps stay canonical, but separated audit from publish with an explicit `dry_run` guard on the GitHub Release step.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required for this plan's implementation.

## Next Phase Readiness

- Plan `06-02` can use the tracked release ledger and the new dry-run proof paths to audit MoonBit package readiness against the same release-review standard.
- Plan `06-03` can align public docs to the concrete package names, artifact names, and smoke commands now captured in Phase 6 release evidence.

## Self-Check: PASSED

- Found `.planning/phases/06-release-readiness-and-docs/06-01-SUMMARY.md`
- Found `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md`
- Found commit `755dae7`
- Found commit `36902be`

---
*Phase: 06-release-readiness-and-docs*
*Completed: 2026-03-20*
