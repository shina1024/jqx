# Project Guide

This repository targets jq-compatible behavior.

## Compatibility

- Compatibility checks in this repo run against jq 1.8.1.
- If jq-version-specific behavior matters, make the intended version or exception explicit in code, tests, or docs.
- Do not widen skips casually or weaken error/output comparison as a shortcut.
- Temporary compatibility exceptions must be explicit and removable.
- Preserve the shared JSON value model across CLI/JS/TS, including object key input/update order.

## Internal Layout

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
