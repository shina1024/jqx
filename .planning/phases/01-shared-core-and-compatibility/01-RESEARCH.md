# Phase 1: Shared Core and Compatibility - Research

**Researched:** 2026-03-12
**Domain:** MoonBit jq-compatible semantic core hardening, differential verification, and CI shaping
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Temporary compatibility exceptions are acceptable during Phase 1, including during breaking refactors.
- Every temporary exception must be visible from both tests and user-facing documentation.
- Each exception must record not only the reason it exists, but also the condition that would allow it to be removed.
- Temporary CI failures caused by breaking changes are acceptable during the phase, but Phase 1 must end with CI passing again.
- Phase 1 completion requires both green CI and explainable jq-difference results.
- The compatibility oracle should use both the maintained repository cases and upstream jq-derived cases.
- Pushes are allowed and expected at meaningful milestones so CI can be checked during the phase.
- The current CI shape is not fixed. If a workflow is excessive it may be removed or reduced; if verification is missing it should be added.
- Large architectural or package/module reorganization is allowed in Phase 1 if it improves the shared-core design.
- Package names, module names, and public/private placement may change when needed to clarify the shared semantic core.
- During the migration, temporary surface-side adjustments are acceptable for practicality.
- The end state must still converge back to one shared semantic core, with surface-specific layers limited to I/O, packaging, and ergonomic adaptation rather than semantic divergence.

### Claude's Discretion
- Exact CI changes to remove over-checking or add missing verification.
- Exact sequencing of compatibility fixes versus structural refactors.
- Exact package, module, and file moves needed to clarify the shared core.
- Exact format and placement of compatibility ledgers, exception docs, and supporting test metadata.

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.
</user_constraints>

<research_summary>
## Summary

Phase 1 should not add new runtime technologies. The repo already contains the essential pieces for a jq-compatible shared core: a custom JSON value model with preserved numeric representations and key ordering in `core/jqx.mbt`, surface wrappers in `jqx.mbt`, `cmd/`, and `ts/jqx/`, and a jq-oracle differential harness in `scripts/jq_diff*.sh`. The work is to consolidate these into a more explicit semantic center, remove accidental surface ownership of behavior, and align CI with the repo's actual quality gate.

The main planning implication is to structure Phase 1 into three complementary tracks: compatibility corpus and exception tracking, shared-core boundary refactor, and proof infrastructure. Those tracks can overlap, but the proof track must be present from the start so that refactors are continuously measured against jq and cross-surface fidelity expectations.

**Primary recommendation:** Treat `core/` plus the compatibility scripts as the invariant center, refactor surface wrappers around that center, and make CI prove only the checks that directly support jq parity, cross-surface fidelity, and the documented MoonBit/TS quality gate.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries/tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MoonBit module layout in `core/`, `cmd/`, `js/`, top-level package | repo current | Houses the parser, evaluator, CLI, JS-target output, and public wrappers | This is already the project's real implementation stack; Phase 1 should tighten it rather than replace it |
| jq differential harness (`scripts/jq_diff.sh`, `scripts/jq_diff_native.sh`) | repo current | Compares jqx behavior against jq 1.8.1 | jq compatibility claims need an oracle, and these scripts already encode that contract |
| Maintained compat corpora (`scripts/jq_compat_cases*.json`, `third_party/jq-tests/`) | repo current | Curated and imported case sources for compatibility measurement | They combine project-owned coverage with upstream reality |
| GitHub Actions CI (`.github/workflows/ci.yml`) | repo current | Cross-platform regression gate | Phase 1 should reshape this into a sharper compatibility and quality proof, not invent a new CI system |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `moon info`, `moon fmt`, `moon check`, `moon test` | toolchain current | Required quality gate from repo policy | Use as the canonical MoonBit gate, and reflect that order in CI where practical |
| `bash ./scripts/ts_packages.sh verify --frozen-lockfile` | repo current | Verifies TS workspace packaging and tests | Keep for Linux CI and for any Phase 1 change that touches JS/TS packaging boundaries |
| `scripts/jq_upstream_import.sh` | repo current | Refreshes and validates imported upstream cases | Use when touching upstream-driven compatibility coverage or ledgers |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing jq differential scripts | Rewrite the compatibility harness from scratch | Would lose existing case semantics and slow Phase 1 with avoidable tooling churn |
| Current shared JSON model with preserved repr/order | Host-language JSON objects at surface boundaries | Simpler wrappers, but breaks the phase goal around fidelity and shared semantics |
| Current multi-OS CI plus focused differential checks | Broader generic test expansion | More cost and noise without proving the phase requirements any better |

