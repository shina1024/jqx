---
phase: 7
slug: nyquist-validation-completion
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-20
---

# Phase 7 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Existing phase verification reports plus repo-standard MoonBit, CLI differential, TS package, and package-content gates |
| **Config file** | `.planning/phases/03-js-ts-runtime-surface/03-VALIDATION.md`, `.planning/phases/04-cli-workflow-parity/04-VALIDATION.md`, `.planning/phases/05-schema-adapter-packages/05-VALIDATION.md`, `.planning/phases/06-release-readiness-and-docs/06-VALIDATION.md`, `.planning/v1.0-MILESTONE-AUDIT.md` |
| **Quick run command** | `rg "status: complete|nyquist_compliant: true|Approval: approved" .planning/phases/03-js-ts-runtime-surface/03-VALIDATION.md .planning/phases/04-cli-workflow-parity/04-VALIDATION.md .planning/phases/05-schema-adapter-packages/05-VALIDATION.md .planning/phases/06-release-readiness-and-docs/06-VALIDATION.md` |
| **Full suite command** | `moon info && moon fmt && moon check && moon test && node scripts/jq_diff.mjs && node scripts/jq_diff.mjs scripts/jq_exit_cases.json && bash ./scripts/ts_packages.sh verify --frozen-lockfile && moon package --list --manifest-path moon.mod.json` |
| **Estimated runtime** | ~600 seconds |

---

## Sampling Rate

- **After every task commit:** Run the smallest relevant phase gate for the touched validation artifact.
- **After every plan wave:** Run the full suite command plus a grep pass over updated validation and audit docs.
- **Before `$gsd-verify-work`:** Full suite must be green and all targeted validation docs must show approved sign-off.
- **Max feedback latency:** 600 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | None | phase-03 validation reconciliation | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ✅ | ✅ green |
| 07-01-02 | 01 | 1 | None | phase-05 validation reconciliation | `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | ✅ | ✅ green |
| 07-02-01 | 02 | 1 | None | phase-04 validation reconciliation | `moon info && moon fmt && moon check && moon test && node scripts/jq_diff.mjs && node scripts/jq_diff.mjs scripts/jq_exit_cases.json` | ✅ | ✅ green |
| 07-02-02 | 02 | 1 | None | phase-06 validation reconciliation | `moon info && moon fmt && moon check && moon test && bash ./scripts/ts_packages.sh verify --frozen-lockfile && moon package --list --manifest-path moon.mod.json` | ✅ | ✅ green |
| 07-03-01 | 03 | 2 | None | phase-07 validation and verification closeout | `rg "status: complete|nyquist_compliant: true|Approval: approved" .planning/phases/03-js-ts-runtime-surface/03-VALIDATION.md .planning/phases/04-cli-workflow-parity/04-VALIDATION.md .planning/phases/05-schema-adapter-packages/05-VALIDATION.md .planning/phases/06-release-readiness-and-docs/06-VALIDATION.md .planning/phases/07-nyquist-validation-completion/07-VALIDATION.md` | ✅ | ✅ green |
| 07-03-02 | 03 | 2 | None | milestone audit refresh | `rg "status: passed|overall: complete|partial_phases: \\[\\]|tech_debt: \\[\\]" .planning/v1.0-MILESTONE-AUDIT.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

Already present and reused:
- Phase 03 to 06 validation artifacts
- Phase 03 to 06 verification reports
- `.planning/phases/06-release-readiness-and-docs/06-RELEASE-AUDIT.md`
- `moon info`, `moon fmt`, `moon check`, and `moon test`
- `node scripts/jq_diff.mjs` and `node scripts/jq_diff.mjs scripts/jq_exit_cases.json`
- `bash ./scripts/ts_packages.sh verify --frozen-lockfile`
- `moon package --list --manifest-path moon.mod.json`

Wave 0 is complete for this phase because the work is retrospective validation reconciliation and milestone closeout tracking, not new product-surface coverage or new test harness creation.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Updated validation docs stay honest about manual versus automated proof | None | Human review is needed to ensure operational maintainer steps such as authenticated `moon publish --dry-run` stay documented as manual prerequisites instead of being silently reclassified as local automated proof | Review the updated Phase 03 to 06 validation artifacts and confirm each manual-only section matches the corresponding verification report and current repository evidence |
| The refreshed milestone audit reads as debt closure rather than new product work | None | Audit wording can overclaim scope even when the underlying files are correct | Review `.planning/v1.0-MILESTONE-AUDIT.md` and `.planning/phases/07-nyquist-validation-completion/07-VERIFICATION.md`; confirm the phase closes validation debt only and does not claim new user-facing behavior |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or truthful manual-only proof
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all required preconditions
- [x] No watch-mode flags
- [x] Feedback latency < 600s
- [x] `nyquist_compliant: true` set in frontmatter

Approval: approved
