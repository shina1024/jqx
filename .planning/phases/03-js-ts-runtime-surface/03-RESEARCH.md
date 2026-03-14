# Phase 3: JS/TS Runtime Surface - Research

**Researched:** 2026-03-14
**Domain:** JS/TS direct runtime boundary, binding helpers, and npm artifact verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- `@shina1024/jqx` is the synchronous direct-use runtime surface.
- `@shina1024/jqx/bind` is the asynchronous backend-binding surface.
- Main-package docs and examples should stay function-centric: `run`, `compile`, `parseJson`, `isValidJson`, `query`, and their JSON-text counterparts are the primary public entrypoints.
- The normal on-ramp is `run(filter, input)`; `compile(...).run(...)` is the explicit reuse path rather than the first thing users should see.
- The value lane is the default JS/TS story; `runJsonText(...)`, `queryJsonText(...)`, and compiled `.runJsonText(...)` are the formal compatibility lane when jq-style text fidelity matters.
- The canonical JS/TS failure contract is `JqxResult<..., JqxRuntimeError>`, not throw-driven control flow for ordinary runtime failures.
- `query(...)` and typed query DSL helpers remain part of the main package, but they are a secondary lane after string-filter runtime usage.
- `query(...)` should accept both typed DSL `Query` values and lower-level `QueryAst` values through one public entrypoint.
- `runtime` and `queryRuntime` remain exported from the main package, but as secondary adapter and integration helpers rather than the first-step API.
- `queryRuntime` remains separate from `runtime`; query-aware integrations opt into it explicitly.

### Claude's Discretion
- Exact root export ordering and README structure needed to keep the runtime story obvious without widening the public surface.
- Exact internal refactor split needed to share helper logic across direct runtime and `/bind`.
- Exact build-script or package-refresh strategy needed to make JS/TS packaging proof reliable on the maintained environments.

### Deferred Ideas (OUT OF SCOPE)
- Moving query helpers to a dedicated `@shina1024/jqx/query` subpath is a declared v2 direction, not a Phase 3 requirement.
- Full adapter-package hardening belongs to Phase 5; Phase 3 only needs enough smoke coverage to avoid breaking the published package surface.
</user_constraints>

<research_summary>
## Summary

Phase 3 is not a greenfield API design problem. The repo already exposes almost all of the intended canonical JS/TS names:

- `run`, `runJsonText`, `compile`, `parseJson`, `isValidJson`
- `query`, `queryJsonText`
- `CompiledFilter.run(...)`, `CompiledFilter.runJsonText(...)`
- `bindRuntime`, `bindQueryRuntime`

The main planning implication is that Phase 3 should focus on boundary hardening, export discipline, and package-proof rather than inventing new runtime semantics. The direct runtime in `ts/jqx/src/direct_runtime.ts` already bundles the generated MoonBit runtime and delegates behavior through the JSON-text compatibility lane. The binding surface in `ts/jqx/src/bind.ts` already wraps JSON-text backends into Promise and streaming clients. The real gaps are:

1. the root package is broader and noisier than the intended "small canonical runtime API"
2. direct and bound runtimes duplicate codec, error, and query-normalization logic
3. package verification is source-level today, not built-artifact-level
4. the current Windows checkout shows a toolchain portability problem: `pnpm test` passes, but `pnpm build` and `pnpm typecheck` fail because `node_modules/.bin` contains Unix-style shims (`esbuild`, `tsgo`) without `.cmd` wrappers