**Installation:**
```bash
# MoonBit quality gate
moon info
moon fmt --check
moon check -d
moon test

# TS / compatibility verification
bash ./scripts/ts_packages.sh verify --frozen-lockfile
bash ./scripts/jq_diff.sh
bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json
bash ./scripts/jq_diff_native.sh
```
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Recommended Project Structure
```text
core/                  # semantic center: JSON model, parser, filter IR, evaluator, builtins
top-level jqx package  # MoonBit public value/text lanes over the core
cmd/                   # CLI argv/stdin/stdout adaptation only
js/                    # JS-target MoonBit bridge
ts/jqx/                # npm packaging and runtime wrappers
scripts/               # jq oracle and package verification harness
.github/workflows/     # CI proof surface
```

### Pattern 1: Semantic-core ownership
**What:** Keep jq meaning in one place: the `Value` model, parser, compiler, evaluator, and builtin logic.
**When to use:** For every behavior change that could affect jq parity or cross-surface fidelity.
**Example:**
```mbt
// Source: core/jqx.mbt
pub enum Value {
  JNull
  JTrue
  JFalse
  Number(Double, String?)
  String(String)
  Array(Array[Value])
  Object(JsonObject)
}
```

### Pattern 2: Thin surface adaptation
**What:** Wrappers translate I/O and public API shape, but do not own semantics.
**When to use:** For CLI parsing/output, MoonBit public API shaping, and JS/TS runtime conversion.
**Example:**
```mbt
// Source: jqx.mbt
pub fn run(filter : StringView, input : Json) -> Array[Json] raise JqxError {
  let compiled = compile(filter) catch { err => raise Compile(err) }
  compiled.run(input) catch {
    err => raise Runtime(err)
  }
}
```

### Pattern 3: Oracle-backed proof
**What:** Differential checks compare jqx outputs, errors, and exits against jq instead of relying only on unit tests.
**When to use:** On compatibility corpus changes, core refactors, and CI gating.
**Example:**
```bash
# Source: scripts/jq_diff.sh
bash ./scripts/jq_diff.sh
bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json
bash ./scripts/jq_diff_native.sh
```

### Anti-Patterns to Avoid
- **Surface-local semantic patches:** fixing CLI or TS behavior without moving the actual rule into the shared core
- **Untracked exception debt:** allowing differential failures without a machine-visible case/ledger plus human-visible explanation
- **CI as a dumping ground:** keeping expensive jobs that do not directly prove Phase 1 requirements
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| jq compatibility proof | A new bespoke comparison tool | `scripts/jq_diff.sh` / `scripts/jq_diff_native.sh` + existing case files | The repo already encodes jq-vs-jqx comparison rules, error normalization, and case metadata |
| Cross-surface JSON semantics | Separate JSON models per surface | `core/jqx.mbt` `Value` + repr/order preservation | Separate models create drift immediately, especially around numbers and object order |
| Exception tracking | Ad hoc TODOs or issue-only notes | Case metadata + dedicated ledger/docs tied to the compat corpus | Phase 1 requires tests + docs visibility, not informal memory |
| CI proof of quality gate | Generic smoke-only CI | Explicit MoonBit gate plus differential and TS verification | The repo already knows which checks matter; Phase 1 should sharpen them, not abstract them away |

