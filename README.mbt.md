# shina1024/jqx

jqx is a jq-compatible tool (work in progress) written in MoonBit.

## Build (Native)

### Windows

Prerequisites:
- Visual Studio Build Tools (C++ build tools)
- Windows 10/11 SDK

Recommended shell:
- Use **Developer PowerShell for VS** (it sets `INCLUDE`/`LIB`/`PATH`).

Commands:
```powershell
moon test --target native --package core
moon run --target native cmd -- ".foo" '{"foo": 1}'
```

Build executable:
```powershell
moon build --target native cmd
```
The executable will be placed under `_build/native/release`. Look for `jqx.exe`
(or the most recently updated `.exe`) and run it directly.

### macOS

Prerequisites:
- Xcode Command Line Tools

Commands:
```bash
moon test --target native --package core
moon run --target native cmd -- ".foo" '{"foo": 1}'
```

Options:
```bash
# Raw string output (no JSON quotes)
moon run --target native cmd -- -r ".foo" '{"foo": "bar"}'

# Null input (ignore stdin/arg)
moon run --target native cmd -- -n "."

# Slurp input values into one array (minimal NDJSON-style support)
moon run --target native cmd -- -s "." "1"

# Exit status by result truthiness (jq -e style)
moon run --target native cmd -- -e ".ok" '{"ok": false}'
```

## Filters (Current)

- Basic: `.`, `.foo`, `.[0]`, `.[]`
- Optional: `.foo?`, `.[0]?`, `.[]?`
- Try: `expr?` (errors produce empty output)
- Try/Catch: `try expr catch expr` (errors run handler)
- Reduce/Foreach: `reduce <expr> as $x (init; update)`, `foreach <expr> as $x (init; update; extract)`
- Literals: numbers, strings, `true/false/null`, arrays `[ ... ]`, objects `{ ... }`
- Pipe/comma: `|`, `,`
- Builtins: `length`, `type`, `keys`
- Functions: `select(expr)`, `map(expr)`, `contains(x)`, `startswith(x)`, `endswith(x)`
- Variables: `.expr as $x | ...`, `$x`
- Logic: `and`, `or`, `not`
- Compare: `==`, `!=`, `<`, `<=`, `>`, `>=`
- Arithmetic: `+`, `-`, `*`, `/`
- Control: `if ... then ... else ... end`, `empty`, `//`

## JS/TS (Minimal API)

This package exposes a small, stable API for JS/TS usage. Build with the JS
target and import the generated bundle.

Functions:
- `parseJson(text)` -> Json
- `parseFilter(text)` -> Filter
- `eval(filter, json)` -> Json[]
- `evalToJsonStrings(filter, jsonText)` -> string[] (JSON strings)

## Compatibility Baseline

The compatibility baseline and current gap list is tracked in:

- `docs/compatibility-matrix.md`

Differential smoke test against `jq`:

```powershell
./scripts/jq_diff.ps1
```

```bash
bash ./scripts/jq_diff.sh
```

Cases are defined in `scripts/jq_compat_cases.json` and are expected to be
expanded continuously.

Notes:
- PowerShell script resolves `jq` via `mise which jq` if `jq` is not in `PATH`.
- Bash script first uses `PATH`, then falls back to `mise` where possible.

Build:
```bash
moon build --target js js
```

Build executable:
```bash
moon build --target native cmd
```
The executable will be placed under `_build/native/release`. Look for `jqx`
and run it directly.

### Linux

Prerequisites:
- C toolchain (gcc/clang) and standard build essentials

Commands:
```bash
moon test --target native --package core
moon run --target native cmd -- ".foo" '{"foo": 1}'
```

Build executable:
```bash
moon build --target native cmd
```
The executable will be placed under `_build/native/release`. Look for `jqx`
and run it directly.

## Notes

- The CLI is native-only because stdin is implemented via native `getchar`.
- JS/TS usage will be added as a separate library entry point.
- Library users should import `shina1024/jqx/core` directly; the root package is
  a thin wrapper around core.
