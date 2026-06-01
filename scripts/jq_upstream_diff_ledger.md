# jq Compatibility Diff Ledger

- maintained cases: `scripts/jq_compat_cases.json`
- upstream cases: `scripts/jq_compat_cases.upstream.json`
- upstream diff snapshot: `scripts/jq_upstream_failures.snapshot.json`
- upstream commit (HEAD): `f58787c41835d9b17795730cb04925fdba25c71c`
- upstream commit (current): `df924eae91af10cc236a907cdadd97813827aa1f`

## Corpus Status

| Corpus | Total | Passing | Temporary Exceptions | Broken | Stale Exception Metadata |
| --- | ---: | ---: | ---: | ---: | ---: |
| maintained | 252 | 252 | 0 | 0 | 0 |
| upstream | 879 | 875 | 4 | 0 | 0 |

## Temporary Exceptions

- [upstream] upstream-jq-test-l1188 (`jq-1.8.1-abort-del-nan-index`): jq 1.8.1 aborts while deleting an array path selected by a NaN index; jqx intentionally does not reproduce process aborts. Remove when jq upstream stops aborting for del(.[nan]) or jqx adopts a documented jq-crash compatibility mode
- [upstream] upstream-jq-test-l1192 (`jq-1.8.1-abort-del-nan-index`): jq 1.8.1 aborts while deleting an array path selected by NaN indices; jqx intentionally does not reproduce process aborts. Remove when jq upstream stops aborting for del(.[nan,nan]) or jqx adopts a documented jq-crash compatibility mode
- [upstream] upstream-jq-test-l1553 (`jq-1.8.1-abort-strindices-input`): jq 1.8.1 aborts when _strindices receives a non-string input; jqx returns a normal type error instead of reproducing process aborts. Remove when jq upstream stops aborting for _strindices with non-string input or jqx adopts a documented jq-crash compatibility mode
- [upstream] upstream-jq-test-l1557 (`jq-1.8.1-abort-strindices-pattern`): jq 1.8.1 aborts when _strindices receives a non-string pattern; jqx returns a normal type error instead of reproducing process aborts. Remove when jq upstream stops aborting for _strindices with non-string pattern or jqx adopts a documented jq-crash compatibility mode

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 874 -> 879
- upstream cases added/removed/changed: 5 / 0 / 0
- upstream differences old/new: 4 -> 4
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

- upstream-jq-test-l2616
- upstream-jq-test-l2621
- upstream-jq-test-l2625
- upstream-jq-test-l2629
- upstream-jq-test-l2633

## Removed Upstream Cases

- none

