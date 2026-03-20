# Phase 4: CLI Workflow Parity - Research

**Researched:** 2026-03-20
**Domain:** jq-compatible native CLI workflows, command identity, and parity proof
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Treat stdin and exactly one direct input argument as the two canonical CLI input workflows for this phase.
- Keep direct input jq-style and narrow; Phase 4 must not grow into multi-argument or jqx-only CLI input extensions.
- Keep input normalization in the CLI adapter layer while compile and evaluate semantics remain owned by the shared core.
- `jqx` is the canonical user-facing command name for help text, examples, and docs.
- `moon run --target native cmd -- ...` remains a contributor and testing workflow, not the normal user-facing CLI identity.
- Treat partial output preservation before runtime errors as part of the parity contract.
- Treat jq-compatible observable error behavior and stable nonzero exit paths as in scope now.
- Keep `-e` behavior regression-protected rather than deferred.
- The Phase 4 option surface is stdin and direct input plus `-r`, `-R`, `-s`, `-n`, `-e`, with existing `-L` support kept but secondary.
- Do not add new jqx-only CLI flags or convenience behaviors in this phase.

### Claude's Discretion
- Exact wording and ordering of help text and README examples once `jqx` is the canonical command name.
- Exact stdout and stderr plumbing needed to preserve jq-compatible observable behavior while keeping current harnesses useful.
- Exact regression coverage to add around direct input, raw and slurp combinations, partial outputs, and module-path behavior.

### Deferred Ideas (OUT OF SCOPE)
- Broader CLI argument forms beyond one optional direct input value.
- New jqx-only flags or convenience workflows.
- Release workflow publication work beyond the command-identity and smoke-test contracts already needed for Phase 4 planning.
</user_constraints>

<research_summary>
## Summary

Phase 4 is not blocked on a missing CLI evaluator. The current repo already implements the core workflow surface and the maintained jq differential corpus is fully green.

Verified current state:
- `moon test cmd` passes locally (`52/52`).
- `node scripts/jq_diff.mjs` passes locally (`248/248`), including the maintained CLI cases for stdin, direct input, `-r`, `-R`, `-s`, `-n`, and `-e`.
- `cmd/main.mbt` already normalizes stdin vs direct-input text, raw-line mode, JSON stream parsing, slurp behavior, BOM handling, and whitespace-separated JSON streams.
- `cmd/main_cli.mbt` already compiles through `@lib.compile(...)`, executes through `@lib.execute_for_cli(...)`, preserves partial outputs before runtime errors, and computes jq-style `-e` exit status from the output stream.
- The CLI release workflow already packages the built binary as `jqx` even though the build artifact path remains `_build/native/.../cmd/cmd(.exe)`.

The primary planning implication is that Phase 4 should focus on contract consolidation and regression-proof, not on inventing new CLI semantics. The real remaining work is:

1. align user-facing help and examples with the canonical `jqx` command name instead of the current `moon run --target native cmd -- ...` usage text
2. keep the adapter-vs-core boundary explicit so CLI transport logic does not drift into surface-local semantics
3. strengthen proof around user-visible workflows and error-path behavior so the already-green maintained corpus remains explainable and regression-resistant
4. ensure docs, native smoke paths, and maintained parity assets all tell the same CLI story

**Primary recommendation:** Plan Phase 4 around two focused slices:
- `04-01` should own the CLI contract surface: usage text, input and output normalization touchpoints, error rendering, and regression coverage that proves those behaviors still flow through the shared core.
- `04-02` should own common option parity and proof hardening: maintained jq cases, module-path and direct-input workflows, native smoke expectations, and regression assets that prevent Phase 4 from quietly drifting back toward surface-local patches.
</research_summary>

<standard_stack>
## Standard Stack

