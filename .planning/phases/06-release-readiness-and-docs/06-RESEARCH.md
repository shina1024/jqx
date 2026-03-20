# Phase 6: Release Readiness and Docs - Research

**Researched:** 2026-03-20
**Domain:** release workflow proof, MoonBit publication readiness, and cross-surface documentation alignment
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- npm readiness requires `release-npm.yml` dry-run success, artifact inspection of each package's `dist/` contents and export map, and a local consumer smoke check against the built packages.
- CLI readiness requires successful 3-OS packaging from `release-cli.yml`, archive-content and executable-name audit, and post-extraction smoke runs of `jqx` / `jqx.exe`.
- Release readiness is not satisfied by CI green alone; audit evidence must exist both in CI logs and in a repository-tracked audit document.
- The first public CLI install story is GitHub Releases manual download only.
- Root docs should say to download the CLI from GitHub Releases and show execution examples, but should not add OS-specific extraction walkthroughs, PATH setup guidance, or asset-name rules.
- MoonBit is a first-class public surface alongside CLI and npm, not a tentative or future-only lane.
- Documentation should remove "planned" language around MoonBit publication and treat `shina1024/jqx` as the formal MoonBit package surface, with publication following immediately once Phase 6 readiness work is complete.
- In the root README, surface order should be CLI first, then MoonBit, then JS/TS.
- Detailed JS/TS guidance belongs in `ts/jqx/README.md`; detailed adapter guidance belongs in each adapter package README.
- The root README should keep only one short representative adapter example and should not mirror every adapter package's full guidance.

### Claude's Discretion
- Exact filename and layout of the repository-tracked release audit document.
- Exact local smoke harness for npm package consumption and extracted CLI archives.
- Exact wording of install and quick-start sections as long as the locked positioning and canonical names remain intact.
- Exact MoonBit packaging audit checklist beyond the already-known metadata and API-contract checks.

### Deferred Ideas (OUT OF SCOPE)
- Additional CLI distribution channels such as Homebrew, winget, Scoop, or OS-specific installers.
- Broader MoonBit release automation beyond publication-readiness proof.
- New runtime features, new public APIs, or new package surfaces.
</user_constraints>

<research_summary>
## Summary

Phase 6 is partly scaffolded already, but the remaining work is not cosmetic. The repo has real release workflows and mostly-correct package surfaces, yet the proof chain still breaks in three places:

1. `release-npm.yml` already supports `workflow_dispatch` with a `dry_run` input, version-vs-tag checks, and frozen-lockfile TS verification, but it does not currently preserve a repository-tracked audit of package artifacts, export maps, or consumer smoke results.
2. `release-cli.yml` already builds Linux/macOS/Windows archives and smoke-runs the built binary before packaging, but it has no dry-run or non-publishing mode. `workflow_dispatch` still ends by publishing a GitHub Release, so `REL-02` is not satisfied yet.
3. `README.mbt.md` is still the root cross-surface entrypoint and the MoonBit package readme, but it currently contradicts earlier phase decisions: it says MoonBit publication is "planned" and still teaches old adapter imports like `@shina1024/jqx/zod`, `@shina1024/jqx/yup`, and `@shina1024/jqx/valibot`.

Verified current state from local inspection:
- `ts/jqx/README.md` already reflects the intended JS/TS story: canonical runtime names, `@shina1024/jqx/bind`, and standalone adapter packages such as `@shina1024/jqx-zod-adapter`.
- `pkg.generated.mbti` exposes the canonical MoonBit surface from Phase 2: `parse_json`, `is_valid_json`, `compile`, `run`, `run_json_text`, plus compiled-filter methods `CompiledFilter::run` and `CompiledFilter::run_json_text`.
- `moon package --list --manifest-path moon.mod.json` succeeds locally, which proves the module can be bundled, but the current package listing includes `_bundle_tmp` and `_bundle_wasmgc`. That means MoonBit publication readiness needs an explicit package-content audit, not just metadata inspection.
- `moon publish --dry-run --manifest-path moon.mod.json` currently fails before publish because no MoonBit credentials file exists locally. Planning should treat authenticated publish dry-run as a separate preflight step with a clear prerequisite (`moon login`), not as something that always works in CI-free local environments.
- `node ./scripts/ts_packages.mjs list` reports the five publishable TS package directories: `ts/adapter-core`, `ts/zod-adapter`, `ts/yup-adapter`, `ts/valibot-adapter`, and `ts/jqx`.

