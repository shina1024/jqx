# jq Compatibility Diff Ledger

- maintained cases: `scripts/jq_compat_cases.json`
- upstream cases: `scripts/jq_compat_cases.upstream.json`
- upstream diff snapshot: `scripts/jq_upstream_failures.snapshot.json`
- upstream commit (HEAD): `579e6f76cffd7643ba4002a2c3618a5ea710589a`
- upstream commit (current): `579e6f76cffd7643ba4002a2c3618a5ea710589a`

## Corpus Status

| Corpus | Total | Passing | Temporary Exceptions | Broken | Stale Exception Metadata |
| --- | ---: | ---: | ---: | ---: | ---: |
| maintained | 252 | 252 | 0 | 0 | 0 |
| upstream | 879 | 877 | 2 | 0 | 0 |

## Temporary Exceptions

- [upstream] upstream-jq-test-l1847 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names. Remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output
- [upstream] upstream-optional-test-l9 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names. Remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 879 -> 879
- upstream cases added/removed/changed: 0 / 0 / 3
- upstream differences old/new: 5 -> 2
- upstream differences new/resolved/changed: 0 / 3 / 0

## New Upstream Differences

- none

## Resolved Upstream Differences

- upstream-jq-test-l2558
- upstream-jq-test-l2563
- upstream-jq-test-l2573

## Upstream Difference Behavior Changes

- none

## Upstream Case Behavior Changes

- upstream-jq-test-l2558: compat_status, compat_platforms, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2563: compat_status, compat_platforms, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2573: compat_status, compat_platforms, compat_ledger_id, compat_reason, compat_removal_condition

## Added Upstream Cases

- none

## Removed Upstream Cases

- none