**Primary recommendation:** Treat `ts/jqx/src/index.ts`, `ts/jqx/src/direct_runtime.ts`, `ts/jqx/src/bind.ts`, `ts/jqx/package.json`, `scripts/ts_package_build.mjs`, `scripts/ts_packages.mjs`, `ts/jqx/README.md`, and the TS test files as the Phase 3 center of gravity. Avoid re-opening jq semantics in MoonBit or adapter behavior in depth unless Phase 3 surface proof exposes a true semantic mismatch.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries and tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ts/jqx/src/direct_runtime.ts` | repo current | Canonical synchronous runtime and `CompiledFilter` surface | This is already where the direct-use runtime contract lives |
| `ts/jqx/src/bind.ts` | repo current | Async backend-binding surface and streaming wrappers | This is already the `/bind` contract and should remain the integration seam |
| `ts/jqx/src/index.ts` | repo current | Root export policy for the npm package | This is the place where "small canonical root API" must become observable |
| `ts/jqx/package.json` | repo current | Package export map and output contract | TS-04 is ultimately about this observable package surface |
| `scripts/ts_package_build.mjs` | repo current | ESM/CJS/declaration artifact generation | This is the build seam that creates the publishable outputs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ts/adapter-core/src/index.ts` | repo current | Shared `Json`, `JqxResult`, `JqxRuntimeError`, query DSL, and inference contracts | Use whenever direct and bound runtimes need one shared public error and type vocabulary |
| `ts/jqx/test/direct_runtime.test.ts` | repo current | Behavioral proof for direct runtime and compiled execution | Use to prove runtime-first API behavior |
| `ts/jqx/test/index.test.ts` | repo current | Behavioral proof for `/bind` helpers and streaming wrappers | Use to prove binding helpers stay aligned with the direct runtime contract |
| `ts/jqx/test/typecheck.ts` | repo current | Type-level proof for public JS/TS contracts | Use to prove root and bind type surfaces, then extend it or split fixtures for package-name import proof |
| `pnpm test` | local verified | Fast runtime regression loop | Already passes in this checkout and exercises both direct and bind behavior |
| `pnpm build`, `pnpm typecheck` | local currently failing | Artifact and declaration proof | These are required by TS-04 and need to become reliable during this phase |
| `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | repo standard | CI-equivalent TS package verification | This is the intended full TS gate from AGENTS.md |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hardening the existing root package | Introduce a new wrapper package for JS/TS | Adds avoidable churn and another migration path before 1.0 |
| Shared helper extraction between direct and bind runtimes | Duplicated encode/decode/error logic in each surface | Simpler short term, but it invites semantic drift between surfaces |
| Artifact-level import and declaration proof | Source-level tests only | Faster to maintain, but it leaves TS-04 unproven |
| Tool-agnostic build invocation or refresh-aware scripts | Assuming platform-specific `.cmd` shims always exist | Works only when installs match the current OS; this checkout already disproves that assumption |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Runtime-first root package
**What:** Keep `@shina1024/jqx` centered on direct runtime calls and compiled reuse, with query helpers and runtime objects clearly secondary.
**When to use:** For `ts/jqx/src/index.ts`, README ordering, and public typecheck proof.
**Example:**
```ts
export {
  compile,
  isValidJson,
  parseJson,
  run,
  runJsonText,
} from "./direct_runtime.js";
```

### Pattern 2: Dual-lane execution over one semantic backend
**What:** The value lane stringifies/parses on the TS side, while the JSON-text lane remains the formal fidelity path.
**When to use:** For direct runtime, compiled runtime, and query runtime paths.
**Example:**
```ts
run(filter, input: Json): JqxResult<Json[], JqxRuntimeError>
runJsonText(filter, input: string): JqxResult<string[], JqxRuntimeError>
compiled.run(input: Json)
compiled.runJsonText(input: string)
```

### Pattern 3: `/bind` wraps JSON-text runtimes instead of redefining semantics
**What:** Backend integrations implement JSON-text operations, and `bindRuntime`/`bindQueryRuntime` lift them into value-lane and streaming client APIs.
**When to use:** For async backends, worker/RPC integrations, and adapter-facing runtime handles.
**Example:**
```ts
const jqx = bindRuntime({
  async runJsonText(filter, input) {
    return { ok: true as const, value: [input] };
  },
});
```

### Pattern 4: Artifact-level package proof
**What:** Verify built `dist` outputs and package-name imports, not only source-file imports.
**When to use:** For `TS-04`, export-map changes, and type declaration proof.
**Example:**
```ts
import { run } from "@shina1024/jqx";
const jqx = require("@shina1024/jqx/bind");
```

## Validation Architecture

Phase 3 validation needs two layers:

- **Fast loop:** `pnpm test`
- **Artifact loop:** `pnpm build && pnpm typecheck && pnpm test`
- **Phase gate:** `bash ./scripts/ts_packages.sh verify --frozen-lockfile`

The planner should assume every plan in this phase needs verification that touches both behavior and packaging shape:

- root runtime names and README ordering
- `CompiledFilter.run(...)` and `CompiledFilter.runJsonText(...)`
- `bindRuntime` / `bindQueryRuntime` value-lane, text-lane, and streaming behavior
- package export map coverage for `.` and `./bind`, with smoke coverage for adapter subpaths that already ship from the main package
- generated `dist/*.js`, `dist/*.cjs`, `dist/*.d.ts`, and `dist/*.d.cts` outputs
- package-name ESM and CJS import proof
- package-name TS declaration proof, including `.d.cts` resolution for CommonJS consumers

Current local finding: the checkout can run `pnpm test`, but `pnpm build` and `pnpm typecheck` fail because `node_modules/.bin` contains Unix-style shims and the build script expects Windows `.cmd` wrappers. The plan should therefore reserve work for either package refresh in the documented dependency order, script hardening, or both before treating build/typecheck as stable task-level verifies.
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but already have the right repo-level solution:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Runtime semantics in TS | A second TS-native jq evaluator | The generated MoonBit runtime in `ts/jqx/src/moonbit_runtime.ts` | Shared semantics are a core project requirement |
| Error transport | Throw-first wrappers for normal runtime failures | `JqxResult` plus `JqxRuntimeError` from adapter-core | The context explicitly chose result-based JS/TS failures |
| Direct vs bind drift | Separate stringify/parse/error/query helper logic in each file | Shared internal helpers used by both `direct_runtime.ts` and `bind.ts` | Lane behavior must stay aligned across surfaces |
| Package proof | Existing source-import tests only | Built-artifact smoke tests plus package-name import/typecheck fixtures | TS-04 is about shipped artifacts, not just source modules |
| API cleanup | Alias exports for every previous shape | One obvious public spelling per operation | AGENTS.md explicitly rejects alias-heavy pre-1.0 debt |
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: The root package reads like a kitchen sink
**What goes wrong:** `@shina1024/jqx` looks like a mixed bag of runtime calls, query DSL, AST document helpers, error helpers, and adapter surfaces with no obvious primary story.
**Why it happens:** The current root export module re-exports many useful things, so convenience slowly outruns clarity.
**How to avoid:** Make `run`, `runJsonText`, `compile`, `parseJson`, and `isValidJson` the unmistakable headline path in exports, docs, and tests.

### Pitfall 2: Direct and bound runtimes drift semantically
**What goes wrong:** JSON stringify/parse, error normalization, or query normalization behave differently between `run(...)` and `bindRuntime(...).run(...)`.
**Why it happens:** `direct_runtime.ts` and `bind.ts` currently duplicate several helpers.
**How to avoid:** Centralize shared helpers or otherwise force both surfaces through the same internal logic.

### Pitfall 3: Packaging proof stops at pre-existing `dist` files
**What goes wrong:** The repo has `dist` artifacts checked in or locally present, so it looks like packaging works even when current builds cannot reproduce them.
**Why it happens:** Tests import from `src`, not from package entrypoints after build.
**How to avoid:** Make Phase 3 prove fresh build outputs and package-name imports.

### Pitfall 4: Build tooling assumes the install OS matches the current execution OS
**What goes wrong:** `pnpm build` or `pnpm typecheck` fail because `.bin` shims were installed for a different environment.
**Why it happens:** This checkout already contains Unix-style shims under `ts/jqx/node_modules/.bin`, while the Windows path expects `.cmd` wrappers.
**How to avoid:** Either refresh packages in the documented order or harden scripts so tool invocation does not depend on fragile platform-specific shims.

### Pitfall 5: Query helpers displace the runtime-first story
**What goes wrong:** `query(...)` and DSL helpers start to read like a competing public narrative rather than the secondary TS convenience lane.
**Why it happens:** The main package intentionally includes query support, so without careful ordering it can dominate the docs and exports.
**How to avoid:** Keep string-filter runtime usage first, compiled reuse second, query helpers third.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Existing canonical direct runtime names
```ts
export function runJsonText(filter: string, input: string): JqxResult<string[], JqxRuntimeError>
export function run(filter: string, input: Json): JqxResult<Json[], JqxRuntimeError>
export function compile(filter: string): JqxResult<CompiledFilter, JqxRuntimeError>
export function parseJson(input: string): JqxResult<Json, JqxRuntimeError>
export function isValidJson(input: string): boolean
```

### Existing compiled-filter lane split
```ts
export class CompiledFilter<Filter extends string = string> {
  run(input: Json): JqxResult<Json[], JqxRuntimeError>
  runJsonText(input: string): JqxResult<string[], JqxRuntimeError>
}
```

### Existing package export map direction
```json
{
  "exports": {
    ".": { "types": "./dist/index.d.ts", "import": "./dist/index.js", "require": "./dist/index.cjs" },
    "./bind": { "types": "./dist/bind.d.ts", "import": "./dist/bind.js", "require": "./dist/bind.cjs" }
  }
}
```
</code_examples>

<open_questions>
## Open Questions

1. **How much query surface should remain prominent on the root package before v2?**
   - What we know: query helpers remain in the main package for now.
   - What is unclear: how aggressively export order and docs should demote them without creating a breaking surprise for current users.
   - Recommendation: keep the APIs, but make them clearly secondary in exports, README order, and quick-start examples.

2. **Should Phase 3 solve the local build failure through package refresh, script hardening, or both?**
   - What we know: `pnpm test` works, while `pnpm build` and `pnpm typecheck` do not in this Windows checkout.
   - What is unclear: whether a clean refresh alone is sufficient or whether `scripts/ts_package_build.mjs` should stop assuming `.cmd` shims.
   - Recommendation: prefer a robust script path even if a refresh is also needed, because Phase 3 is about package reliability.

3. **How much adapter-subpath proof belongs in this phase?**
   - What we know: the main package currently exports `./zod`, `./yup`, and `./valibot`, but Phase 5 owns adapter hardening.
   - What is unclear: whether Phase 3 should do only existence/import smoke tests or deeper behavior checks.
   - Recommendation: smoke-test subpath resolution and leave adapter behavior depth to Phase 5.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `AGENTS.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/03-js-ts-runtime-surface/03-CONTEXT.md`
- `ts/jqx/src/direct_runtime.ts`
- `ts/jqx/src/bind.ts`
- `ts/jqx/src/index.ts`
- `ts/jqx/src/moonbit_runtime.ts`
- `ts/jqx/package.json`
- `ts/jqx/README.md`
- `ts/jqx/test/direct_runtime.test.ts`
- `ts/jqx/test/index.test.ts`
- `ts/jqx/test/typecheck.ts`
- `ts/adapter-core/src/index.ts`
- `scripts/ts_package_build.mjs`
- `scripts/ts_packages.mjs`

### Secondary (MEDIUM confidence)
- `ts/jqx/dist/index.d.ts`
- `ts/jqx/dist/direct_runtime.d.ts`
- `ts/jqx/dist/bind.d.ts`
- local shell verification in this checkout: `pnpm test` passed; `pnpm build` and `pnpm typecheck` failed because tool shims are not Windows-runnable
</sources>

<metadata>
## Metadata

**Research scope:**
- JS/TS root runtime boundary and docs
- compiled-filter and `/bind` contract alignment
- package export and artifact verification
- local toolchain/verification viability

**Confidence breakdown:**
- Public API direction: HIGH
- Compiled/bind contract direction: HIGH
- Package verification gaps: HIGH
- Exact build-tool remediation strategy: MEDIUM

**Research date:** 2026-03-14
**Valid until:** 2026-04-13
</metadata>

---

*Phase: 03-js-ts-runtime-surface*
*Research completed: 2026-03-14*
*Ready for planning: yes*