Primary planning implication:
- `06-01` should own release workflow proof and artifact auditing, including a fix for the missing CLI dry-run/non-publishing path.
- `06-02` should own MoonBit packaging audit, metadata cleanup, and an authenticated publication-readiness preflight path.
- `06-03` should own cross-surface documentation alignment, with `README.mbt.md` as the main drift hotspot and `ts/jqx/README.md` plus adapter READMEs as secondary references that must stay consistent.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries and tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `.github/workflows/release-npm.yml` | repo current | npm release and dry-run workflow | Already encodes version matching, TS verification, and `pnpm publish` dry-run behavior |
| `.github/workflows/release-cli.yml` | repo current | 3-OS native packaging and GitHub Release publication | Already defines the executable naming and archive shape contract |
| `moon.mod.json` | repo current | MoonBit package metadata and readme binding | This is the package identity that `mooncakes.io` will consume |
| `pkg.generated.mbti` | generated current | Public MoonBit API contract | This is the canonical proof of what the MoonBit surface actually exports |
| `README.mbt.md` | repo current | Root entrypoint and MoonBit package readme | This is the highest-risk drift surface because it serves multiple audiences |
| `ts/jqx/package.json` | repo current | npm metadata and public export map | This is the observable JS/TS package contract |
| `ts/jqx/README.md` | repo current | Canonical JS/TS runtime docs | Already close to the intended Phase 6 state |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `scripts/ts_packages.mjs` | repo current | Enumerate TS publishable packages and support release verification | Use when auditing npm release coverage and package order |
| `scripts/ts_packages.sh` / `scripts/ts_packages.ps1` | repo current | Frozen-lockfile workspace verification and package refresh | Use as the TS release-quality gate |
| `scripts/ts_package_build.mjs` | repo current | Built-artifact packaging contract for TS packages | Use when package artifact expectations need to match docs and publish output |
| `ts/zod-adapter/README.md` | repo current | Canonical Zod adapter docs | Use as the package-level source of truth for adapter guidance |
| `ts/yup-adapter/README.md` | repo current | Canonical Yup adapter docs | Use as the package-level source of truth for adapter guidance |
| `ts/valibot-adapter/README.md` | repo current | Canonical Valibot adapter docs | Use as the package-level source of truth for adapter guidance |
| `moon package --list --manifest-path moon.mod.json` | locally verified | MoonBit package-content preflight | Use to audit what would actually ship before publish |
| `moon publish --dry-run --manifest-path moon.mod.json` | locally inspected | Authenticated MoonBit publish preflight | Use after `moon login`; current local environment proves the login prerequisite is real |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Treating workflow green as release proof | Repository-tracked audit docs with artifact inspection | Slightly more work, but it makes release readiness reviewable and durable |
| Reusing `release-cli.yml` as-is for dry-run | Splitting packaging/audit from publish or adding a non-publishing mode | More YAML work, but required for `REL-02` because current dispatch still publishes |
| Keeping MoonBit publish readiness as a docs-only check | Using `moon package --list` and authenticated `moon publish --dry-run` as explicit proof steps | More operationally concrete and catches real package-content problems |
| Keeping detailed adapter docs in the root README | Moving details back to package READMEs and keeping one representative root example | Reduces drift and preserves one clear owner per surface |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Separate "build and audit" from "publish"
**What:** The release workflow should let maintainers build artifacts, inspect them, and record evidence before anything becomes public.
**When to use:** For CLI release automation, npm artifact review, and release-audit documentation.
**Example:**
- npm already has `dry_run`; Phase 6 should extend that path with artifact evidence.
- CLI currently lacks this split; Phase 6 likely needs a draft/non-publishing path or a separated packaging workflow.

### Pattern 2: Release proof must include shipped artifact inspection
**What:** Verification should target the produced archives and package bundles, not only source trees or CI pass/fail status.
**When to use:** For npm export-map checks, package consumer smoke tests, MoonBit publish bundle review, and CLI archive inspection.
**Example:**
- inspect each TS package's built `dist/` outputs and entrypoints
- inspect CLI archives for `jqx` / `jqx.exe`
- inspect MoonBit package contents via `moon package --list`

### Pattern 3: One doc owner per public surface
**What:** Root README introduces all surfaces; each package README owns its detailed public guidance.
**When to use:** For README restructuring and example pruning.
**Example:**
- `README.mbt.md`: install overview and one short adapter example
- `ts/jqx/README.md`: direct runtime and `/bind` details
- adapter READMEs: validator-specific install and `createAdapter(runtime).filter(...)` examples

