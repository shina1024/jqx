---
phase: 6
slug: release-readiness-and-docs
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 6 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MoonBit CLI checks, TS package verification, workflow-file inspection, and release-artifact/package-content audit |
| **Config file** | `.github/workflows/release-npm.yml`, `.github/workflows/release-cli.yml`, `moon.mod.json`, `ts/jqx/package.json`, `README.mbt.md`, `ts/jqx/README.md` |
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
| 06-01-01 | 01 | 1 | REL-01 | npm package verification and workflow contract | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | CLI-03, REL-02 | native build smoke and CLI packaging contract | `moon build --target native --release cmd` | ✅ | ⬜ pending |
| 06-02-01 | 02 | 2 | MBT-06 | MoonBit package-content audit | `moon package --list --manifest-path moon.mod.json` | ✅ | ⬜ pending |
| 06-02-02 | 02 | 2 | MBT-06 | authenticated MoonBit publish preflight | `moon publish --dry-run --manifest-path moon.mod.json` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 3 | REL-03 | cross-surface canonical-name presence check | `rg "run_json_text|runJsonText|bindRuntime|@shina1024/jqx-zod-adapter|@shina1024/jqx-yup-adapter|@shina1024/jqx-valibot-adapter" README.mbt.md ts/jqx/README.md ts/zod-adapter/README.md ts/yup-adapter/README.md ts/valibot-adapter/README.md` | ✅ | ⬜ pending |
| 06-03-02 | 03 | 3 | REL-03 | root README drift regression check | `rg "@shina1024/jqx/(zod|yup|valibot)|MoonBit package on `mooncakes.io`: planned" README.mbt.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] Add a non-publishing or draft-only CLI packaging path so `REL-02` can be verified without creating a public GitHub Release
- [ ] Choose and create the repository-tracked Phase 6 release audit document that records npm, CLI, and MoonBit evidence
- [ ] Provide MoonBit credentials via `moon login` before treating `moon publish --dry-run --manifest-path moon.mod.json` as a required green check
- [ ] Audit the current MoonBit package bundle and decide whether `_bundle_tmp` and `_bundle_wasmgc` are acceptable published contents

Current local finding:
- `node ./scripts/ts_packages.mjs list` reports the five publishable TS package directories
- `moon package --list --manifest-path moon.mod.json` passes and currently packages `_bundle_tmp` and `_bundle_wasmgc`
- `moon publish --dry-run --manifest-path moon.mod.json` fails locally because credentials are not configured

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| npm dry-run evidence proves each package's shipped artifact surface, not only workflow success | REL-01 | The maintainer must review the actual dry-run output, export maps, and consumer smoke results and capture them in the audit document | Trigger `release-npm.yml` with `workflow_dispatch` and `dry_run=true`; inspect each package's `dist/` contents, confirm package names/versions, and record the audit in the Phase 6 release document |
| CLI release artifacts can be inspected before publication and contain `jqx` / `jqx.exe` inside the archive | CLI-03, REL-02 | Cross-OS archive naming and extraction behavior cannot be fully proven from source edits alone | Run the non-publishing CLI packaging path for Linux/macOS/Windows, inspect archive contents, extract each artifact, and smoke-run `jqx "." "null"` or `jqx.exe "." "null"` |
| MoonBit public story is first-class and no longer tentative in the root README | MBT-06, REL-03 | Example ordering and confidence level require human review | Review `README.mbt.md`; confirm install order is CLI, MoonBit, JS/TS, MoonBit is not described as "planned", and examples match `pkg.generated.mbti` canonical names |
| Root README keeps only one short adapter example and routes detail to package READMEs | REL-03 | This is a narrative-quality check, not only a grep target | Review `README.mbt.md`, `ts/jqx/README.md`, and the adapter READMEs; confirm root README is concise and package READMEs remain the detailed owners |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 420s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
