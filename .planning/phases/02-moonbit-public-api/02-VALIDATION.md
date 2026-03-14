---
phase: 2
slug: moonbit-public-api
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-14
---

# Phase 2 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MoonBit toolchain (`moon info`, `moon fmt`, `moon check`, `moon test`) |
| **Config file** | `moon.mod.json` |
| **Quick run command** | `moon check -d && moon test` |
| **Full suite command** | `moon info && moon fmt --check && moon check -d && moon test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `moon check -d && moon test`
- **After every plan wave:** Run `moon info && moon fmt --check && moon check -d && moon test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | ARCH-02, MBT-01, MBT-05 | public-surface | `moon info && moon check -d` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | MBT-01 | docs+surface | `moon check -d` | ✅ | ⬜ pending |
| 02-01-03 | 01 | 1 | MBT-01 | top-level tests | `moon test` | ✅ | ⬜ pending |
| 02-02-01 | 02 | 2 | MBT-02, MBT-03 | API-shape | `moon check -d` | ✅ | ⬜ pending |
| 02-02-02 | 02 | 2 | MBT-02, MBT-03 | compiled-lane tests | `moon test` | ✅ | ⬜ pending |
| 02-02-03 | 02 | 2 | MBT-02, MBT-03 | docs+tests | `moon check -d && moon test` | ✅ | ⬜ pending |
| 02-03-01 | 03 | 3 | ARCH-02, MBT-04, MBT-05 | error-contract | `moon info && moon check -d && moon test` | ✅ | ⬜ pending |
| 02-03-02 | 03 | 3 | MBT-04 | boundary-shape | `moon check -d` | ✅ | ⬜ pending |
| 02-03-03 | 03 | 3 | ARCH-02, MBT-04, MBT-05 | full gate | `moon info && moon fmt --check && moon check -d && moon test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

The repo already has:
- `jqx_test.mbt` for top-level MoonBit API proof
- `pkg.generated.mbti` generation via `moon info`
- repo-standard MoonBit quality gate commands in the required order

Wave 0 is therefore complete for this phase.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Public `.mbti` contract review | ARCH-02, MBT-05 | Generated API diffs need human judgment to catch accidental leakage, weak naming, or broadening of public contracts | Run `moon info`, inspect `pkg.generated.mbti`, and confirm the normal public surface stays on top-level `Json` and opaque `CompiledFilter` types without exposing core-only shapes |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
