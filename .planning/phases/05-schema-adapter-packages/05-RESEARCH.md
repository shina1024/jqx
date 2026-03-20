# Phase 5: Schema Adapter Packages - Research

**Researched:** 2026-03-20
**Domain:** JS/TS schema adapter package boundaries, shared adapter contracts, and validation-proof strategy
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- The canonical public adapter surfaces are the standalone packages `@shina1024/jqx-zod-adapter`, `@shina1024/jqx-yup-adapter`, and `@shina1024/jqx-valibot-adapter`.
- `@shina1024/jqx/zod`, `@shina1024/jqx/yup`, and `@shina1024/jqx/valibot` should be removed rather than kept as convenience aliases.
- `@shina1024/jqx` must return to being the runtime package, not a mixed runtime-plus-adapter umbrella.
- `@shina1024/jqx-adapter-core` remains an internal shared package, not a normal end-user entrypoint.
- Normal adapter usage docs should show three explicit dependencies: `@shina1024/jqx`, one adapter package, and one validator package.
- The canonical adapter on-ramp is `createAdapter(runtime).filter(...)`.
- `infer(...)` remains public but secondary to `filter(...)`.
- Query integration remains opt-in through `createQueryAdapter(runtime).query(...)`.
- Keep the existing factory names `createAdapter` and `createQueryAdapter`.
- The adapter error contract keeps the stable top-level `input_validation`, `runtime`, and `output_validation` kinds plus a jqx-owned top-level `message`.
- The `issues` payload should preserve validator-native detail instead of normalizing all libraries into one jqx-specific issue shape.
- Yup and Valibot should move closer to Zod in structured issue richness where practical.
- Adapter docs must make the runtime boundary explicit: adapters sit on the stable jqx runtime contract and do not depend on internal runtime details.

### Claude's Discretion
- Exact package and build-script edits required to remove adapter subpaths from `@shina1024/jqx` cleanly.
- Exact shared issue payload typing that preserves validator-native detail without making adapter-core a public user on-ramp.
- Exact test and README updates needed to keep the runtime-first story coherent across root and adapter packages.
- Exact artifact-level proof needed to show adapter boundaries changed without breaking package outputs.

### Deferred Ideas (OUT OF SCOPE)
- New schema-library integrations beyond Zod, Yup, and Valibot.
- Broadening jqx runtime semantics or the query/runtime API beyond Phase 3.
- Turning `@shina1024/jqx-adapter-core` into a promoted public package.
</user_constraints>

<research_summary>
## Summary

Phase 5 is not a greenfield adapter design problem. The repo already has real standalone adapter packages, a shared adapter-core contract, package-local tests, and type fixtures. The remaining work is public-surface hardening and proof:

- `ts/zod-adapter/src/index.ts`, `ts/yup-adapter/src/index.ts`, and `ts/valibot-adapter/src/index.ts` already expose the intended `createAdapter(runtime)` and `createQueryAdapter(runtime)` factories.
- `ts/adapter-core/src/index.ts` already owns the shared `JqxRuntime`, `JqxQueryRuntime`, `AdapterError`, runtime error forwarding, and inference helpers.
- The root runtime package still exposes adapter subpaths through `ts/jqx/package.json` and `ts/jqx/src/zod.ts`, `src/yup.ts`, `src/valibot.ts`, so the public package story is currently duplicated.
- `ts/jqx/README.md` and the adapter READMEs still teach the old subpath story, so docs and canonical import paths are not yet aligned with the locked decisions.
- Zod already preserves native `z.ZodIssue[]`, but Yup and Valibot currently collapse issues to `string[]`, which conflicts with the intent to preserve richer validator-native detail where practical.
- Shared adapter contract tests already exist in `ts/adapter-core/test/adapter_contract_cases.ts`, and package-local runtime tests currently pass for Zod, Yup, and Valibot.

Local verification in this checkout:
- `pnpm test` passed in `ts/zod-adapter`
- `pnpm test` passed in `ts/yup-adapter`
- `pnpm test` passed in `ts/valibot-adapter`
- `pnpm test` failed in `ts/jqx` because `pnpm build` fails with a missing native binding during `ts_package_build.mjs`

The primary planning implication is that Phase 5 should stay split into two slices:

1. stabilize adapter-core contracts and package boundaries
2. harden docs, tests, and validator-specific behavior across Zod, Yup, and Valibot