### Pattern 4: MoonBit readiness is metadata + package contents + public contract
**What:** Publication readiness is not only `moon.mod.json`. It is the combination of metadata, what the package actually bundles, and whether the documented API matches the generated `.mbti`.
**When to use:** For `MBT-06` planning and execution.
**Example:**
- `moon.mod.json` names `README.mbt.md` as the published readme
- `pkg.generated.mbti` defines the actual public function names
- `moon package --list` reveals whether unwanted build directories or files would ship

### Pattern 5: Canonical names must stay aligned across all examples
**What:** The same public names should appear in root docs, package docs, and artifact-install guidance.
**When to use:** For `REL-03`.
**Example:**
- MoonBit: `run`, `compile`, `run_json_text`
- JS/TS: `run`, `compile`, `runJsonText`, `bindRuntime`, `bindQueryRuntime`
- adapters: standalone package names only
- CLI: `jqx` from GitHub Releases, not package-manager channels that do not exist

## Validation Architecture

Phase 6 validation needs four layers:

- **MoonBit quality gate:** `moon info && moon fmt && moon check && moon test`
- **TS package gate:** `bash ./scripts/ts_packages.sh verify --frozen-lockfile`
- **MoonBit package-content gate:** `moon package --list --manifest-path moon.mod.json`
- **Authenticated MoonBit publish preflight:** `moon publish --dry-run --manifest-path moon.mod.json` after `moon login`

Manual-only release verifications still matter:
- Run the npm release workflow through `workflow_dispatch` with `dry_run=true`, then record package-by-package artifact and consumer-smoke evidence in a repository-tracked audit document.
- Run a non-publishing CLI packaging path across Linux/macOS/Windows, inspect archive contents, extract the archive, and smoke-run `jqx` / `jqx.exe`.

Current local findings:
- `moon package --list --manifest-path moon.mod.json` passed and produced `C:\\Users\\shina\\repos\\jqx\\_build\\publish\\shina1024-jqx-0.1.0.zip`
- the package listing currently includes `_bundle_tmp` and `_bundle_wasmgc`, so bundle hygiene is an explicit planning concern
- `moon publish --dry-run --manifest-path moon.mod.json` failed with `failed to open credentials file ... please login first`

Planning implication:
- no Wave 0 test framework work is needed
- but the plans must reserve explicit steps for release-audit evidence, MoonBit bundle hygiene, and authenticated publish preflight
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but already have the right repo-level solution:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TS package release coverage | Hard-coded package lists in workflow steps | `node ./scripts/ts_packages.mjs list` | The repo already centralizes publishable package enumeration |
| Cross-surface API truth | Manually rewritten API summaries | `pkg.generated.mbti` and package README entrypoints | Generated interface and package docs are the authoritative sources |
| MoonBit publish readiness | Metadata-only checklist | `moon.mod.json` + `moon package --list` + `moon publish --dry-run` | This catches both package identity and actual shipped contents |
| Adapter docs in root README | Repeating full adapter tutorials in `README.mbt.md` | One short representative example in root, details in adapter READMEs | Avoids drift after Phase 5 surface cleanup |
| CLI install guidance | Inventing package-manager instructions | GitHub Releases download story only | Context explicitly forbids implying channels that do not exist |
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Treating `release-cli.yml` as a safe dry-run path when it still publishes
**What goes wrong:** A maintainer triggers `workflow_dispatch` for inspection and unintentionally creates a GitHub Release.
**Why it happens:** The current workflow has `prerelease`, but no true dry-run or draft-only branch.
**How to avoid:** Add a non-publishing path or split packaging from publication before claiming `REL-02`.

### Pitfall 2: Updating root docs without pruning old adapter import paths
**What goes wrong:** `README.mbt.md` keeps teaching `@shina1024/jqx/zod` even though the canonical Phase 5 surface is standalone adapter packages.
**Why it happens:** The root README currently mixes cross-surface overview with detailed JS/TS examples.
**How to avoid:** Keep one short adapter example in root and route details to package READMEs.

### Pitfall 3: Claiming MoonBit publish readiness from metadata alone
**What goes wrong:** `moon.mod.json` looks fine, but the packaged module still includes unwanted generated directories or misses a readme/API alignment check.
**Why it happens:** Metadata inspection is faster than packaging inspection.
**How to avoid:** Make `moon package --list` and `.mbti`-vs-doc checks part of the required acceptance path.

### Pitfall 4: Leaving MoonBit positioned as tentative while Phase 2 already made it first-class
**What goes wrong:** Root docs still say MoonBit publication is "planned," weakening the equal-surface public story.
**Why it happens:** The root README predates the later public API and adapter surface cleanup.
**How to avoid:** Make MoonBit install and quick-start language as confident as CLI and npm once readiness work is complete.

