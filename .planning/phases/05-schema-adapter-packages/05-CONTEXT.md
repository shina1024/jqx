# Phase 5: Schema Adapter Packages - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Make Zod, Yup, and Valibot adapter packages work as stable JS/TS public packages on top of the canonical jqx runtime surface. This phase covers adapter package boundaries, canonical import paths, adapter API shape, validation error contracts, and adapter-facing documentation/examples. It does not add new schema-library integrations or broaden jqx runtime semantics.

</domain>

<decisions>
## Implementation Decisions

### Package boundaries and canonical imports
- The canonical public adapter surfaces are the independent packages `@shina1024/jqx-zod-adapter`, `@shina1024/jqx-yup-adapter`, and `@shina1024/jqx-valibot-adapter`.
- `@shina1024/jqx/zod`, `@shina1024/jqx/yup`, and `@shina1024/jqx/valibot` should be removed rather than kept as equal-weight aliases or convenience subpaths.
- `@shina1024/jqx` should return to being the runtime package, not a mixed runtime-plus-adapter umbrella.
- `@shina1024/jqx-adapter-core` remains an internal implementation package shared by adapters, not a normal end-user entrypoint.
- Adapter install/docs should explicitly show three direct dependencies for normal use: `@shina1024/jqx`, the selected adapter package, and the selected validator library.

### Adapter API shape
- The canonical adapter on-ramp is `createAdapter(runtime).filter(...)`.
- `infer(...)` remains public but is a secondary lane after `filter(...)`, not the first API users should see.
- Query integration remains opt-in through `createQueryAdapter(runtime).query(...)` rather than expanding the default adapter factory.
- Keep the current factory names `createAdapter` and `createQueryAdapter`.
- Keep the adapter story aligned with Phase 3's JS/TS runtime choice that string-filter execution is the normal path and query support is secondary.

### Validation error contract
- The top-level adapter error contract stays shared across validators with `input_validation`, `runtime`, and `output_validation` kinds.
- Adapter errors should continue to carry a stable top-level `message` chosen by jqx for quick logging and control-flow use.
- The `issues` payload should preserve validator-native detail rather than normalizing every library into one jqx-specific issue shape.
- Zod/Yup/Valibot adapters should be as symmetric as practical in issue richness; in particular, Yup and Valibot should move toward preserving structured native issue data instead of collapsing everything to `string[]` where practical.
- Runtime failures still flow through the stable jqx runtime error contract rather than validator-specific wrapping.

### Documentation and example ordering
- Each adapter README should begin with `createAdapter(runtime).filter(...)` as the first real example.
- The standard README runtime example should import `runtime` from `@shina1024/jqx` rather than leading with custom runtime injection.
- `query(...)` examples belong in a secondary section after the main filter flow.
- `infer(...)` examples should also live in a secondary section rather than the quick start.
- Adapter docs should make the runtime boundary explicit: adapters sit on the stable jqx runtime contract rather than reaching into runtime internals.

### Claude's Discretion
- Exact package/build/test changes needed to remove adapter subpaths from `@shina1024/jqx` cleanly without regressing package artifacts.
- Exact internal representation for richer Yup and Valibot issue payloads, as long as validator-native detail is preserved.
- Exact README wording and example depth needed to keep adapters clearly secondary to the runtime while still being practical public packages.
- Exact regression coverage additions needed to prove the new package boundaries, imports, and error payload shapes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and project constraints
- `.planning/ROADMAP.md` — Phase 5 goal, success criteria, and plan split for schema adapter packages.
- `.planning/REQUIREMENTS.md` — `ADPT-01`, `ADPT-02`, and `ADPT-03` define the required Zod, Yup, and Valibot adapter outcomes.
- `.planning/PROJECT.md` — project-level rule that library-side integrations may exist, but public surfaces should stay coherent and aligned with the stable runtime.

### Prior JS/TS runtime decisions
- `.planning/phases/03-js-ts-runtime-surface/03-CONTEXT.md` — Phase 3 locks the direct runtime as the main JS/TS surface, keeps `runtime` and `queryRuntime` secondary but public, and keeps query support secondary to string-filter execution.

### Current adapter and runtime public contract
- `ts/jqx/README.md` — current JS/TS runtime README, including the present adapter guidance and subpath-based examples that this phase should reconcile.
- `ts/jqx/package.json` — current npm export map showing adapter subpaths on the main runtime package.
- `ts/zod-adapter/README.md` — current Zod adapter README and its present public guidance.
- `ts/yup-adapter/README.md` — current Yup adapter README and its present public guidance.
- `ts/valibot-adapter/README.md` — current Valibot adapter README and its present public guidance.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ts/adapter-core/src/index.ts`: shared adapter contract types, runtime wrappers, validation runner helpers, and inference helpers already used by all three adapters.
- `ts/adapter-core/test/adapter_contract_cases.ts`: shared contract test suite that can keep Zod/Yup/Valibot behavior aligned while package boundaries change.
- `ts/zod-adapter/src/index.ts`, `ts/yup-adapter/src/index.ts`, `ts/valibot-adapter/src/index.ts`: already expose the same `createAdapter` / `createQueryAdapter` shape, so Phase 5 can harden a real existing pattern instead of inventing one.
- `ts/jqx/src/runtime_shared.ts`, `ts/jqx/src/direct_runtime.ts`, and `ts/jqx/src/index.ts`: already define the stable runtime objects and error helpers that adapters should depend on.

### Established Patterns
- The JS/TS runtime already treats `run(filter, input)` as the default on-ramp, with query support and integration helpers as secondary lanes.
- Adapter packages already use dependency injection with `runtime` / `queryRuntime` rather than reaching into MoonBit internals directly.
- The current codebase has both independent adapter packages and `@shina1024/jqx` adapter subpaths; this phase should collapse that duplicate public story to one canonical path.
- Contract tests and type tests already exist per adapter, which makes it practical to refactor public package shape without weakening behavioral proof.

### Integration Points
- Package-boundary work will primarily touch `ts/jqx/package.json`, `ts/jqx/src/zod.ts`, `ts/jqx/src/yup.ts`, `ts/jqx/src/valibot.ts`, and package-export tests under `ts/jqx/test/`.
- Adapter public-contract work will center on `ts/adapter-core/src/index.ts` plus the three adapter `src/index.ts` files and their tests.
- Documentation alignment will primarily touch `ts/jqx/README.md`, `ts/zod-adapter/README.md`, `ts/yup-adapter/README.md`, and `ts/valibot-adapter/README.md`.

</code_context>

<specifics>
## Specific Ideas

- The best public story is: install `@shina1024/jqx`, one adapter package, and one validator package explicitly.
- `@shina1024/jqx` should stay easy to explain as the runtime package, while adapter packages stay optional integration layers built on top.
- Removing main-package adapter subpaths is preferable to keeping convenience aliases because the project should converge on one obvious public spelling per adapter surface.
- The main quick start for every adapter should look like `createAdapter(runtime).filter(...)`; custom runtime injection remains supported but is not the first story.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-schema-adapter-packages*
*Context gathered: 2026-03-20*