The established libraries and tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `cmd/args.mbt` | repo current | Parses CLI options, filter text, and the optional direct input argument | This is already the CLI argument boundary |
| `cmd/main.mbt` | repo current | Normalizes raw and JSON inputs, stream splitting, slurp, and BOM handling | This is already where CLI transport behavior lives |
| `cmd/main_cli.mbt` | repo current | Usage text, module-search-path setup, compile and run orchestration, error rendering, and exit-status behavior | This is the user-visible CLI contract surface |
| `cmd/output.mbt` | repo current | jq-style output formatting for raw vs JSON output | This is the formatting seam for `-r` behavior |
| `shina1024/jqx/core` | repo current | Shared jq-compatible compile and execution semantics | Phase 4 must keep semantics here, not in the CLI wrapper |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `cmd/args_wbtest.mbt` | repo current | Argument parsing regressions | Use for option parsing and direct-input argument rules |
| `cmd/main_wbtest.mbt` | repo current | CLI workflow and error-path regressions | Use for input normalization, exit status, and error ordering proof |
| `cmd/main_native_wbtest.mbt` | repo current | Native-only module-path proof | Use when `-L` or native runtime behavior is relevant |
| `cmd/output_wbtest.mbt` | repo current | Raw vs JSON output formatting proof | Use for `-r` coverage |
| `scripts/jq_compat_cases.json` | repo current | Maintained jq compatibility cases, including CLI workflows | Use for strict jq differential proof rather than ad hoc snapshots |
| `scripts/jq_diff.mjs` | repo current | Native CLI differential harness against jq 1.8.1 | Use for maintained parity proof and native smoke validation |
| `.github/workflows/release-cli.yml` | repo current | Release-profile build and `jqx` packaging smoke path | Use as the canonical artifact-name contract for CLI docs and packaging language |
| `README.mbt.md` | repo current | Public CLI quick-start and examples | Use to align help text and docs around `jqx` |
| `moon test cmd` | local verified | Fast CLI regression loop | Already green in this checkout and should remain the default task-level check |
| `node scripts/jq_diff.mjs` | local verified | Maintained jq parity proof | Already green in this checkout and should stay part of the phase gate |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Keeping CLI transport in `cmd` | Moving stdin and direct-input normalization into `core` | Would blur the shared-core boundary and make the CLI own semantic patches indirectly |
| Tightening proof via maintained differential cases | Relaxed snapshots of CLI output or broader skip rules | Easier short term, but it weakens the jq-compatibility contract |
| Canonicalizing help and docs around `jqx` | Keeping `moon run --target native cmd -- ...` as the public-facing examples | Convenient for contributors, but wrong for end users and inconsistent with README and release packaging |
| Reusing the existing native harness | Writing separate one-off smoke scripts for each option | Duplicates proof paths and increases drift risk |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Pattern 1: CLI adapter owns transport, core owns semantics
**What:** Parse args and normalize text inputs in `cmd`, then compile and execute through the shared core.
**When to use:** For stdin vs direct-input routing, raw-input handling, and stream splitting.
**Example:**
```mbt
let compiled = @lib.compile(cfg.filter)
let inputs = parse_cli_inputs(cfg, cli_stdin)
let result = @lib.execute_for_cli(compiled, input)
```

### Pattern 2: Direct input is a narrow jq-style lane
**What:** Accept either stdin or one direct input argument, not a widened multi-argument CLI surface.
**When to use:** For argument parsing, README examples, and maintained parity cases.
**Example:**
```mbt
let input = if idx < args.length() {
  let value = args[idx]
  idx += 1
  if idx < args.length() {
    return Err("too many arguments")
  }
  Some(value)
} else {
  None
}
```

### Pattern 3: Observable error behavior preserves prior outputs
**What:** Runtime errors still report jq-style error lines while retaining earlier successfully produced outputs.
**When to use:** For `run_cli(...)`, differential cases, and wbtests.
**Example:**
```mbt
append_json_output_values(outputs, result.0)
match result.1 {
  Some(msg) => {
    let lines = render_error_lines(msg)
    append_output_lines(lines, cfg.raw, outputs)
    return { lines, exit_code: Some(5) }
  }
  None => ()
}
```

### Pattern 4: Canonical command name vs contributor execution path
**What:** User-facing text says `jqx`, while contributor tooling may still use `moon run ... cmd --` or the raw build artifact path.
**When to use:** For usage text, README examples, native smoke tests, and release workflow references.
**Example:**
- `README.mbt.md` already documents `jqx ...`
- `.github/workflows/release-cli.yml` copies `_build/native/.../cmd(.exe)` to `dist/jqx(.exe)`
- `cmd/main_cli.mbt` still shows `moon run --target native cmd -- ...` in usage text today

