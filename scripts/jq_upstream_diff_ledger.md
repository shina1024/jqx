# jq Compatibility Diff Ledger

- maintained cases: `scripts/jq_compat_cases.json`
- upstream cases: `scripts/jq_compat_cases.upstream.json`
- upstream diff snapshot: `scripts/jq_upstream_failures.snapshot.json`
- upstream commit (HEAD): `b33a7634ba34ffa7ce7368cc0ebf5ca40b54c7e6`
- upstream commit (current): `b33a7634ba34ffa7ce7368cc0ebf5ca40b54c7e6`

## Corpus Status

| Corpus | Total | Passing | Temporary Exceptions | Broken | Stale Exception Metadata |
| --- | ---: | ---: | ---: | ---: | ---: |
| maintained | 248 | 245 | 3 | 0 | 0 |
| upstream | 843 | 843 | 0 | 0 | 0 |

## Temporary Exceptions

- [maintained] cli-exit-status-empty (cli-e-exit-status): jqx CLI does not yet implement jq -e exit semantics for false/null/no-result cases and returns status 0.. Remove when Remove once cmd exit handling matches jq 1.8.1 for -e on false, null, and empty outputs.
- [maintained] cli-exit-status-false (cli-e-exit-status): jqx CLI does not yet implement jq -e exit semantics for false/null/no-result cases and returns status 0.. Remove when Remove once cmd exit handling matches jq 1.8.1 for -e on false, null, and empty outputs.
- [maintained] cli-exit-status-null (cli-e-exit-status): jqx CLI does not yet implement jq -e exit semantics for false/null/no-result cases and returns status 0.. Remove when Remove once cmd exit handling matches jq 1.8.1 for -e on false, null, and empty outputs.

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 843 -> 843
- upstream cases added/removed/changed: 0 / 0 / 0
- upstream differences old/new: 0 -> 0
- upstream differences new/resolved/changed: 0 / 0 / 0

## New Upstream Differences

- none

## Resolved Upstream Differences

- none

## Upstream Difference Behavior Changes

- none

## Upstream Case Behavior Changes

- none

## Added Upstream Cases

- none

## Removed Upstream Cases

- none

