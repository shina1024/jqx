# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v0.1.0 — Initial Release

**Shipped:** 2026-03-21
**Phases:** 7 | **Plans:** 19

### What Was Built

- A shared MoonBit semantic core with maintained `jq 1.8.1` compatibility proof, compatibility-lane fidelity, and cross-surface ordering checks.
- Canonical MoonBit, JS/TS, and CLI public surfaces that all route through the same semantics.
- Standalone schema-adapter packages, auditable release dry-runs, MoonBit package readiness proof, and complete Nyquist validation coverage.

### What Worked

- The phase-plan-summary cadence kept scope narrow and verification explicit.
- Canonical names and package boundaries were cleaned up before release instead of being preserved as long-term alias debt.
- Release and validation evidence lived in the repository, so closeout did not depend on reconstructing CI state from memory.

### What Was Inefficient

- Windows-local jq differential wrappers remained less reliable than Linux CI, which forced some proof to stay environment-specific.
- Milestone archival needed manual cleanup after `gsd-tools milestone complete` generated only partial archive metadata.

### Patterns Established

- Treat compatibility exceptions as ledgered, explicit, and removable.
- Keep the JS/TS root package runtime-first, with adapters and advanced bindings on clearly separate surfaces.
- Close milestone audits only after every phase has both verification and Nyquist-compliant validation artifacts.

### Key Lessons

1. Shared semantics stay tractable when every surface is forced to prove behavior against the same compatibility and validation artifacts.
2. Pre-release API cleanup is worth doing early; carrying alias-heavy surfaces into release would have created avoidable semver debt.
3. Milestone closeout needs both product proof and process proof; otherwise tech debt just moves into release operations.

### Cost Observations

- Notable: 19 plans and 38 tasks were enough to reach a clean `v0.1.0` archive without reopening scope after the roadmap was set.
- Notable: The major closeout overhead came from validation reconciliation and archive curation, not from late feature work.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Key Change |
|-----------|--------|------------|
| v0.1.0 | 7 | Established the shared-core, verification-first, and audit-backed release workflow |

### Top Lessons (Verified Across Milestones)

1. More milestones are needed before cross-milestone trends become stable.
