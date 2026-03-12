---
phase: 1
slug: shared-core-and-compatibility
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-12
---

# Phase 1 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MoonBit test runner + bash differential harness + GitHub Actions |
| **Config file** | `moon.mod.json`, `.github/workflows/ci.yml`, `scripts/jq_compat_cases*.json` |
| **Quick run command** | `moon check -d && moon test && bash ./scripts/jq_diff.sh` |
| **Full suite command** | `moon info && moon fmt --check && moon check -d && moon test && moon test --target js js && bash ./scripts/ts_packages.sh verify --frozen-lockfile && bash ./scripts/jq_upstream_ledger.sh --verify && bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json && bash ./scripts/jq_diff_native.sh` |
| **Estimated runtime** | ~300 seconds |

---

## Sampling Rate

- **After every task commit:** Run the task's own `<verify>` command, plus `moon check -d` when MoonBit code changed.
- **After every plan wave:** Run `moon info && moon fmt --check && moon check -d && moon test && moon test --target js js && bash ./scripts/ts_packages.sh verify --frozen-lockfile && bash ./scripts/jq_upstream_ledger.sh --verify && bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json && bash ./scripts/jq_diff_native.sh`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 300 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | COMP-01, COMP-02 | differential/import | `bash ./scripts/jq_upstream_ledger.sh --verify && bash ./scripts/jq_upstream_import.sh && git diff --exit-code -- scripts/jq_compat_cases.upstream.json` | ✅ | ⬜ pending |
| 01-01-02 | 01 | 1 | COMP-01, COMP-02 | differential | `bash ./scripts/jq_diff.sh` | ✅ | ⬜ pending |
| 01-01-03 | 01 | 1 | COMP-01, COMP-02 | differential/doc | `bash ./scripts/jq_upstream_ledger.sh --verify && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json` | ✅ | ⬜ pending |
| 01-02-01 | 02 | 2 | ARCH-01, ARCH-03, ARCH-04 | architecture+oracle | `moon check -d && bash ./scripts/jq_diff.sh` | ✅ | ⬜ pending |
| 01-02-02 | 02 | 2 | ARCH-01, ARCH-03, ARCH-04 | unit+oracle | `moon test && bash ./scripts/jq_diff.sh` | ✅ | ⬜ pending |
| 01-02-03 | 02 | 2 | ARCH-01, ARCH-03, ARCH-04 | cross-surface+oracle | `moon test && moon test --target js js && bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff_native.sh` | ✅ | ⬜ pending |
| 01-03-01 | 03 | 3 | COMP-03, COMP-04 | cross-surface fidelity | `moon test && moon test --target js js` | ✅ | ⬜ pending |
| 01-03-02 | 03 | 3 | COMP-03, COMP-04 | differential | `bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json && bash ./scripts/jq_diff_native.sh` | ✅ | ⬜ pending |
| 01-03-03 | 03 | 3 | COMP-03, COMP-04 | full gate | `moon info && moon fmt --check && moon check -d && moon test && moon test --target js js && bash ./scripts/ts_packages.sh verify --frozen-lockfile && bash ./scripts/jq_upstream_ledger.sh --verify && bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json && bash ./scripts/jq_diff_native.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure provides a starting oracle and targeted tests, but it does not yet fully prove Phase 1:

- `scripts/jq_diff*.sh` and existing compat corpora already provide the jq oracle baseline for `COMP-01` and `COMP-02`.
- Shared-ledger coverage verification is intentionally added by Plan 01 via `scripts/jq_upstream_ledger.sh --verify`; it is not fully present before execution starts.
- Current MoonBit/JS tests do not yet fully prove `COMP-03` and `COMP-04` through the MoonBit top-level API, JS wrapper, and CLI-facing differential path together.
- Current CI exists, but Plan 03 is responsible for reshaping it into the final Phase 1 gate.

Wave 0 is therefore intentionally incomplete; Plans 01 and 03 close the missing proof.

---

## Manual-Only Verifications

No phase-exit requirement is intended to remain manual-only. Human review still interprets whether documented jq differences are acceptable, but the phase adds automated proof that case metadata, the shared ledger, and differential outputs stay aligned.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 gaps are explicitly documented
- [x] No watch-mode flags
- [x] Feedback latency < 300s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
