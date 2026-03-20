# Phase 6: Release Readiness and Docs - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate publishable artifacts, MoonBit package readiness, and surface-consistent docs across CLI, JS/TS, and MoonBit. This phase hardens release proof and canonical documentation; it does not add new runtime features or new distribution channels.

</domain>

<decisions>
## Implementation Decisions

### Release evidence and audit depth
- npm readiness requires `release-npm.yml` dry-run success, artifact inspection of each package's `dist/` contents and export map, and a local consumer smoke check against the built packages.
- CLI readiness requires successful 3-OS packaging from `release-cli.yml`, archive-content and executable-name audit, and post-extraction smoke runs of `jqx` / `jqx.exe`.
- Release readiness is not satisfied by CI green alone; audit evidence must exist both in CI logs and in a repository-tracked audit document.
- README instructions for release consumption should be auditable against the actual produced artifacts, not against contributor-only build commands.

### CLI release distribution story
- The first public CLI install story is GitHub Releases manual download only.
- Root docs should say to download the CLI from GitHub Releases and show execution examples, but should not add OS-specific extraction walkthroughs, PATH setup guidance, or asset-name rules.
- CLI release docs should stay narrow and avoid implying Homebrew, winget, Scoop, or other package-manager channels that do not exist yet.
- CLI packaging must keep the public executable name `jqx` / `jqx.exe` inside the produced archives.

### MoonBit publication posture
- MoonBit is a first-class public surface alongside CLI and npm, not a tentative or future-only lane.
- Documentation should remove "planned" language around MoonBit publication and treat `shina1024/jqx` as the formal MoonBit package surface, with publication following immediately once Phase 6 readiness work is complete.
- Install docs should present CLI, npm, and MoonBit at the same granularity rather than routing MoonBit users through GitHub-only fallback guidance.
- MoonBit quick-start examples should continue to center the canonical `run`, `compile`, and `run_json_text` surface decisions established in Phase 2.

### Documentation ownership and ordering
- The root README is the project entrypoint and carries install guidance plus the minimum quick-start for each public surface.
- In the root README, surface order should be CLI first, then MoonBit, then JS/TS.
- Detailed JS/TS guidance belongs in `ts/jqx/README.md`; detailed adapter guidance belongs in each adapter package README.
- The root README should keep only one short representative adapter example and should not try to mirror every adapter package's full guidance.
- For MoonBit, the root README remains the canonical detailed public README until a separate MoonBit-specific public doc exists.

### Claude's Discretion
- Exact filename, section layout, and granularity of the repository-tracked release audit document.
- Exact local smoke harness or script shape used to verify npm package consumption and extracted CLI archives.
- Exact wording of install and quick-start sections, as long as CLI docs stay minimal, MoonBit stays first-class, and package responsibilities stay separated.
- Exact choice of representative adapter example kept in the root README, as long as only one short example remains.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and release requirements
- `.planning/ROADMAP.md` — Phase 6 goal, success criteria, and plan split for release readiness and docs.
- `.planning/REQUIREMENTS.md` — `CLI-03`, `MBT-06`, `REL-01`, `REL-02`, and `REL-03` define the required release and documentation outcomes.
- `.planning/PROJECT.md` — project-level constraints that all three surfaces are equal public deliverables and that release readiness is part of the v1 goal.
- `.planning/STATE.md` — current release-related blockers, including Linux CI as the authoritative jq differential path and the need to settle MoonBit publication timing.

### Prior surface decisions to preserve
- `.planning/phases/02-moonbit-public-api/02-CONTEXT.md` — MoonBit public API priority, canonical names, and the value-lane vs JSON-text-lane presentation order.
- `.planning/phases/03-js-ts-runtime-surface/03-CONTEXT.md` — JS/TS direct runtime, `/bind`, query lane, and documentation positioning decisions.
- `.planning/phases/04-cli-workflow-parity/04-CONTEXT.md` — `jqx` as the canonical CLI command name and CLI docs/usage alignment constraints.
- `.planning/phases/05-schema-adapter-packages/05-CONTEXT.md` — standalone adapter package boundaries and the requirement to avoid old `@shina1024/jqx/*` adapter imports in canonical docs.

