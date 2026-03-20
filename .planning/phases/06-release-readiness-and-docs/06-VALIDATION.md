---
phase: 6
slug: release-readiness-and-docs
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-20
---

# Phase 6 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MoonBit CLI checks, TS package verification, workflow-file inspection, and release-artifact/package-content audit |
| **Config file** | `.github/workflows/release-npm.yml`, `.github/workflows/release-cli.yml`, `moon.mod.json`, `ts/jqx/package.json`, `README.mbt.md`, `ts/jqx/README.md`, `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md` |
| **Quick run command** | `moon info && moon check` |
| **Full suite command** | `moon info && moon fmt && moon check && moon test && bash ./scripts/ts_packages.sh verify --frozen-lockfile && moon package --list --manifest-path moon.mod.json` |
| **Estimated runtime** | ~420 seconds |

---

## Sampling Rate

- **After every task commit:** Run the smallest relevant command for the touched surface (`moon info && moon check`, `bash ./scripts/ts_packages.sh verify --frozen-lockfile`, or `moon package --list --manifest-path moon.mod.json`)
- **After every plan wave:** Run `moon info && moon fmt && moon check && moon test && bash ./scripts/ts_packages.sh verify --frozen-lockfile && moon package --list --manifest-path moon.mod.json`
- **Before `$gsd-verify-work`:** Full suite must be green and release-audit evidence must be present
- **Max feedback latency:** 420 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | REL-01 | npm package verification and workflow contract | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ✅ | ✅ green |
| 06-01-02 | 01 | 1 | CLI-03, REL-02 | native build smoke and CLI packaging contract | `moon build --target native --release cmd` | ✅ | ✅ green |
| 06-02-01 | 02 | 2 | MBT-06 | MoonBit package-content audit | `moon package --list --manifest-path moon.mod.json` | ✅ | ✅ green |
| 06-02-02 | 02 | 2 | MBT-06 | authenticated MoonBit publish preflight procedure | `moon login && moon publish --dry-run --manifest-path moon.mod.json` | ✅ | ✅ green |
| 06-03-01 | 03 | 3 | REL-03 | cross-surface canonical-name presence check | `rg "run_json_text|runJsonText|bindRuntime|@shina1024/jqx-zod-adapter|@shina1024/jqx-yup-adapter|@shina1024/jqx-valibot-adapter" README.mbt.md ts/jqx/README.md ts/zod-adapter/README.md ts/yup-adapter/README.md ts/valibot-adapter/README.md` | ✅ | ✅ green |
| 06-03-02 | 03 | 3 | REL-03 | root README drift regression check | `rg "@shina1024/jqx/(zod|yup|valibot)|MoonBit package on `mooncakes.io`: planned" README.mbt.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

Already present and locally verified:
- `.github/workflows/release-npm.yml` exposes `dry_run`, keeps `bash ./scripts/ts_packages.sh verify --frozen-lockfile`, and records publishable package evidence through `scripts/ts_packages.mjs list`.
- `.github/workflows/release-cli.yml` exposes `dry_run`, packages `dist/jqx` and `dist/jqx.exe`, uploads archives, and skips public release publication when `dry_run=true`.
- `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md` records npm, CLI, and MoonBit release evidence in the repository.
- `moon.mod.json` excludes `_bundle_tmp` and `_bundle_wasmgc`, and `moon package --list --manifest-path moon.mod.json` passes without those staging directories.
- The authenticated MoonBit publish preflight is documented as `moon login && moon publish --dry-run --manifest-path moon.mod.json` in the tracked audit ledger.

Wave 0 is complete for this phase because the missing release audit document, non-publishing workflow paths, package exclusions, and MoonBit publish-preflight procedure are now present in the repository. The remaining authenticated publish step is an operational maintainer action, not missing validation infrastructure.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| npm dry-run evidence proves each package's shipped artifact surface, not only workflow success | REL-01 | The maintainer must review the actual dry-run output, export maps, and consumer smoke results and capture them in the audit document | Trigger `release-npm.yml` with `workflow_dispatch` and `dry_run=true`; inspect each package's `dist/` contents, confirm package names/versions, and record the audit in the Phase 6 release document |
| CLI release artifacts can be inspected before publication and contain `jqx` / `jqx.exe` inside the archive | CLI-03, REL-02 | Cross-OS archive naming and extraction behavior cannot be fully proven from source edits alone | Run the non-publishing CLI packaging path for Linux/macOS/Windows, inspect archive contents, extract each artifact, and smoke-run `jqx "." "null"` or `jqx.exe "." "null"` |
| Authenticated MoonBit publish preflight remains an operational maintainer gate | MBT-06 | The documented dry-run publish path requires credentials and cannot be verified anonymously in every local environment | Run `moon login`, then `moon publish --dry-run --manifest-path moon.mod.json`, and record the result in `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md` |
| MoonBit public story is first-class and no longer tentative in the root README | MBT-06, REL-03 | Example ordering and confidence level require human review | Review `README.mbt.md`; confirm install order is CLI, MoonBit, JS/TS, MoonBit is not described as "planned", and examples match `pkg.generated.mbti` canonical names |
| Root README keeps only one short adapter example and routes detail to package READMEs | REL-03 | This is a narrative-quality check, not only a grep target | Review `README.mbt.md`, `ts/jqx/README.md`, and the adapter READMEs; confirm root README is concise and package READMEs remain the detailed owners |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 420s
- [x] `nyquist_compliant: true` set in frontmatter

Approval: approved