**Key insight:** Phase 1 is primarily a consolidation phase. Existing repo assets are already the right raw materials; the risk is fragmentation and inconsistent proof, not missing libraries.
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Refactor drift hidden by passing unit tests
**What goes wrong:** Core or surface refactors appear safe locally but subtly diverge from jq in error text, exits, or numeric formatting.
**Why it happens:** Unit tests only cover project-known cases, while jq parity needs oracle comparison.
**How to avoid:** Keep differential checks on maintained and upstream case sets running throughout the phase, especially after structural moves.
**Warning signs:** `moon test` passes but `jq_diff` or native exit comparisons start diverging.

### Pitfall 2: Shared core in name only
**What goes wrong:** The repo still claims a shared core, but wrappers start containing behavior-only patches for their own surfaces.
**Why it happens:** Surface files feel easier to modify than the semantic center.
**How to avoid:** Treat any semantic fix in `cmd/`, `jqx.mbt`, `js/`, or `ts/jqx/` as suspicious unless it is purely I/O or packaging.
**Warning signs:** A bug fix changes wrapper behavior without a matching core or corpus change.

### Pitfall 3: CI noise blocks useful iteration
**What goes wrong:** Engineers stop trusting CI because jobs are too broad, redundant, or detached from Phase 1 requirements.
**Why it happens:** CI grows historically and is rarely pruned.
**How to avoid:** Keep jobs that prove MoonBit quality gate, differential parity, TS packaging integrity, and multi-OS smoke coverage; trim checks that duplicate those signals without adding confidence.
**Warning signs:** CI runtime grows while failures teach little about compatibility or shared-core correctness.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Shared JSON fidelity boundary
```mbt
// Source: core/jqx.mbt
pub fn Value::to_json_string(self : Value) -> String {
  // Uses repr when preserved, keeps jq-style compact JSON output,
  // and respects object key order from the shared JSON model.
}
```

### CLI input normalization as adaptation layer
```mbt
// Source: cmd/main.mbt
fn parse_cli_inputs(
  cfg : CliArgs,
  stdin_text : String,
) -> Array[@lib.Value] raise @lib.ParseError {
  if cfg.no_input {
    [@lib.Value::null()]
  } else {
    // CLI-specific raw/slurp/stdin handling
  }
}
```

### JS/TS direct runtime as wrapper over MoonBit bridge
```ts
// Source: ts/jqx/src/direct_runtime.ts
export function run(filter: string, input: Json): JqxResult<Json[], JqxRuntimeError> {
  const encoded = encodeRuntimeInput(input);
  if (!encoded.ok) return encoded;
  const runtimeOut = runJsonText(filter, encoded.value);
  if (!runtimeOut.ok) return runtimeOut;
  return decodeRuntimeOutputs(runtimeOut.value);
}
```
</code_examples>

<sota_updates>
## State of the Art (2024-2026)

What's changed recently:

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Treating surface wrappers as semi-independent | Treating them as thin adapters around one semantic center | This repo's current direction | Phase 1 should formalize and finish this move |
| Generic CI “test job only” thinking | Differential jq-oracle checks plus packaging checks | Already encoded in repo scripts/workflows | Compatibility phases need proof closer to behavior, not just compilation |
| Passive API compatibility debt | Pre-1.0 cleanup with deliberate breaking changes | Current project stance | Phase 1 can safely reorganize internals and boundaries if it improves the shared core |

**New tools/patterns to consider:**
- **Compatibility ledger tied to cases:** a structured doc or metadata layer that explains every temporary jq difference and its removal condition
- **CI reduction with purpose:** collapsing redundant matrix work if it does not add proof beyond Linux oracle + cross-OS smoke

**Deprecated/outdated:**
- **Undocumented one-off compatibility skips:** not acceptable for this project direction
- **Assuming current package layout is fixed:** Phase 1 explicitly allows reorganization
</sota_updates>

## Validation Architecture

