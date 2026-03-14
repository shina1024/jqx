---
phase: 02-moonbit-public-api
plan: 01
subsystem: api
tags: [moonbit, public-api, docs, generated-contract]
requires: []
provides:
  - canonical top-level MoonBit runtime entrypoints centered on `parse_json`, `is_valid_json`, `compile`, `run`, and `run_json_text`
  - MoonBit quick-start docs that teach the direct `Json` lane first
  - generated public contract proof for the canonical runtime surface
affects: [02-02, 02-03, phase-3-js-ts-runtime, phase-6-release-readiness-and-docs]
tech-stack:
  added: []
  patterns:
    - top-level MoonBit API as the primary public surface
    - generated `.mbti` review as part of public API hardening
key-files:
  created: []
  modified:
    - jqx.mbt
    - README.mbt.md
    - jqx_test.mbt
    - pkg.generated.mbti
key-decisions:
  - "MoonBit quick start now teaches `run(filter, Json)` as the default path, with compile as the explicit reuse step."
  - "The top-level package keeps one small canonical naming set and does not retain alias-heavy compatibility spellings."
patterns-established:
  - "Treat `pkg.generated.mbti` as a first-class proof artifact whenever top-level MoonBit entrypoints change."
  - "Use docs and top-level tests to prove the intended API ordering, not only source inspection."
requirements-completed: [ARCH-02, MBT-01, MBT-05]
duration: 30 min shared across Phase 2 plans
completed: 2026-03-14
---

# Phase 2 Plan 01: MoonBit Runtime Entry Points Summary

**The top-level MoonBit package now presents one obvious runtime API, with `run(filter, Json)` taught as the normal entrypoint and the generated public contract aligned to that boundary.**

## Performance

- **Duration:** 30 min shared across Phase 2 plans
- **Started:** 2026-03-14T11:56:24+09:00
- **Completed:** 2026-03-14T12:25:57+09:00
- **Execution style:** shared implementation pass across Plans 01-03

## Accomplishments

- Kept the canonical top-level names in `jqx.mbt` and aligned the generated MoonBit contract to the intended small public surface.
- Updated MoonBit-facing docs so the direct `Json` lane is the first normal workflow users see.
- Kept top-level tests centered on the public package rather than reintroducing `core` as a parallel normal path.

## Execution Commits

Implementation for Plans 01-03 landed together because the public runtime naming, compiled-lane shaping, and error-contract cleanup touched the same boundary files:

1. **Phase 2 planning artifacts** - `ec677f4` (docs)
2. **Shared MoonBit public API implementation** - `80df341` (feat)

## Files Created/Modified

- `jqx.mbt` - keeps the canonical top-level runtime entrypoints and directs direct execution through the public package.
- `README.mbt.md` - presents the value lane first and demotes boundary helpers and internal packages.
- `jqx_test.mbt` - keeps top-level API proof focused on the public MoonBit package.
- `pkg.generated.mbti` - proves the generated public contract matches the intended top-level surface.

## Decisions Made

- Kept `parse_json` and `is_valid_json` as public helpers, but positioned them as boundary helpers instead of the main happy path.
- Avoided adding alias exports for older shapes while the package is still pre-1.0.

## Deviations from Plan

### Execution note

**1. [Execution] Implemented Plans 01-03 as one integrated public-surface change**
- **Why:** The runtime naming cleanup, compiled-lane shaping, and public error narrowing all touched `jqx.mbt`, `jqx_public_types.mbt`, tests, docs, and the generated `.mbti` together.
- **Impact:** The plan goals were preserved, but implementation was committed as one shared feature change rather than three isolated execution commits.

## Issues Encountered

- The plan-checker subagent could not read local files in this Windows environment because of a sandbox backend mismatch, so final plan/phase verification was completed through direct local inspection and the MoonBit quality gate.

## Next Phase Readiness

- Phase 3 can inherit the same canonical ordering for JS/TS public APIs: direct runtime use first, compiled reuse second, fidelity-sensitive text lane explicit.

## Self-Check: PASSED

- Found shared implementation commit `80df341`
- `moon info`, `moon fmt`, `moon check -d`, and `moon test` all passed after the public API changes

---
*Phase: 02-moonbit-public-api*
*Completed: 2026-03-14*
