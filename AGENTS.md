# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Doc Policy (Repository)

- CLI/Library user-facing documentation lives in `README.mbt.md`.
- `README.mbt.md` is distribution/usage-first (executable + npm). Keep source build/test internals out.
- Development guidance and maintenance policy lives in this file (`AGENTS.md`).
- Active work items and checklists live in `agent-todo.md`.
- Keep `docs/` lightweight; do not duplicate long-lived guidance there.

Distribution channels policy:
- Primary: executable (`jqx`) and npm package (`@shina1024/jqx`).
- Secondary: MoonBit package registration on `mooncakes.io` (planned).

## Project Structure

- MoonBit packages are organized per directory with `moon.pkg.json`.
- Package tests:
  - blackbox: `*_test.mbt`
  - whitebox: `*_wbtest.mbt`
- Module metadata is in `moon.mod.json`.

Current package split:
- `core/`: parser/evaluator shared by CLI and JS/TS paths
- `cmd/`: native CLI
- `js/`: MoonBit JS-facing minimal API
- `ts/jqx`: npm-facing JS/TS entrypoint (`@shina1024/jqx`, `@shina1024/jqx/zod`, `@shina1024/jqx/yup`, `@shina1024/jqx/valibot`)
- `ts/adapter-core`: shared runtime/result/inference helpers
- `ts/zod-adapter`, `ts/yup-adapter`, `ts/valibot-adapter`: schema adapters

## Coding Convention

- MoonBit code uses block style separated by `///|`.
- Block order is irrelevant; refactors can be done block-by-block.
- Keep deprecated blocks in `deprecated.mbt` when needed.

## Tooling

Core commands:
- `moon fmt`
- `moon info`
- `moon check`
- `moon test`
- `moon test --update` (snapshot updates)
- `moon coverage analyze > uncovered.log`

Quality gate for code changes:
1. `moon info`
2. `moon fmt`
3. `moon check`
4. `moon test`

When public APIs change, inspect generated `.mbti` diffs carefully.

## Compatibility Policy

- Target behavior: jq 1.7 semantics.
- Differential baseline in this repo: jq 1.8.1.
- Keep strict compatibility checks.
  - Do not widen skips casually.
  - Do not weaken error/output comparison rules as a shortcut.
- Temporary exceptions must be explicit and removable.

## Current Baseline (2026-03-03)

- `moon test`: 256/256 pass
- `moon test --target native --package core`: 196/196 pass
- differential smoke (`scripts/jq_compat_cases.json`): 242/242 pass
- differential upstream full (`scripts/jq_compat_cases.upstream.json`): 843/843 pass, skipped 0
- compile-fail error checks: strict-only (`expect_error_mode: any` は 0 件)

## Known Compatibility Gaps (High-level)

- Differential corpus 内では既知の機能差分はなし。
- locale 依存の `%A`/`%B` は native で C `strftime` を使用し、jq と同じ環境依存系に揃える。
- 理論上の完全互換に向けては、timezone 差分と将来 upstream 追加ケースの継続監視を行う。

## JSON Parser First: Design Notes

- 最優先は JSON パーサー。
- CLI/JS/TS で同一コア API を使う。
- jq evaluator にそのまま接続できる JSON 値モデルを維持する。
- Object キー順は入力/更新順維持を基本とする。

### Core Data Model

- `Null`, `Bool`, `Number`, `String`, `Array`, `Object`
- `Number` は jq 互換と JS 制約を踏まえて運用

### Parser API (Core)

- `parse_json(text: String) -> Result[Json, JsonError]`
- `JsonError` includes `line`, `column`, `offset`, `message`

## JS/TS Strategy

Two-lane approach:
- Dynamic lane: jq string compatibility API
- Query lane: `Query[I, O]`-style DSL/AST API

Guidelines:
- jq string inference is partial and conservative.
- Non-inferable syntax falls back to `unknown` or `Json`.
- Prefer query DSL for strong static guarantees.

## Refactoring Policy (Maintainability)

- Prioritize behavior-preserving splits.
- Avoid mixing structural refactor and feature change in one commit.
- Keep source/test mapping explicit.

