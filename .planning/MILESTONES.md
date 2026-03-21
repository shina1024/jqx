# Milestones

## v0.1.0 Initial Release (Shipped: 2026-03-21)

**Scope:** 7 phases, 19 plans, 38 tasks
**Timeline:** 2026-03-12 -> 2026-03-21
**Git range:** `1b42b38` -> `6b31f73`
**Archive:** `.planning/milestones/v0.1.0-ROADMAP.md`, `.planning/milestones/v0.1.0-REQUIREMENTS.md`, `.planning/milestones/v0.1.0-MILESTONE-AUDIT.md`

**Key accomplishments:**

- Shared core compatibility, fidelity, and object-order proof now align with the maintained `jq 1.8.1` corpus, with explicit exception tracking and no residual compatibility debt in the shipped milestone.
- MoonBit users now get a canonical `Json`-first public API plus a JSON-text compatibility lane without depending on `@core.Value`.
- JS/TS users now get a runtime-first `@shina1024/jqx` package, `/bind` integration helpers, and working ESM, CJS, and declaration outputs.
- CLI users now get jq-compatible stdin, direct-input, option, and error-path workflows through the same shared semantic core.
- Standalone Zod, Yup, and Valibot adapter packages now sit on stable runtime contracts instead of internal core details.
- Release dry-runs, MoonBit publication readiness, cross-surface docs, and Nyquist validation coverage are all complete for the `0.1.0` baseline.

---