### Release workflows and packaging contracts
- `.github/workflows/release-npm.yml` — npm tag/dry-run flow, version-match gate, TS verification, and publish/dry-run behavior.
- `.github/workflows/release-cli.yml` — CLI multi-OS packaging flow, archive naming, binary naming, and GitHub Release publishing behavior.
- `scripts/ts_packages.mjs` — TS package refresh/verify orchestration used by release verification.
- `scripts/ts_package_build.mjs` — built-artifact packaging contract for ESM/CJS/types outputs and dependency repair behavior.

### Current public docs and metadata to align
- `README.mbt.md` — root project README and current MoonBit-facing public README that must become the canonical cross-surface entrypoint.
- `ts/jqx/README.md` — canonical JS/TS runtime README.
- `ts/zod-adapter/README.md` — canonical Zod adapter README.
- `ts/yup-adapter/README.md` — canonical Yup adapter README.
- `ts/valibot-adapter/README.md` — canonical Valibot adapter README.
- `ts/jqx/package.json` — npm metadata, export map, and public package identity for the JS/TS runtime.
- `moon.mod.json` — MoonBit package metadata and published package identity.
- `pkg.generated.mbti` — current generated MoonBit public API contract that documentation must match.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/release-npm.yml`: already performs version/tag checks, TS package verification, and `pnpm publish` dry-runs.
- `.github/workflows/release-cli.yml`: already builds release artifacts on Linux/macOS/Windows, renames binaries to `jqx` / `jqx.exe`, and performs a minimal smoke run before packaging.
- `scripts/ts_packages.mjs` and `scripts/ts_package_build.mjs`: already define the repeatable build/verify path for shipped TS artifacts rather than source-only tests.
- `README.mbt.md`, `ts/jqx/README.md`, and the adapter READMEs: already provide the main public docs surfaces that Phase 6 needs to align rather than replace.
- `moon.mod.json`, `ts/jqx/package.json`, and `pkg.generated.mbti`: already expose the current publish metadata and API contract that release docs must reflect.

### Established Patterns
- Release automation is tag-driven via GitHub Actions, with manual dispatch paths for dry-runs and prerelease control.
- JS/TS package verification builds `dist/` first and then tests the package-name entrypoints, which supports artifact-level release proof.
- CLI packaging already normalizes the shipped executable name to `jqx` / `jqx.exe` even though build outputs originate from `cmd`.
- The root README currently serves double duty as the repository landing page and the MoonBit package readme, so root-doc changes affect both audiences.
- `ts/jqx/README.md` and the adapter READMEs are already close to the intended Phase 5+ public story, while `README.mbt.md` still carries stale adapter subpath examples and tentative MoonBit publication wording.

### Integration Points
- Plan 06-01 should center on the release workflows, artifact audit capture, and local smoke verification paths.
- Plan 06-02 should center on MoonBit package metadata, publication-readiness checks, and the root README's MoonBit install/publication language.
- Plan 06-03 should center on `README.mbt.md`, `ts/jqx/README.md`, and the adapter READMEs, keeping cross-surface naming and example order consistent with prior phase decisions.

</code_context>

<specifics>
## Specific Ideas

- Keep the first CLI release story deliberately minimal: download from GitHub Releases, then run `jqx`.
- Present MoonBit with the same confidence level as npm in the install section instead of treating it as a secondary or future surface.
- Keep only one representative adapter example in the root README to avoid repeating and drifting from package-specific docs.
- Use the Phase 6 audit artifacts to prove both the workflow path and the consumer path, not just that maintainers can build packages locally.

</specifics>

<deferred>
## Deferred Ideas

- Additional CLI distribution channels such as Homebrew, winget, Scoop, or OS-specific installers belong in a future phase.
- Broader MoonBit release automation beyond publication-ready metadata and immediate publish readiness is out of scope unless Phase 6 uncovers a blocking gap.

</deferred>

---

*Phase: 06-release-readiness-and-docs*
*Context gathered: 2026-03-20*