Current core layout intent:
- Parser responsibilities: `parser_cursor`, `parser_atom`, `parser_expr`, `parser_lowering`
- Evaluator responsibilities: `execute`, `json_ops`, `path_ops`, `collection_ops`
- Builtin dispatch responsibilities: `builtin_path`, `builtin_string`, `builtin_collection`, `builtin_numeric`, `builtin_stream`

Test naming policy:
- Single-source primary tests: `<source_stem>_test.mbt`
- Cross-cut execute suites: `execute_<topic>_test.mbt`
- Test helpers: `<domain>_test_support_test.mbt`
- Put `Source under test` header comments at test file tops.

## Performance Policy

Goal:
- Reduce runtime overhead while preserving jq compatibility.

Priority themes:
1. Algorithmic wins first (e.g., avoid `O(n^2)` hot paths).
2. Reuse/caching for expensive repeated work (e.g., regex compile cache).
3. Reduce environment/binding copies in evaluation hot paths.
4. Improve string construction strategy in heavy text operations.

Potential breaking candidates (evaluate carefully before adoption):
- Move from copy-heavy env maps to frame-chain environments.
- Move from eager result arrays to stream-first execution model.

## Differential and CI Workflow

Differential scripts:
- Smoke: `scripts/jq_diff.ps1`, `scripts/jq_diff.sh`
- Upstream full: `scripts/jq_diff.ps1 -CasesPath scripts/jq_compat_cases.upstream.json`
- Native `-e`: `scripts/jq_diff_native.ps1`, `scripts/jq_diff_native.sh`

Upstream fixture update/import:
- `scripts/update_jq_tests.ps1`, `scripts/update_jq_tests.sh`
- `scripts/jq_upstream_import.ps1`, `scripts/jq_upstream_import.sh`
- `scripts/jq_upstream_ledger.ps1`, `scripts/jq_upstream_ledger.sh`
  - updates `scripts/jq_upstream_failures.snapshot.json`
  - generates `scripts/jq_upstream_diff_ledger.md` (new fail / resolved fail / behavior changes)

CI (`.github/workflows/ci.yml`):
- Linux/macOS/Windows MoonBit check+tests
- Linux TS lint/typecheck/test/build (`adapter-core`, adapters, `ts/jqx`)
- Linux differential smoke/upstream/native-exit
- Linux coverage analyze + summary + artifact

Nightly differential (`.github/workflows/differential-nightly.yml`):
- cross-OS full differential + native-exit (`schedule` + `workflow_dispatch`)
- on failure, auto-open/update GitHub issue: `[CI] Differential Nightly failed`
- on recovery, auto-comment and close the above issue

Nightly operation checklist (`workflow_dispatch`):
1. Trigger `Differential Nightly` on `main`.
2. Confirm all `differential-full` matrix jobs are `success` and `nightly-status` is `success`.
3. Confirm no open issue titled `[CI] Differential Nightly failed` remains.
4. If a failure issue existed, confirm recovery comment + close were posted by the same run.
5. Record run URL/date in `agent-todo.md` when closing an operational task.

Release workflow:
- `.github/workflows/release-cli.yml`
- `v*` tag push (or manual dispatch with tag) builds native CLI artifacts for Linux/macOS/Windows and uploads them to GitHub Releases.

## Build (Native)

### Windows

- Requires Visual Studio Build Tools + Windows SDK
- Use Developer PowerShell for VS
- Example:
  - `moon test --target native --package core`
  - `moon run --target native cmd -- ".foo" '{"foo": 1}'`

### macOS

- Requires Xcode Command Line Tools
- Example:
  - `moon test --target native --package core`
  - `moon run --target native cmd -- ".foo" '{"foo": 1}'`

### Linux

- Requires gcc/clang toolchain
- Example:
  - `moon test --target native --package core`
  - `moon run --target native cmd -- ".foo" '{"foo": 1}'`

## Working Queue

- Use `agent-todo.md` as the single actionable queue.
- Keep completed items checked with clear scope notes.
