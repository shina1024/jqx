# Project Guide

This repository targets jq-compatible behavior.

## Compatibility

- Compatibility checks in this repo run against jq 1.8.1.
- If jq-version-specific behavior matters, make the intended version or exception explicit in code, tests, or docs.
- Do not widen skips casually or weaken error/output comparison as a shortcut.
- Temporary compatibility exceptions must be explicit and removable.
- Preserve the shared JSON value model across CLI/JS/TS, including object key input/update order.

## MoonBit Public API

- `shina1024/jqx` top-level package is intended to become the primary MoonBit public API and the basis for `mooncakes.io` publication.
- Before `1.0`, prioritize a coherent long-term public API over preserving the current thin wrapper or early cross-surface API shapes. Breaking changes are acceptable when they reduce long-term API debt.
- Keep `shina1024/jqx/core` as the lower-level jq-compatible engine. It may keep internal `Json` / `Filter` representations needed for jq semantics, evaluation internals, and numeric repr preservation.
- Do not use `@core.Value` as the primary MoonBit user boundary. MoonBit-facing APIs should prefer the standard `Json` type from `moonbitlang/core/json`.
- Add explicit conversion helpers between standard `Json` and `@core.Value`. Treat conversion through standard `Json` as the convenience lane; jq-specific numeric repr fidelity is preserved by text-based compatibility lanes, not by `Json` round-trips.
- Public MoonBit APIs should expose two lanes:
  - value lane: accept and return standard `Json` for embedding in MoonBit applications
  - compatibility lane: accept and return JSON text (`StringView` / `String`) when jq-style fidelity matters
- For compiled execution, prefer a public compiled-filter abstraction over asking MoonBit users to depend on `@core.Filter` directly. `@core.Filter` can remain an implementation detail unless a strong reason appears.
- Do not block MoonBit public package publication on a typed query DSL. First prioritize string-filter execution, compiled execution, JSON conversion, and clear public errors; query DSL can follow later.
- Do not advertise `mooncakes.io` as an active channel until top-level public APIs and examples are MoonBit-user-facing and no longer tell users to import `core` directly.

## Internal Layout

- Surface split:
  - `shina1024/jqx`: top-level public package for MoonBit users
  - `shina1024/jqx/core`: jq-compatible engine package
  - `shina1024/jqx/cmd`: native CLI package
  - `shina1024/jqx/js`: JS-target-facing MoonBit package used by JS/TS bindings
  - `ts/*`: npm packaging and adapter workspace; canonical JS/TS user-facing package names live here, not in the MoonBit package path
- Naming judgment:
  - `core` is appropriate for the lower-level engine package
  - `cmd` is appropriate for the CLI package
  - `js` is acceptable as a repo-internal package name, but it is not the canonical end-user JS/TS package surface; keep that distinction clear in docs
- Parser responsibilities: `parser_cursor`, `parser_atom`, `parser_expr`, `parser_lowering`
- Evaluator responsibilities: `execute`, `json_ops`, `path_ops`, `collection_ops`
- Builtin dispatch responsibilities: `builtin_path`, `builtin_string`, `builtin_collection`, `builtin_numeric`, `builtin_stream`
- Test naming:
  - single-source primary tests: `<source_stem>_test.mbt`
  - cross-cut execute suites: `execute_<topic>_test.mbt`
  - helpers: `<domain>_test_support_test.mbt`
  - add `Source under test` header comments at test file tops

## Validation

- Run the quality gate for code changes in this order: `moon info`, `moon fmt`, `moon check`, `moon test`
- When public APIs change, inspect generated `.mbti` diffs carefully.
- If local `file:` TS dependencies change, refresh packages in dependency order:
  - Windows: `./scripts/ts_packages.ps1 refresh`
  - Linux/macOS: `bash ./scripts/ts_packages.sh refresh`
- CI-equivalent TS verification: `bash ./scripts/ts_packages.sh verify --frozen-lockfile`