The root package export cleanup and built-artifact proof cannot be treated as a docs-only change because `ts/jqx/test/package_exports.test.ts` currently asserts that adapter subpaths resolve from `@shina1024/jqx`. Phase 5 must intentionally invert that proof story.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries and tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ts/adapter-core/src/index.ts` | repo current | Shared runtime, result, adapter error, and validation helpers | This is the existing contract seam shared by all adapters |
| `ts/zod-adapter/src/index.ts` | repo current | Zod adapter public API and native issue preservation baseline | This already matches the intended factory shape |
| `ts/yup-adapter/src/index.ts` | repo current | Yup adapter public API and issue-shaping implementation | This is where richer Yup issue detail must be preserved |
| `ts/valibot-adapter/src/index.ts` | repo current | Valibot adapter public API and issue-shaping implementation | This is where richer Valibot issue detail must be preserved |
| `ts/jqx/package.json` | repo current | Root npm export map and dependency boundary | This is where the runtime-only package story becomes observable |
| `ts/jqx/src/zod.ts`, `src/yup.ts`, `src/valibot.ts` | repo current | Current root-package adapter re-export shims | These are the files that currently keep the duplicated public story alive |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ts/adapter-core/test/adapter_contract_cases.ts` | repo current | Shared runtime and validation behavior contract across adapters | Use to keep Zod, Yup, and Valibot behavior aligned |
| `ts/zod-adapter/test/index.test.ts` | repo current | Zod runtime behavior proof | Use for adapter behavior and issue-shape regressions |
| `ts/yup-adapter/test/index.test.ts` | repo current | Yup runtime behavior proof | Use when changing Yup issue payloads or shared hooks |
| `ts/valibot-adapter/test/index.test.ts` | repo current | Valibot runtime behavior proof | Use when changing Valibot issue payloads or shared hooks |
| `ts/zod-adapter/test/typecheck.ts` | repo current | Zod public type surface proof | Use when changing adapter error types or factory signatures |
| `ts/yup-adapter/test/typecheck.ts` | repo current | Yup public type surface proof | Use when changing issue payload types |
| `ts/valibot-adapter/test/typecheck.ts` | repo current | Valibot public type surface proof | Use when changing issue payload types |
| `ts/jqx/test/package_exports.test.ts` | repo current | Built-artifact and package-name import proof for root exports | Use when removing root adapter subpaths and validating the new package boundary |
| `ts/jqx/README.md` and adapter `README.md` files | repo current | Public package narrative and install/import examples | Use to align canonical imports and example ordering |
| `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | repo standard | CI-equivalent TS package verification | Use as the full-suite gate after package boundary changes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Removing root adapter subpaths | Keeping `@shina1024/jqx/zod` style aliases | Easier short term, but it keeps the public story duplicated and violates the locked decision to prefer one obvious spelling |
| Preserving validator-native issue payloads | Converting all libraries to `string[]` | Simpler implementation, but it throws away structured issue data and weakens adapter ergonomics |
| Reusing shared adapter-core contract tests | Copy-pasting behavior tests per adapter | Faster to write once, but it invites drift across Zod, Yup, and Valibot |
| Built-artifact package proof | Source-import-only tests | Cheaper locally, but it fails to prove the shipped npm surface after export-map changes |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: Standalone adapter packages over root-package subpaths
**What:** `@shina1024/jqx` stays the runtime package while adapters live at their own package names.
**When to use:** For package export maps, dependency cleanup, README install examples, and package-name smoke tests.
**Example:**
```ts
import { runtime } from "@shina1024/jqx";
import { createAdapter } from "@shina1024/jqx-zod-adapter";
```

### Pattern 2: Adapter-core owns the shared contract, runtime package owns semantics
**What:** Adapters depend on the stable `JqxRuntime` / `JqxQueryRuntime` contract from adapter-core and do not reach into MoonBit or root runtime internals.
**When to use:** For adapter implementation work, shared helper changes, and runtime error forwarding.
**Example:**
```ts
export function createAdapter(runtime: JqxRuntime): DynamicAdapter {
  return createDynamic(runtime);
}
```

### Pattern 3: Preserve native validator issue payloads behind one stable top-level error shape
**What:** Keep `kind` and `message` stable across adapters, but let `issues` stay native to each validator where practical.
**When to use:** For Yup and Valibot issue handling, shared adapter error typing, and type fixtures.
**Example:**
```ts
type AdapterError<Issues> =
  | { kind: "input_validation"; message: string; issues: Issues }
  | { kind: "runtime"; message: string; runtimeError: JqxRuntimeError }
  | { kind: "output_validation"; index: number; message: string; issues: Issues };