## Validation Architecture

Phase 4 validation should stay CLI-specific but still honor the repo-wide quality gate order.

- **Fast loop:** `moon test cmd`
- **Shared gate:** `moon info`, `moon fmt`, `moon check`, `moon test`
- **CLI parity gate:** `node scripts/jq_diff.mjs`
- **Native artifact smoke:** rely on `scripts/jq_diff.mjs` default native runner and the existing release-workflow smoke expectations

The planner should assume every Phase 4 plan needs verification that touches both:
- focused package-level CLI regressions in `cmd/*_wbtest.mbt`
- maintained jq differential proof through `scripts/jq_compat_cases.json` and `scripts/jq_diff.mjs`

Current local finding:
- `moon test cmd` passed in this checkout
- `node scripts/jq_diff.mjs` passed in this checkout with `248/248`

That means Wave 0 test infrastructure is already present. Phase 4 planning should add or adjust proof where the user-facing CLI contract is still under-specified, not build new infrastructure from scratch.
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

Problems that look simple but already have the right repo-level solution:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CLI evaluator behavior | Surface-local execution shortcuts in `cmd` | `@lib.compile(...)` and `@lib.execute_for_cli(...)` from the shared core | Shared semantics are the project contract |
| Input stream parsing | Separate ad hoc parsers per option combination | `parse_cli_inputs(...)`, `parse_json_stream_values(...)`, and `parse_raw_lines(...)` | The existing transport logic already covers the maintained CLI cases |
| Parity proof | Relaxed snapshots or widened skip logic | Maintained jq differential cases in `scripts/jq_compat_cases.json` | AGENTS.md rejects weakened compatibility proof |
| Command identity | Telling users to invoke `moon run --target native cmd -- ...` as the public CLI | `jqx` in help text, docs, and packaged artifacts | The locked decision already chose `jqx` as the public command name |
| Error-path checks | Only unit tests or only shell smoke tests | Both wbtests and maintained jq differential proof | User-visible error ordering is part of the phase contract |
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Moving CLI transport rules into the semantic core
**What goes wrong:** Stream splitting, raw-input record handling, or direct-input routing migrate into `core`, making the CLI a hidden semantic owner.
**Why it happens:** The CLI already has working behavior, so it can be tempting to "clean it up" by centralizing everything.
**How to avoid:** Keep transport and process-level behavior in `cmd`; only jq evaluation semantics belong in `core`.

### Pitfall 2: Public docs and help text disagree about the command name
**What goes wrong:** README says `jqx`, usage text says `moon run --target native cmd -- ...`, and release artifacts ship `jqx`.
**Why it happens:** Contributor workflows leak into the user-facing contract.
**How to avoid:** Make `jqx` the public story everywhere users read first, while keeping contributor execution paths secondary.

### Pitfall 3: Treating the green differential corpus as permission to weaken proof
**What goes wrong:** Because `248/248` is already green, the phase stops maintaining strict jq comparison and starts relying on looser checks.
**Why it happens:** The visible code gaps look small, so proof can seem optional.
**How to avoid:** Treat the existing green corpus as the baseline that must be preserved and extended only with equally strict checks.

### Pitfall 4: Over-expanding Phase 4 into release or packaging work
**What goes wrong:** The plan drifts into full CLI publication work, artifact distribution changes, or broader release automation.
**Why it happens:** Command identity and packaged binary naming are close to release concerns.
**How to avoid:** Limit Phase 4 to the user-visible CLI workflow contract and its proof. Full release readiness remains Phase 6.

### Pitfall 5: Adding jqx-only conveniences while touching CLI ergonomics
**What goes wrong:** New flags or argument forms sneak in under the banner of usability.
**Why it happens:** CLI cleanup work often invites small extensions.
**How to avoid:** Keep Phase 4 strictly on jq-compatible workflows and the locked option set.
</common_pitfalls>

<code_examples>
## Code Examples

Verified patterns from current repo sources:

### Current CLI usage text is still contributor-oriented
```mbt
fn usage_summary_line() -> String {
  "Usage: moon run --target native cmd -- [options] \"<filter>\" [\"<json>\"]"
}
```

### Current CLI already routes semantics through the shared core
```mbt
let compiled = @lib.compile(cfg.filter)
let inputs = parse_cli_inputs(cfg, cli_stdin)
let result = @lib.execute_for_cli(compiled, input)
```

### Current release workflow already packages the public binary name as `jqx`
```yaml
CLI_BIN="_build/native/release/build/cmd/cmd"
cp "${CLI_BIN}" "dist/jqx"
```

### Current maintained differential corpus already covers the target Phase 4 option set
```json
{ "name": "cli-raw-string-output", "jqx_args": ["-r"] }
{ "name": "cli-raw-lines", "jqx_args": ["-R"] }
{ "name": "cli-slurp-ndjson", "jqx_args": ["-s"] }
{ "name": "cli-no-input", "jqx_args": ["-n"], "jqx_use_stdin": true }
{ "name": "cli-exit-status-empty", "jqx_args": ["-e"], "jqx_use_stdin": false }
```
</code_examples>

<open_questions>
## Open Questions

1. **How far should Phase 4 go on command identity cleanup?**
   - What we know: the public command name is locked as `jqx`, README already uses it, and release packaging already emits `jqx`.
   - What is unclear: whether any contributor-only wording should remain in help text or whether it should move entirely to contributor docs.
   - Recommendation: make help and README fully `jqx`-first; keep `moon run` only in contributor-oriented material if needed.

2. **Which user-visible workflows still need explicit regression proof beyond the already-green maintained corpus?**
   - What we know: the maintained corpus already covers the target flag set and common stdin/direct-input workflows.
   - What is unclear: whether help text, usage errors, and direct-input examples are adequately pinned by current wbtests.
   - Recommendation: prioritize proof for command identity, usage/error wording, and any direct-input or partial-output cases that are user-visible but not yet tightly asserted.

3. **Should native artifact naming appear in Phase 4 execution work or remain only an external workflow fact?**
   - What we know: the release workflow already packages `jqx`, while native build directories still expose `cmd`.
   - What is unclear: whether any repo-local scripts or docs besides README need adjustment to keep the contract coherent.
   - Recommendation: keep Phase 4 focused on observable command identity and smoke assumptions; do not widen into full release-automation changes unless a mismatch blocks the CLI story.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `AGENTS.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/PROJECT.md`
- `.planning/phases/04-cli-workflow-parity/04-CONTEXT.md`
- `.planning/phases/01-shared-core-and-compatibility/01-02-SUMMARY.md`
- `.planning/phases/01-shared-core-and-compatibility/01-03-SUMMARY.md`
- `cmd/args.mbt`
- `cmd/main.mbt`
- `cmd/main_cli.mbt`
- `cmd/output.mbt`
- `cmd/args_wbtest.mbt`
- `cmd/main_wbtest.mbt`
- `cmd/main_native_wbtest.mbt`
- `cmd/output_wbtest.mbt`
- `scripts/jq_compat_cases.json`
- `scripts/jq_diff.mjs`
- `.github/workflows/release-cli.yml`
- `README.mbt.md`

### Secondary (HIGH confidence local verification)
- local shell verification in this checkout: `moon test cmd` passed (`52/52`)
- local shell verification in this checkout: `node scripts/jq_diff.mjs` passed (`248/248`)
</sources>

<metadata>
## Metadata

**Research scope:**
- CLI argument and input normalization boundary
- shared-core execution ownership for CLI behavior
- help text and command identity contract
- maintained jq parity proof and native smoke path

**Confidence breakdown:**
- Existing CLI semantic coverage: HIGH
- Shared-core boundary assessment: HIGH
- Command-identity and help-text gap: HIGH
- Exact remaining execution scope: MEDIUM-HIGH

**Research date:** 2026-03-20
**Valid until:** 2026-04-19
</metadata>

---

*Phase: 04-cli-workflow-parity*
*Research completed: 2026-03-20*
*Ready for planning: yes*