Phase 1 validation should be split into fast local proof and slower oracle proof:

- **Fast loop:** `moon info`, `moon fmt --check`, `moon check -d`, targeted `moon test --target native core`, targeted `moon test --target native cmd`, and focused JS tests when wrappers change
- **Wave-level loop:** `moon test`, `bash ./scripts/ts_packages.sh verify --frozen-lockfile`, `bash ./scripts/jq_diff.sh`, `bash ./scripts/jq_diff.sh scripts/jq_compat_cases.upstream.json`, `bash ./scripts/jq_diff_native.sh`
- **CI principle:** keep the final gate green by the end of the phase, but allow temporary breakage during large refactors
- **Artifact principle:** compatibility exceptions must be reviewable from both automated case data and human-facing docs/ledger

The planner should assume that Phase 1 plans must either preserve this validation path or improve it. Any CI edits in the phase must be justified by sharper proof, lower redundancy, or lower maintenance cost.

<open_questions>
## Open Questions

1. **How much of the current CI matrix is redundant for Phase 1?**
   - What we know: Linux carries the heaviest compatibility proof, while additional OS jobs mostly provide smoke coverage today.
   - What's unclear: Which jobs are genuinely catching cross-platform issues versus duplicating Linux signal.
   - Recommendation: Include an explicit CI audit task early in the phase and allow plan output to remove or reshape redundant jobs.

2. **Where should the compatibility exception ledger live?**
   - What we know: tests + docs visibility is mandatory, and the repo already has case JSON files plus upstream ledgers.
   - What's unclear: whether to extend existing ledgers or add a new Phase 1-specific doc.
   - Recommendation: Planner should choose the lowest-friction option that keeps machine-readable linkage to case files.

3. **How aggressive should initial structural moves be?**
   - What we know: large reorganizations are allowed.
   - What's unclear: whether an early big move or staged extraction is the cheaper path once planning inspects file ownership.
   - Recommendation: Prefer staged plans unless planner finds a single large move is cleaner and still keeps milestone CI observability.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `core/jqx.mbt` - shared JSON model, parser, fidelity behavior, and ordering semantics
- `jqx.mbt` - current MoonBit public wrappers and value/text lanes
- `cmd/main.mbt` - CLI adaptation layer and input parsing
- `ts/jqx/src/direct_runtime.ts` - JS/TS runtime wrapper over the MoonBit bridge
- `scripts/jq_diff.sh`, `scripts/jq_diff_native.sh` - jq oracle proof harness
- `scripts/jq_compat_cases.json`, `scripts/jq_compat_cases.upstream.json`, `third_party/jq-tests/` - compatibility corpora
- `.github/workflows/ci.yml`, `.github/workflows/release-cli.yml`, `.github/workflows/release-npm.yml` - existing CI and release proof surfaces
- `AGENTS.md` - explicit constraints on jq 1.8.1 compatibility, JSON model ordering, public API cleanup, and validation order

### Secondary (MEDIUM confidence)
- `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/phases/01-shared-core-and-compatibility/01-CONTEXT.md` - project-level Phase 1 constraints and goals
</sources>

<metadata>
## Metadata

**Research scope:**
- Core technology: MoonBit semantic core and wrappers
- Ecosystem: jq oracle scripts, GitHub Actions CI, TS verification harness
- Patterns: shared-core ownership, thin surface adaptation, oracle-backed proof
- Pitfalls: refactor drift, surface-local semantics, CI noise

**Confidence breakdown:**
- Standard stack: HIGH - based on current repo architecture rather than speculative changes
- Architecture: HIGH - grounded in current file ownership and project constraints
- Pitfalls: HIGH - directly tied to repo shape and Phase 1 goals
- Code examples: HIGH - drawn from current source files

**Research date:** 2026-03-12
**Valid until:** 2026-04-11
</metadata>

---

*Phase: 01-shared-core-and-compatibility*
*Research completed: 2026-03-12*
*Ready for planning: yes*
