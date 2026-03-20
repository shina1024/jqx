---
phase: 06-release-readiness-and-docs
plan: 03
subsystem: docs
tags: [docs, cli, moonbit, typescript, adapters]
requires:
  - phase: 06-01
    provides: release-audit artifact names, package names, and dry-run proof paths
  - phase: 06-02
    provides: canonical MoonBit package story and publish-preflight requirements
provides:
  - Root README ordered as CLI, MoonBit, then JS/TS
  - JS/TS package README aligned to canonical runtime and `/bind` boundaries
  - Standalone adapter READMEs cross-linked to the runtime docs and root overview
affects: [release-readiness, docs]
tech-stack:
  added: []
  patterns:
    - Root docs stay cross-surface and concise; package READMEs own detailed surface-specific guidance
    - Standalone adapter package names are the only documented validator entrypoints
key-files:
  created:
    - .planning/phases/06-release-readiness-and-docs/06-03-SUMMARY.md
  modified:
    - README.mbt.md
    - ts/jqx/README.md
    - ts/zod-adapter/README.md
    - ts/yup-adapter/README.md
    - ts/valibot-adapter/README.md
key-decisions:
  - "The root README now owns only the cross-surface install story and one representative quick start per surface."
  - "Detailed JS/TS runtime and adapter guidance stays in package READMEs so canonical package names do not drift independently."
patterns-established:
  - "CLI, MoonBit, and JS/TS docs should be introduced in that order from the root README."
  - "Package-specific behavior should link back to the root overview rather than duplicating cross-surface guidance."
requirements-completed: [REL-03]
duration: 12 min
completed: 2026-03-20
---

# Phase 06 Plan 03: Release Readiness and Docs Summary

**The public documentation story is now consistent across CLI, MoonBit, JS/TS, and the standalone adapter packages.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-20T14:07:00Z
- **Completed:** 2026-03-20T14:19:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Rewrote the root README so users meet the three public surfaces in the intended order: CLI first, MoonBit second, JS/TS third.
- Removed the old root-package adapter subpath story from the root docs and replaced it with a representative standalone adapter example using `@shina1024/jqx-zod-adapter`.
- Added ownership links between the root docs, `ts/jqx/README.md`, and the validator-specific adapter READMEs so the detailed runtime and adapter guidance lives where it belongs.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite the root README as the canonical cross-surface entrypoint** - `ef4791a` (docs)
2. **Task 2: Align JS/TS and adapter package READMEs with the canonical root documentation** - `681ad9f` (docs)

## Files Created/Modified

- `README.mbt.md` - introduces CLI, MoonBit, and JS/TS in the intended order and uses only canonical package names.
- `ts/jqx/README.md` - keeps the detailed runtime, query, and `/bind` guidance aligned with the root overview.
- `ts/zod-adapter/README.md` - preserves the `createAdapter(runtime).filter(...)` on-ramp and links back to the runtime docs.
- `ts/yup-adapter/README.md` - preserves the canonical standalone Yup package story and cross-links the runtime docs.
- `ts/valibot-adapter/README.md` - preserves the canonical standalone Valibot package story and cross-links the runtime docs.

## Decisions Made

- Kept the root README high-level and cross-surface, with package READMEs owning the detailed runtime and adapter behavior that is more likely to evolve.
- Used standalone adapter package names everywhere and removed the old root-package adapter subpath story from canonical docs.

## Deviations from Plan

- None. The root and package READMEs were aligned directly against the final package boundaries and canonical names from earlier phases.

## Issues Encountered

- None.

## User Setup Required

- None.

## Next Phase Readiness

- Phase 06 is ready for final verification and completion tracking.

## Self-Check: PASSED

- `README.mbt.md` teaches CLI, MoonBit, and JS/TS in that order
- Root docs use `@shina1024/jqx-zod-adapter` and do not reference removed root adapter subpaths
- `ts/jqx/README.md` documents `runJsonText`, `bindRuntime`, and `bindQueryRuntime`
- Adapter READMEs keep `createAdapter(runtime)` as the primary on-ramp

---
*Phase: 06-release-readiness-and-docs*
*Completed: 2026-03-20*
