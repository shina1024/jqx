# shina1024/jqx

jqx is a jq-compatible tool (work in progress) written in MoonBit.

## Build (Native)

### Windows

Prerequisites:
- Visual Studio Build Tools (C++ build tools)
- Windows 10/11 SDK

Recommended shell:
- Use **Developer Command Prompt for VS** (it sets `INCLUDE`/`LIB`/`PATH`).

Commands:
```powershell
moon test --target native --package core
moon run --target native cmd/jqx -- ".foo" '{"foo": 1}'
```

Build executable:
```powershell
moon build --target native cmd/jqx
```
The executable will be placed under `_build/native/release`. Look for `jqx.exe`
(or the most recently updated `.exe`) and run it directly.

### macOS

Prerequisites:
- Xcode Command Line Tools

Commands:
```bash
moon test --target native --package core
moon run --target native cmd/jqx -- ".foo" '{"foo": 1}'
```

Options:
```bash
# Raw string output (no JSON quotes)
moon run --target native cmd/jqx -- -r ".foo" '{"foo": "bar"}'
```

Build executable:
```bash
moon build --target native cmd/jqx
```
The executable will be placed under `_build/native/release`. Look for `jqx`
and run it directly.

### Linux

Prerequisites:
- C toolchain (gcc/clang) and standard build essentials

Commands:
```bash
moon test --target native --package core
moon run --target native cmd/jqx -- ".foo" '{"foo": 1}'
```

Build executable:
```bash
moon build --target native cmd/jqx
```
The executable will be placed under `_build/native/release`. Look for `jqx`
and run it directly.

## Notes

- The CLI is native-only because stdin is implemented via native `getchar`.
- JS/TS usage will be added as a separate library entry point.
