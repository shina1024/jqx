---
phase: 4
slug: cli-workflow-parity
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-20
---

# Phase 4 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MoonBit wbtests plus maintained jq differential proof |
| **Config file** | `cmd/moon.pkg`, `.planning/REQUIREMENTS.md`, `scripts/jq_compat_cases.json` |
| **Quick run command** | `moon test cmd` |
| **Full suite command** | `moon info && moon fmt && moon check && moon test && node scripts/jq_diff.mjs` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run `moon test cmd`
- **After every plan wave:** Run `moon info && moon fmt && moon check && moon test && node scripts/jq_diff.mjs`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | CLI-01 | jqx-first help and docs contract | `moon test cmd` | ✅ | ⬜ pending |
| 04-01-02 | 01 | 1 | CLI-01 | focused CLI workflow and output regressions | `moon test cmd` | ✅ | ⬜ pending |
| 04-02-01 | 02 | 2 | CLI-01, CLI-02 | maintained jq CLI corpus expansion | `node scripts/jq_diff.mjs && node scripts/jq_diff.mjs scripts/jq_exit_cases.json` | ✅ | ⬜ pending |
| 04-02-02 | 02 | 2 | CLI-01, CLI-02 | fast and native parity proof alignment | `moon test cmd && node scripts/jq_diff.mjs && node scripts/jq_diff.mjs scripts/jq_exit_cases.json` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

Already present and locally verified:
- `cmd/args_wbtest.mbt` for CLI argument parsing
- `cmd/main_wbtest.mbt` for CLI workflow, error ordering, and exit-status behavior
- `cmd/main_native_wbtest.mbt` for native-only module-path proof
- `cmd/output_wbtest.mbt` for raw-output formatting
- `scripts/jq_compat_cases.json` for maintained jq CLI parity cases
- `scripts/jq_diff.mjs` for native maintained differential proof

Wave 0 expectation for execution:
- Reuse the existing infrastructure rather than creating a new CLI harness.
- Add targeted cases only where Phase 4 tightens the public CLI contract or closes under-specified user-visible behavior.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Help text and README both present `jqx` as the canonical user-facing command | CLI-01 | The exact wording and prominence of command identity need human review even if automated tests are green | Review `cmd/main_cli.mbt` and `README.mbt.md`; confirm usage and examples are `jqx`-first and that contributor-only `moon run` wording is not the public default |
| CLI transport work still delegates semantics through the shared core | CLI-01, CLI-02 | Human review is needed to confirm execution flow did not drift into surface-local semantic patches | Review `cmd/main.mbt` and `cmd/main_cli.mbt`; confirm the CLI still compiles via `@lib.compile(...)` and executes via `@lib.execute_for_cli(...)` rather than wrapper-local semantic branches |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
