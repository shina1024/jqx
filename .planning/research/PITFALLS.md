# Pitfalls Research

**Domain:** MoonBit-based jq-compatible runtime published as CLI, JS/TS library, and MoonBit library
**Researched:** 2026-03-12
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Surface semantic drift

**What goes wrong:**
The same filter produces different results, errors, or ordering depending on whether it runs through the CLI, JS/TS, or MoonBit API.

**Why it happens:**
Surface wrappers start carrying local behavior fixes because they are easier to change than the core.

**How to avoid:**
Keep semantics in one shared core, keep wrappers thin, and add cross-surface regression tests whenever a mismatch is fixed.

**Warning signs:**
Bug fixes land in `cmd` or `ts/*` without matching core changes, or docs start describing behavior per surface.

**Phase to address:**
Phase 1 - semantic core and compatibility harness

---

### Pitfall 2: JSON fidelity loss at the public boundary

**What goes wrong:**
Large integers, raw strings, formatting-sensitive outputs, or key ordering drift once data is converted through host-language value types too early.

**Why it happens:**
It is tempting to normalize everything into convenient host values before the runtime has finished compatibility-sensitive work.

**How to avoid:**
Make the JSON-text lane first-class, keep the shared JSON value model explicit, and test value lane and text lane separately.

**Warning signs:**
Compatibility failures cluster around big numbers, raw output, or object ordering; library APIs hide whether they are using text or value semantics.

**Phase to address:**
Phase 1 - semantic core and compatibility harness

---

### Pitfall 3: Hidden compatibility exceptions

**What goes wrong:**
The project claims jq compatibility while silently skipping cases, weakening comparison logic, or leaving version-specific behavior undocumented.

**Why it happens:**
Compatibility gaps are expensive, and it is easy to soften tests instead of fixing semantics.

**How to avoid:**
Treat jq 1.8.1 as a fixed oracle, document every temporary exception, and keep skips narrow and removable.

**Warning signs:**
Broad test skips, fuzzy output matching, or docs that say "mostly compatible" without a precise boundary.

**Phase to address:**
Phase 1 - semantic core and compatibility harness

---

### Pitfall 4: Public API debt before release

**What goes wrong:**
Alias exports, mixed naming conventions, or leaky core types make docs and package surfaces harder to stabilize.

**Why it happens:**
Convenience aliases accumulate while the project is still exploring the right public shape.

**How to avoid:**
Choose canonical names early, expose standard `Json` at the MoonBit boundary, and remove obsolete aliases before 1.0.

**Warning signs:**
README examples, generated `.mbti`, and TS declarations disagree on the preferred names.

**Phase to address:**
Phase 2 - public API stabilization

---

### Pitfall 5: Release packaging drift

**What goes wrong:**
The core works locally, but npm artifacts, MoonBit package metadata, or CLI release assets are incomplete or inconsistent.

**Why it happens:**
Release logic is usually tested last, and each surface has its own packaging details.

**How to avoid:**
Dry-run npm and CLI release workflows before launch, verify generated artifacts, and make package boundaries explicit in docs.

**Warning signs:**
Local tests pass but built artifacts are missing files, wrong module formats, or stale docs.

**Phase to address:**
Phase 4 - release rehearsal and publication prep

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Wrapping core-only types in public MoonBit APIs | Fast path while prototyping | Locks callers to internals and complicates future cleanup | Never for release-bound APIs |
| Adding compatibility skips instead of fixes | Faster green tests | Compatibility claims become untrustworthy | Only as an explicitly documented temporary exception |
| Bundling adapter logic into the main runtime package | Fewer packages to manage | Runtime package stops being runtime-first and gains optional deps | Only during local prototyping, not for release |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| npm package exports | Shipping only one module format or stale `.d.ts` files | Validate ESM, CJS, and declaration outputs together |
| MoonBit package publication | Assuming mooncakes publication details later | Decide publication path before release docs are finalized |
| jq oracle tests | Comparing only happy-path outputs | Compare errors, raw modes, and exit semantics too |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Recompiling filters for every library call | Avoidable latency and noisy CPU use | Expose compiled filters and cache in callers where appropriate | Shows up immediately in repeated library use |
| Re-parsing through text and value layers repeatedly | Large inputs feel slower than jq | Keep conversions explicit and minimize boundary crossings | Breaks first on large JSON inputs |
| Running only tiny compatibility fixtures | Real workloads fail after "passing" tests | Add coverage for realistic nested data and option combinations | Breaks during release candidates |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Adding ad hoc non-jq side-effecting builtins | Broadens attack surface and muddies project scope | Keep the runtime focused on jq semantics and explicit library adapters |
| Treating untrusted filter text as harmless in host integrations | Callers may expose expensive or surprising execution paths | Document trust boundaries and keep host-side limits configurable |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Marketing "full compatibility" before the suite is actually complete | Users stop trusting release notes after the first mismatch | Tie compatibility claims to jq 1.8.1 and document exceptions precisely |
| Hiding the distinction between value lane and JSON-text lane | Users hit confusing number or output differences | Name both lanes clearly in docs and examples |
| Different error naming across surfaces | Support burden rises because examples do not translate | Keep failure classes aligned even if transport types differ |

## "Looks Done But Isn't" Checklist

- [ ] **CLI parity:** Verify raw mode, slurp, null input, and exit status, not only simple filter output
- [ ] **MoonBit API:** Verify public signatures use standard `Json` and generated `.mbti` matches the intended canonical names
- [ ] **JS/TS package:** Verify ESM, CJS, and `.d.ts` outputs all work from the published entry points
- [ ] **Compatibility claim:** Verify temporary skips and explicit exceptions are still documented and narrow
- [ ] **Release readiness:** Verify npm and CLI release workflows have been dry-run with actual artifacts

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Surface semantic drift | HIGH | Move the fix into core, add regression tests for all surfaces, then simplify wrappers |
| Public API debt | MEDIUM | Pick canonical names, update docs/examples, remove aliases, inspect `.mbti` and TS declaration diffs |
| Release packaging drift | MEDIUM | Rebuild from clean state, inspect artifact contents, rerun dry-run releases before announcing availability |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Surface semantic drift | Phase 1 | Oracle tests and cross-surface smoke tests agree |
| JSON fidelity loss | Phase 1 | Value lane and text lane both pass targeted number/output tests |
| Hidden compatibility exceptions | Phase 1 | Skips are explicit, documented, and shrinking |
| Public API debt | Phase 2 | `.mbti`, README examples, and TS declarations all use canonical names |
| Release packaging drift | Phase 4 | Dry-run artifacts are complete for npm and CLI |

## Sources

- https://jqlang.org/manual/ - jq behavior and CLI semantics
- https://docs.moonbitlang.com/en/latest/ - MoonBit package and public API context
- `AGENTS.md` - explicit warning against widened skips, alias debt, and ordering drift
- `README.mbt.md` - current advertised CLI and library surfaces

---
*Pitfalls research for: MoonBit-based jq-compatible runtime published as CLI, JS/TS library, and MoonBit library*
*Researched: 2026-03-12*
