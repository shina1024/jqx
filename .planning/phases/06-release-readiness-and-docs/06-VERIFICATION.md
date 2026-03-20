---
phase: 06-release-readiness-and-docs
verified: 2026-03-20T23:17:24.0559794+09:00
status: passed
score: 5/5 must-haves verified
---

# Phase 06: Release Readiness and Docs Verification Report

**Phase Goal:** Users and maintainers can trust release artifacts and canonical docs across CLI, JS/TS, and MoonBit surfaces.
**Verified:** 2026-03-20T23:17:24.0559794+09:00
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Maintainers can dry-run the npm release workflow and inspect publishable package artifacts before the first public release. | ✓ VERIFIED | `.github/workflows/release-npm.yml` now exposes `dry_run`, keeps `bash ./scripts/ts_packages.sh verify --frozen-lockfile`, runs `pnpm publish --access public --dry-run --no-git-checks`, and uploads an audit artifact after enumerating packages through `scripts/ts_packages.mjs list`. |
| 2 | Maintainers can dry-run the CLI release workflow and inspect packaged `jqx` / `jqx.exe` archives without publishing a GitHub Release. | ✓ VERIFIED | `.github/workflows/release-cli.yml` now accepts `dry_run`, packages `dist/jqx` and `dist/jqx.exe`, uploads the archives with `actions/upload-artifact@v7`, and guards `Publish GitHub Release` with `if: ${{ needs.prepare.outputs.dry_run != 'true' }}`. |
| 3 | The MoonBit package is publication-ready as `shina1024/jqx`, with package contents proven through explicit publish metadata and a documented authenticated dry-run publish path. | ✓ VERIFIED | `moon.mod.json` keeps `name: "shina1024/jqx"` and `readme: "README.mbt.md"`, adds `exclude` entries for `_bundle_tmp` and `_bundle_wasmgc`, `moon package --list --manifest-path moon.mod.json` passes locally without those staging directories, and the release ledger records `moon login` plus `moon publish --dry-run --manifest-path moon.mod.json`. |
| 4 | Users can follow one coherent public doc story across the root README, the JS/TS package README, and the standalone adapter package READMEs. | ✓ VERIFIED | `README.mbt.md` now introduces CLI, MoonBit, and JS/TS in that order; `ts/jqx/README.md` owns detailed runtime and `/bind` guidance; the adapter READMEs keep `createAdapter(runtime).filter(...)` as the primary on-ramp and link back to the runtime docs. |
| 5 | Canonical public names are consistent across the release workflows, MoonBit package story, and JS/TS documentation. | ✓ VERIFIED | Root docs use `moon add shina1024/jqx`, `npm install @shina1024/jqx`, and standalone adapter package names only; `ts/jqx/README.md` keeps `run`, `runJsonText`, `compile`, `bindRuntime`, and `bindQueryRuntime`; the release ledger records `@shina1024/jqx`, `@shina1024/jqx/bind`, and the standalone adapter packages. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.github/workflows/release-npm.yml` | Auditable npm dry-run workflow with package-surface verification | ✓ VERIFIED | Exists and contains `dry_run`, `bash ./scripts/ts_packages.sh verify --frozen-lockfile`, package-list auditing via `scripts/ts_packages.mjs list`, artifact upload, and `pnpm publish --access public --dry-run --no-git-checks`. |
| `.github/workflows/release-cli.yml` | Non-publishing CLI packaging workflow with uploadable archives | ✓ VERIFIED | Exists and contains `dry_run`, `dist/jqx`, `dist/jqx.exe`, `actions/upload-artifact@v7`, and the `Publish GitHub Release` dry-run guard. |
| `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md` | Repository-tracked release ledger for npm, CLI, and MoonBit evidence | ✓ VERIFIED | Exists and records npm package names, `@shina1024/jqx/bind`, CLI asset names such as `jqx-vX.Y.Z-linux.tar.gz`, smoke commands, `shina1024/jqx@0.1.0`, `moon login`, and the expected package exclusions. |
| `moon.mod.json` | MoonBit package identity, published readme binding, and package exclusions | ✓ VERIFIED | Exists and contains `name`, `readme`, `exclude`, and the updated MoonBit-first description. |
| `README.mbt.md` | Canonical root cross-surface docs | ✓ VERIFIED | Exists, is 140 lines long, teaches CLI then MoonBit then JS/TS, and uses only standalone adapter package names. |
| `ts/jqx/README.md` | Detailed JS/TS runtime and `/bind` documentation | ✓ VERIFIED | Exists, is 152 lines long, keeps `runJsonText`, `bindRuntime`, and `bindQueryRuntime`, and links to the root and adapter package docs. |
| `ts/zod-adapter/README.md` | Canonical standalone Zod adapter docs | ✓ VERIFIED | Exists, leads with `createAdapter(runtime).filter(...)`, and links to the runtime and root docs. |
| `ts/yup-adapter/README.md` | Canonical standalone Yup adapter docs | ✓ VERIFIED | Exists, leads with `createAdapter(runtime).filter(...)`, and links to the runtime and root docs. |
| `ts/valibot-adapter/README.md` | Canonical standalone Valibot adapter docs | ✓ VERIFIED | Exists, leads with `createAdapter(runtime).filter(...)`, and links to the runtime and root docs. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `.github/workflows/release-npm.yml` | `scripts/ts_packages.mjs` | npm release proof iterates the repository's canonical publishable package list | WIRED | The workflow calls `node ./scripts/ts_packages.mjs list` in multiple audit and publish steps before producing the npm release evidence. |
| `.github/workflows/release-cli.yml` | `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md` | CLI asset names and smoke commands are recorded in the tracked release ledger | WIRED | The workflow packages Linux, macOS, and Windows archives while the release ledger records the expected asset names and `jqx "." "null"` smoke commands. |
| `moon.mod.json` | `README.mbt.md` | MoonBit metadata publishes the same readme users see on the package surface | WIRED | `moon.mod.json` points `readme` at `README.mbt.md`, and the root README now teaches `moon add shina1024/jqx` plus the canonical `run` / `compile` / `run_json_text` story. |
| `README.mbt.md` | `ts/jqx/README.md` | Root docs introduce the JS/TS runtime while the package README owns detailed runtime and `/bind` guidance | WIRED | The root README stays cross-surface and links readers to `ts/jqx/README.md` for detailed runtime, query, and `/bind` contracts. |
| `README.mbt.md` | adapter READMEs | Root docs keep one representative adapter example while package READMEs own validator-specific detail | WIRED | The root README demonstrates `@shina1024/jqx-zod-adapter`, and each adapter README links back to the runtime README and root overview. |

### Requirements Coverage

| Requirement | Status | Evidence |
| --- | --- | --- |
| `CLI-03` | ✓ SATISFIED | `.github/workflows/release-cli.yml`, `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md`, `README.mbt.md` |
| `MBT-06` | ✓ SATISFIED | `moon.mod.json`, `README.mbt.md`, `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md`, successful `moon package --list --manifest-path moon.mod.json` |
| `REL-01` | ✓ SATISFIED | `.github/workflows/release-npm.yml`, `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md`, successful `bash ./scripts/ts_packages.sh verify --frozen-lockfile` |
| `REL-02` | ✓ SATISFIED | `.github/workflows/release-cli.yml`, `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md` |
| `REL-03` | ✓ SATISFIED | `README.mbt.md`, `ts/jqx/README.md`, `ts/zod-adapter/README.md`, `ts/yup-adapter/README.md`, `ts/valibot-adapter/README.md` |

No orphaned Phase 6 requirements were found. The plan frontmatter, requirements file, summaries, and implemented artifacts all resolve to `CLI-03`, `MBT-06`, `REL-01`, `REL-02`, and `REL-03`.

## Anti-Patterns Found

None found during phase verification.

## Human Verification Required

None for phase-goal verification. The phase goal was to make release rehearsal and publication readiness auditable and repository-tracked; the actual GitHub workflow runs and credentialed `moon publish --dry-run` remain operational maintainer steps rather than missing implementation work.

## Local Environment Notes

- `moon info` passed.
- `moon fmt` passed.
- `moon check` passed.
- `moon test` passed with `328` tests passing.
- `moon package --list --manifest-path moon.mod.json` passed and excluded `_bundle_tmp` and `_bundle_wasmgc`.
- `bash ./scripts/ts_packages.sh verify --frozen-lockfile` passed across `ts/adapter-core`, `ts/jqx`, `ts/zod-adapter`, `ts/yup-adapter`, and `ts/valibot-adapter`.

## Gaps Summary

**No gaps found.** Phase goal achieved. Ready to complete the phase.

## Verification Metadata

**Verification approach:** Goal-backward, derived from the Phase 6 goal and success criteria in `.planning/ROADMAP.md`
**Must-haves source:** Phase 6 success criteria plus requirement mapping in `.planning/ROADMAP.md`
**Automated checks:** 6 passed, 0 failed
**Human checks required:** 0
**Implementation commits reviewed:** `755dae7`, `36902be`, `39fc54f`, `0c3c4b2`, `ef4791a`, `681ad9f`

---
*Verified: 2026-03-20T23:17:24.0559794+09:00*
*Verifier: Codex*