```

### Pattern 4: Contract tests stay shared, artifact tests stay root-package aware
**What:** Use shared adapter behavior tests to keep runtime semantics aligned, and use root package export tests to prove the public package boundary actually changed.
**When to use:** For package-boundary changes, issue-shape changes, and README/import proof.
**Example:**
- `ts/adapter-core/test/adapter_contract_cases.ts` proves shared adapter behavior
- `ts/jqx/test/package_exports.test.ts` proves built package entrypoints

### Pattern 5: Runtime-first docs, adapter-second docs
**What:** The runtime package quick start should stay centered on `@shina1024/jqx`, while adapter READMEs start with `createAdapter(runtime).filter(...)`.
**When to use:** For README reordering and install/import snippets.
**Example:**
- Root README: runtime first, adapters as optional integrations
- Adapter README: `createAdapter(runtime).filter(...)` before `infer(...)` or query helpers

## Validation Architecture

Phase 5 validation needs two layers:

- **Fast loop:** package-local `pnpm test` in the touched adapter package(s)
- **Contract/type loop:** package-local `pnpm typecheck` where adapter error or factory signatures change
- **Artifact/package loop:** `pnpm build && pnpm test` in `ts/jqx` after root export-map changes
- **Phase gate:** `bash ./scripts/ts_packages.sh verify --frozen-lockfile`

Current local findings:
- adapter package runtime tests are already green for Zod, Yup, and Valibot
- root-package artifact verification is not currently stable in this checkout because `ts/jqx` build fails with a missing native binding during `ts_package_build.mjs`

Planning implication:
- Phase 5 does not need a brand-new test harness for adapter behavior
- but it does need an explicit validation path for root-package artifact proof before export-map changes can be treated as complete
- the first plan should reserve work either to restore `ts/jqx` package verification in the current environment or to route verification through the documented package-refresh path before claiming boundary cleanup is proven
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but already have the right repo-level solution:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Shared adapter result and runtime types | Per-adapter copies of `JqxRuntime`, `JqxResult`, or `AdapterError` | `ts/adapter-core/src/index.ts` | Shared contracts are already centralized |
| Adapter behavior proof | Independent hand-written behavior suites per validator | `ts/adapter-core/test/adapter_contract_cases.ts` plus package-local tests | This keeps runtime behavior aligned across all three adapters |
| Public adapter imports | Root-package convenience subpaths | Standalone adapter package names | The locked decisions explicitly reject alias-heavy public surfaces |
| Validator issue detail | Converting every issue to a display string too early | Native validator issues in `issues`, jqx-owned top-level `message` | Preserves useful structure without changing the common error kind contract |
| Package export validation | Reading `package.json` only | Built-artifact tests in `ts/jqx/test/package_exports.test.ts` and package-name imports | The phase changes observable npm surfaces, so shipped artifacts must be proven |
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Root package and standalone packages both remain canonical
**What goes wrong:** Docs, exports, and tests continue to support both `@shina1024/jqx/zod` and `@shina1024/jqx-zod-adapter`.
**Why it happens:** The current code already supports both stories, so it is easy to "defer cleanup."
**How to avoid:** Remove root adapter subpaths, their shim source files, and tests that assert they resolve.

### Pitfall 2: Yup and Valibot keep collapsing structured issues to `string[]`
**What goes wrong:** Top-level adapter error kinds stay stable, but downstream users still lose useful per-field validator detail.
**Why it happens:** The current implementations normalize too early.
**How to avoid:** Preserve native issue payloads and update type fixtures to prove the richer shapes.

### Pitfall 3: Adapter-core drifts into a promoted user-facing package
**What goes wrong:** README examples or root exports start pointing users at `@shina1024/jqx-adapter-core`.
**Why it happens:** It already holds the shared types and can look attractive as a shortcut.
**How to avoid:** Keep adapter-core as an internal implementation package and document runtime-plus-adapter usage instead.

### Pitfall 4: Export-map cleanup is declared done without built-artifact proof
**What goes wrong:** Source files and README text change, but the shipped package still exports stale entrypoints or broken dependency paths.
**Why it happens:** Source-level tests are quicker than package builds.
**How to avoid:** Make `ts/jqx` build/test or the documented TS package verify script part of plan acceptance.

### Pitfall 5: Docs center `infer(...)` or query helpers before `filter(...)`
**What goes wrong:** The public adapter story becomes abstract and harder to explain, even though the implementation is correct.
**Why it happens:** All three adapter APIs already exist and can appear equally weighted.
**How to avoid:** Keep `createAdapter(runtime).filter(...)` as the first real example everywhere.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Root package currently re-exports standalone adapters
```ts
export * from "@shina1024/jqx-zod-adapter";
```

### Root package export map still publishes adapter subpaths
```json
"./zod": {
  "types": "./dist/zod.d.ts",
  "import": "./dist/zod.js",
  "require": "./dist/zod.cjs"
}
```

### Zod already preserves native issues while Yup and Valibot do not
```ts
export type AdapterError = CoreAdapterError<z.ZodIssue[]>;
export type AdapterError = CoreAdapterError<string[]>;
```

### Root package tests currently assert adapter subpaths resolve
```ts
const zod = await import("@shina1024/jqx/zod");
const yup = await import("@shina1024/jqx/yup");
const valibot = await import("@shina1024/jqx/valibot");
```
</code_examples>

<open_questions>
## Open Questions

1. **How rich should the preserved Yup and Valibot issue payloads be?**
   - What we know: `string[]` is too lossy for the locked decision.
   - What is unclear: whether the public adapter types should expose native library issue arrays directly or library-shaped subsets.
   - Recommendation: prefer the actual native validator issue arrays unless a concrete incompatibility forces a narrower typed projection.

2. **Should root-package adapter dependencies disappear entirely after subpath removal?**
   - What we know: `ts/jqx/package.json` currently depends on all three adapter packages only to support root subpaths and docs/tests around them.
   - What is unclear: whether any root-package smoke or docs tooling still needs those dependencies after cleanup.
   - Recommendation: treat adapter package dependencies as removable unless a surviving test or build path proves otherwise.

3. **How should the current `ts/jqx` build failure be handled during this phase?**
   - What we know: local `pnpm test` in `ts/jqx` fails before tests because `pnpm build` cannot find a required native binding.
   - What is unclear: whether a dependency refresh alone fixes it or whether the package-build path needs hardening.
   - Recommendation: make root-package artifact verification an explicit part of the first plan so package-boundary work cannot end with unproven exports.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `AGENTS.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/PROJECT.md`
- `.planning/phases/05-schema-adapter-packages/05-CONTEXT.md`
- `.planning/phases/03-js-ts-runtime-surface/03-CONTEXT.md`
- `ts/adapter-core/src/index.ts`
- `ts/adapter-core/test/adapter_contract_cases.ts`
- `ts/jqx/package.json`
- `ts/jqx/README.md`
- `ts/jqx/src/zod.ts`
- `ts/jqx/src/yup.ts`
- `ts/jqx/src/valibot.ts`
- `ts/jqx/test/package_exports.test.ts`
- `ts/zod-adapter/src/index.ts`
- `ts/zod-adapter/README.md`
- `ts/zod-adapter/test/index.test.ts`
- `ts/zod-adapter/test/typecheck.ts`
- `ts/yup-adapter/src/index.ts`
- `ts/yup-adapter/README.md`
- `ts/yup-adapter/test/index.test.ts`
- `ts/yup-adapter/test/typecheck.ts`
- `ts/valibot-adapter/src/index.ts`
- `ts/valibot-adapter/README.md`
- `ts/valibot-adapter/test/index.test.ts`
- `ts/valibot-adapter/test/typecheck.ts`

### Secondary (HIGH confidence local verification)
- local shell verification in this checkout: `pnpm test` passed in `ts/zod-adapter`
- local shell verification in this checkout: `pnpm test` passed in `ts/yup-adapter`
- local shell verification in this checkout: `pnpm test` passed in `ts/valibot-adapter`
- local shell verification in this checkout: `pnpm test` failed in `ts/jqx` because `pnpm build` failed with a missing native binding during `ts_package_build.mjs`
</sources>

<metadata>
## Metadata

**Research scope:**
- standalone adapter package boundaries vs root-package subpaths
- shared adapter-core contract stability
- validator-native issue payload preservation
- built-artifact proof for export-map changes

**Confidence breakdown:**
- current package-boundary gap: HIGH
- shared contract direction: HIGH
- validator issue-shape gap: HIGH
- exact root-package build remediation: MEDIUM

**Research date:** 2026-03-20
**Valid until:** 2026-04-19
</metadata>

---

*Phase: 05-schema-adapter-packages*
*Research completed: 2026-03-20*
*Ready for planning: yes*