### Pitfall 5: Releasing without a repository-tracked audit trail
**What goes wrong:** CI logs prove something happened once, but maintainers cannot review or compare release readiness over time.
**Why it happens:** Workflow output feels sufficient during implementation.
**How to avoid:** Require an audit document that records release workflow runs, artifact checks, and smoke results.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### npm release already supports dry-run and version gating
```yaml
workflow_dispatch:
  inputs:
    dry_run:
      default: false
```

### CLI release workflow still publishes a GitHub Release on dispatch
```yaml
- name: Publish GitHub Release
  uses: softprops/action-gh-release@v2
```

### Root README still positions MoonBit as tentative
```md
- MoonBit package on `mooncakes.io`: planned
```

### Root README still teaches removed adapter subpaths
```md
- `import { createAdapter } from "@shina1024/jqx/zod"`
```

### JS/TS package README already teaches standalone adapter packages
```ts
import { createAdapter } from "@shina1024/jqx-zod-adapter";
```
 </code_examples>

<open_questions>
## Open Questions

1. **How should CLI dry-run be introduced without weakening the real release workflow?**
   - What we know: current `release-cli.yml` always reaches a publish step.
   - What is unclear: whether the cleanest fix is a draft-release mode, a `dry_run` input, or a split build-only workflow.
   - Recommendation: prefer a dedicated non-publishing packaging/audit path so artifact inspection is possible without side effects.

2. **What should the repository-tracked audit artifact look like?**
   - What we know: context requires a tracked audit document, not just CI logs.
   - What is unclear: whether Phase 6 should use one per-surface audit file or one combined release-readiness document.
   - Recommendation: use one combined Phase 6 audit document so npm, CLI, and MoonBit evidence stays comparable in one place.

3. **How strict should MoonBit package-content cleanup be before publication?**
   - What we know: `moon package --list` currently includes `_bundle_tmp` and `_bundle_wasmgc`.
   - What is unclear: whether those directories are acceptable implementation artifacts or packaging leakage that should be excluded.
   - Recommendation: treat them as suspect until explicitly justified; publication-readiness should bias toward a minimal, reviewable package bundle.

4. **How much authenticated MoonBit publication proof is required for `MBT-06`?**
   - What we know: local `moon publish --dry-run` requires credentials.
   - What is unclear: whether Phase 6 execution should stop at `moon package --list` if credentials are unavailable, or require a maintainer-authenticated dry-run before marking the requirement complete.
   - Recommendation: plan for both: unauthenticated local packaging proof plus an authenticated publish dry-run step with an explicit prerequisite.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `AGENTS.md`
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/06-release-readiness-and-docs/06-CONTEXT.md`
- `.planning/phases/02-moonbit-public-api/02-CONTEXT.md`
- `.planning/phases/03-js-ts-runtime-surface/03-CONTEXT.md`
- `.planning/phases/04-cli-workflow-parity/04-CONTEXT.md`
- `.planning/phases/05-schema-adapter-packages/05-CONTEXT.md`
- `.github/workflows/release-npm.yml`
- `.github/workflows/release-cli.yml`
- `README.mbt.md`
- `ts/jqx/README.md`
- `ts/zod-adapter/README.md`
- `ts/yup-adapter/README.md`
- `ts/valibot-adapter/README.md`
- `moon.mod.json`
- `pkg.generated.mbti`
- `ts/jqx/package.json`
- `scripts/ts_packages.mjs`
- `scripts/ts_package_build.mjs`

### Secondary (HIGH confidence local verification)
- local shell verification in this checkout: `node ./scripts/ts_packages.mjs list` returned `ts/adapter-core`, `ts/zod-adapter`, `ts/yup-adapter`, `ts/valibot-adapter`, `ts/jqx`
- local shell verification in this checkout: `moon package --list --manifest-path moon.mod.json` passed and listed the current MoonBit publish bundle
- local shell verification in this checkout: `moon publish --dry-run --manifest-path moon.mod.json` failed because no local MoonBit credentials file exists yet
</sources>

<metadata>
## Metadata

**Research scope:**
- npm and CLI release workflow proof paths
- MoonBit package metadata and package-content readiness
- root README drift against JS/TS and MoonBit canonical surfaces
- release-audit evidence requirements

**Confidence breakdown:**
- npm workflow gap assessment: HIGH
- CLI dry-run gap assessment: HIGH
- root README drift assessment: HIGH
- MoonBit publish bundle readiness assessment: MEDIUM-HIGH

**Research date:** 2026-03-20
**Valid until:** 2026-04-19
</metadata>

---

*Phase: 06-release-readiness-and-docs*
*Research completed: 2026-03-20*
*Ready for planning: yes*
