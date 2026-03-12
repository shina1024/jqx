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
| **Quick run command** | `moon check -d && moon test --target native core && moon test --target native cmd` |
| **Full suite command** | `moon info && moon fmt --check && moon check -d && moon test --target native core && moon test --target native cmd && moon test --target js js && bash ./scripts/ts_packages.sh verify --frozen-lockfile && bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json && bash ./scripts/jq_diff_native.sh` |
| **Estimated runtime** | ~300 seconds |

---

## Sampling Rate

- **After every task commit:** Run `moon check -d && moon test --target native core && moon test --target native cmd`
- **After every plan wave:** Run `moon info && moon fmt --check && moon check -d && moon test --target native core && moon test --target native cmd && moon test --target js js && bash ./scripts/ts_packages.sh verify --frozen-lockfile && bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json && bash ./scripts/jq_diff_native.sh`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 300 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | COMP-01, COMP-02 | differential | `bash ./scripts/jq_diff.sh && bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json` | ✅ | ⬜ pending |
| 01-02-01 | 02 | 1 | ARCH-01, ARCH-03, ARCH-04 | unit/integration | `moon check -d && moon test --target native core && moon test --target native cmd` | ✅ | ⬜ pending |
| 01-03-01 | 03 | 2 | COMP-03, COMP-04 | cross-surface | `moon test --target js js && bash ./scripts/jq_diff_native.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 300s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
