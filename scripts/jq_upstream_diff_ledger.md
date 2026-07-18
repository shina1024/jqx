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
| upstream | 879 | 874 | 5 | 0 | 0 |

## Temporary Exceptions

- [upstream] upstream-jq-test-l1847 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names. Remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output
- [upstream] upstream-jq-test-l2558 (`jqx-windows-native-deep-json-roundtrip-stack`): The Windows native jqx executable exits with STATUS_STACK_OVERFLOW (0xC00000FD) while processing this 9,999-level JSON round trip; Linux and macOS complete the upstream case.. Remove when The Windows native jqx executable completes this upstream case without STATUS_STACK_OVERFLOW.
- [upstream] upstream-jq-test-l2563 (`jqx-windows-native-deep-fromjson-stack`): The Windows native jqx executable exits with STATUS_STACK_OVERFLOW (0xC00000FD) while parsing this 10,000-level JSON value; Linux and macOS return the expected depth-limit result.. Remove when The Windows native jqx executable completes this upstream case without STATUS_STACK_OVERFLOW.
- [upstream] upstream-jq-test-l2573 (`jqx-windows-native-deep-setpath-flatten-stack`): The Windows native jqx executable exits with STATUS_STACK_OVERFLOW (0xC00000FD) while flattening this 10,000-level setpath result; Linux and macOS complete the upstream case.. Remove when The Windows native jqx executable completes this upstream case without STATUS_STACK_OVERFLOW.
- [upstream] upstream-optional-test-l9 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names. Remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 879 -> 879
- upstream cases added/removed/changed: 0 / 0 / 7
- upstream differences old/new: 7 -> 5
- upstream differences new/resolved/changed: 5 / 7 / 0

## New Upstream Differences

- upstream-jq-test-l1847 (`temporary-exception`)
- upstream-jq-test-l2558 (`temporary-exception`)
- upstream-jq-test-l2563 (`temporary-exception`)
- upstream-jq-test-l2573 (`temporary-exception`)
- upstream-optional-test-l9 (`temporary-exception`)

## Resolved Upstream Differences

- upstream-jq-test-l2602
- upstream-jq-test-l2611
- upstream-jq-test-l2616
- upstream-jq-test-l2621
- upstream-jq-test-l2625
- upstream-jq-test-l2629
- upstream-jq-test-l2633

## Upstream Difference Behavior Changes

- none

## Upstream Case Behavior Changes

- upstream-jq-test-l2602: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2611: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2616: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2621: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2625: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2629: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2633: compat_status, compat_ledger_id, compat_reason, compat_removal_condition

## Added Upstream Cases

- none

## Removed Upstream Cases

- none

