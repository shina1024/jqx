# Phase 4: CLI Workflow Parity - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Finish the jq-compatible native CLI workflows on top of the shared core. This phase covers stdin and direct-input execution, the common jq option set promised by the roadmap, user-facing CLI help/examples, and observable output/error/exit behavior. It does not add CLI-only capabilities or broaden the CLI beyond jq compatibility.

</domain>

<decisions>
## Implementation Decisions

### Input workflows
- Treat stdin and exactly one direct input argument as the two canonical CLI input workflows for this phase.
- Keep direct input jq-style and narrow; Phase 4 should not grow into broader multi-argument or jqx-specific input extensions.
- Keep input normalization in the CLI adapter layer while compile/evaluate semantics remain owned by the shared core.

### User-facing CLI identity
- `jqx` is the canonical user-facing command name for help text, examples, and docs.
- `moon run --target native cmd -- ...` remains a contributor/testing workflow, not the normal user-facing CLI identity.
- CLI usage text and README examples should align on the same public command spelling.

### Error and exit behavior
- Treat partial output preservation before runtime errors as part of the Phase 4 parity contract.
- Treat jq-compatible observable error behavior, including clear value-output vs error-reporting behavior and stable nonzero exit paths, as in-scope now rather than later cleanup.
- Keep `-e` behavior as explicit regression-protected parity work rather than a deferred CLI polish item.

### Public option surface for this phase
- The polished Phase 4 workflow story centers on stdin/direct input plus `-r`, `-R`, `-s`, `-n`, and `-e`, matching roadmap and requirements scope.
- Keep `-L` supported because it already exists in code and tests, but treat it as a secondary workflow behind the common jq option set.
- Do not add new jqx-only CLI flags or convenience behaviors in this phase.

### Claude's Discretion
- Exact wording and ordering of help text and README examples once `jqx` is the canonical command name.
- Exact stdout/stderr plumbing needed to preserve jq-compatible observable behavior while keeping the current harnesses useful.
- Exact regression coverage to add around direct input, raw/slurp combinations, partial outputs, and module-path behavior.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 4 goal, success criteria, and plan split for CLI workflow parity.
- `.planning/REQUIREMENTS.md` — `CLI-01` and `CLI-02` define the required CLI workflows and common jq option coverage.
- `.planning/PROJECT.md` — project-level rule that the CLI stays jq-compatible and does not become an extension surface.

### Prior shared-core boundary decisions
- `.planning/phases/01-shared-core-and-compatibility/01-CONTEXT.md` — shared-core ownership and thin-surface boundary established in Phase 1.
- `.planning/phases/01-shared-core-and-compatibility/01-02-SUMMARY.md` — confirms CLI stream segmentation stays adapter-side rather than moving semantic ownership out of `core`.
- `.planning/phases/01-shared-core-and-compatibility/01-03-SUMMARY.md` — documents native CLI differential proof and the fact that `-e` parity is already treated as regression-protected behavior.

### Current public CLI contract and proof assets
- `README.mbt.md` — current advertised `jqx` CLI quick-start and option examples that Phase 4 should make fully true.
- `scripts/jq_compat_cases.json` — maintained CLI parity cases for stdin/direct input, `-r`, `-R`, `-s`, `-n`, `-e`, and order-sensitive CLI-visible behavior.
- `scripts/jq_diff.mjs` — differential harness that defines the current jq-vs-jqx CLI proof path and native-vs-moon-run execution shape.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cmd/args.mbt`: parses `-r`, `-R`, `-s`, `-n`, `-e`, `-L`, the filter, and the optional direct input argument.
- `cmd/main.mbt`: owns CLI-side input normalization for JSON stream parsing, raw-line parsing, slurp handling, BOM skipping, and whitespace-separated stdin values.
- `cmd/main_cli.mbt`: owns usage text, stdin detection, module-search-path setup, CLI run orchestration, error formatting, and exit-status calculation.
- `cmd/args_wbtest.mbt`, `cmd/main_wbtest.mbt`, `cmd/main_native_wbtest.mbt`, `cmd/output_wbtest.mbt`: already give package-level regression coverage for CLI parsing and behavior.
- `scripts/jq_compat_cases.json` and `scripts/jq_diff.mjs`: already provide maintained jq differential proof for the exact workflow area Phase 4 is hardening.

### Established Patterns
- CLI-specific stream segmentation and transport behavior live in `cmd`, while compile/evaluate semantics remain delegated to `core`.
- CLI runs clear and then set module search paths per invocation, defaulting to `"."` when `-L` is not supplied.
- Maintained parity cases already encode common CLI workflows as strict jq comparisons rather than relaxed snapshots.
- Public docs already speak in terms of the `jqx` command even though current usage text still exposes `moon run --target native cmd -- ...`.

### Integration Points
- Phase 4 planning should center on `cmd/args.mbt`, `cmd/main.mbt`, `cmd/main_cli.mbt`, README CLI examples, and the maintained/differential CLI proof scripts.
- CLI execution currently flows through `@lib.compile(...)` and `@lib.execute_for_cli(...)`; new parity work should keep using those shared-core entrypoints rather than adding wrapper-only semantics.
- Any user-facing command-name cleanup must stay aligned with the eventual native artifact name and with the existing `cmd` package build/test paths.

</code_context>

<specifics>
## Specific Ideas

- User accepted the recommended defaults for all identified Phase 4 gray areas.
- The intended public story is one obvious command name, `jqx`, plus jq-style common workflows rather than a developer-oriented `moon run` narrative.
- Error-path behavior should be treated as user-visible parity work, not as an implementation detail that can remain loosely defined.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-cli-workflow-parity*
*Context gathered: 2026-03-20*
