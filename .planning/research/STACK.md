# Stack Research

**Domain:** MoonBit-based jq-compatible runtime with CLI, JS/TS, and MoonBit public surfaces
**Researched:** 2026-03-12
**Confidence:** MEDIUM

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| MoonBit toolchain | v0.8.3 docs / current beta toolchain | Implement the shared parser, compiler, runtime, native CLI, and JS-target output | The project's core goal is evaluating MoonBit as one implementation across all surfaces, and the official docs support package, test, JS, and native workflows |
| jq | 1.8.1 | Compatibility oracle for language semantics and CLI behavior | The repo explicitly targets jq 1.8.1, so this should remain the fixed external contract for tests, docs, and exception handling |
| Node.js | 24.x LTS | npm packaging, JS/TS tests, release verification | The official Node release page lists v24 as Active LTS on 2026-03-12, making it the safest baseline for package consumers and CI |
| `@typescript/native-preview` | 7.0.0-dev.20260313.1 | Workspace typechecking backend for npm package and adapter development | The current `ts/*` packages pin `@typescript/native-preview`, and repo scripts route type-aware checks through that toolchain rather than stock `typescript` |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| pnpm | repo-managed | Install and verify TS packages | Use for `ts/*` package refresh and frozen-lockfile verification |
| esbuild + tsgo | repo current | Build ESM/CJS bundles and emit declaration files for npm packages | The current package scripts call `ts_package_build.mjs`, which shells out to `esbuild` and `tsgo` rather than `tsup` |
| oxfmt | 0.38.0 | Format TS workspace files | Use for package-level formatting checks |
| oxlint | 1.53.0 | Lint TS workspace files | Use for fast linting on public TS surfaces |
| zod / yup / valibot adapters | repo current | Provide practical library integrations without changing core jq semantics | Use as optional library-side extensions, not as runtime dependencies for the compatibility core |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `moon info`, `moon fmt`, `moon check`, `moon test` | MoonBit quality gate | Run in this order for code changes; inspect `.mbti` diffs when public APIs move |
| `pnpm build`, `pnpm test`, `pnpm typecheck` | npm surface verification | Run after refreshing local `file:` dependencies in dependency order; `typecheck` uses `tsgo` on top of the pinned native-preview toolchain |
| GitHub Releases + npm publish dry runs | Release rehearsal | Required before first public release so packaging bugs do not show up at launch time |

## Installation

```bash
# Core toolchains
# Install the latest MoonBit toolchain from the official installer
# Install Node.js 24 LTS from nodejs.org
npm install -g pnpm

# Example npm package verification
cd ts/jqx
pnpm install --frozen-lockfile
pnpm build
pnpm test
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| One shared MoonBit core | Separate Rust or Go core plus bindings | Use only if raw performance or ecosystem maturity becomes more important than evaluating MoonBit itself |
| `esbuild` + `tsgo` packaging | Rollup or unbuild | Use if output customization becomes much more complex than the current runtime-plus-adapter package shape |
| Node 24 LTS baseline | Node Current | Use only if a required runtime feature lands after Node 24 and materially helps packaging or tests |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Separate implementations per surface | This guarantees semantic drift and duplicates compatibility work | One shared MoonBit core with thin CLI, JS/TS, and MoonBit adapters |
| CLI-only feature growth beyond jq | This weakens the compatibility contract and complicates oracle testing | Keep practical extensions in library packages only |
| Alias-heavy public APIs before 1.0 | This creates avoidable API debt and confusing docs | Promote canonical names early and remove obsolete aliases |

## Stack Patterns by Variant

**If verifying jq behavior:**
- Use the JSON-text compatibility lane and jq 1.8.1 oracle checks
- Because numeric fidelity, output text, and exit semantics are easiest to validate from preserved JSON text

**If building ergonomic library APIs:**
- Use the value lane on top of the same compiled filter/runtime core
- Because MoonBit and JS users want standard `Json` and object inputs without losing semantic alignment

**If publishing schema integrations:**
- Put adapters in separate `ts/*` packages
- Because the main runtime package should stay runtime-first and not make optional validation libraries mandatory

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| MoonBit current beta toolchain | Repo package version `0.1.0` | The language is still pre-1.0, so API cleanup pressure is expected |
| Node 24 LTS | `@typescript/native-preview` 7.0.0-dev.20260313.1, `esbuild`, `tsgo`, Node test runner | Stable npm packaging and test baseline |
| jq 1.8.1 | jqx compatibility suite | Treat jq as a fixed oracle, not an approximate target |

## Sources

- https://docs.moonbitlang.com/en/latest/ - official MoonBit docs and current documentation version
- https://docs.moonbitlang.com/en/latest/package/package-manager.html - official MoonBit package manager and `moon publish`
- https://www.moonbitlang.com/download/ - official MoonBit installation guidance
- https://nodejs.org/en/about/previous-releases - official Node.js release status
- `ts/jqx/package.json`, `ts/adapter-core/package.json`, `ts/yup-adapter/package.json`, `ts/zod-adapter/package.json`, `ts/valibot-adapter/package.json` - current TS workspace toolchain pins and script definitions
- https://jqlang.org/manual/ - official jq manual
- https://github.com/jqlang/jq/releases/tag/jq-1.8.1 - official jq 1.8.1 release page
- `README.mbt.md`, `AGENTS.md`, `moon.mod.json`, `ts/jqx/package.json`, `ts/adapter-core/package.json` - current repo conventions and versions

---
*Stack research for: MoonBit-based jq-compatible runtime with CLI, JS/TS, and MoonBit public surfaces*
*Researched: 2026-03-12*
