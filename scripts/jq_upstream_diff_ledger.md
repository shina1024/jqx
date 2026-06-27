# jq Compatibility Diff Ledger

- maintained cases: `scripts/jq_compat_cases.json`
- upstream cases: `scripts/jq_compat_cases.upstream.json`
- upstream diff snapshot: `scripts/jq_upstream_failures.snapshot.json`
- upstream commit (HEAD): `3c81b6295808c967df24f71da93e601189ba3a61`
- upstream commit (current): `3c81b6295808c967df24f71da93e601189ba3a61`

## Corpus Status

| Corpus | Total | Passing | Temporary Exceptions | Broken | Stale Exception Metadata |
| --- | ---: | ---: | ---: | ---: | ---: |
| maintained | 252 | 252 | 0 | 0 | 0 |
| upstream | 879 | 870 | 9 | 0 | 0 |

## Temporary Exceptions

- [upstream] upstream-jq-test-l1847 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names. Remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output
- [upstream] upstream-jq-test-l2602 (`jq-1.8.2-deep-contains-guard`): jq 1.8.2 reports "Containment check too deep" for this deep contains case; jqx currently completes the operation instead of enforcing the jq depth guard. Remove when jqx implements the jq 1.8.2 deep contains guard or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2611 (`jq-1.8.2-deep-object-merge-guard`): jq 1.8.2 reports "Object merge too deep" for this deep object multiplication case; jqx currently completes the operation instead of enforcing the jq depth guard. Remove when jqx implements the jq 1.8.2 deep object merge guard or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2616 (`jq-1.8.2-deep-equality-guard`): jq 1.8.2 reports "Equality check too deep" for this deep equality case; jqx currently completes the operation instead of enforcing the jq depth guard. Remove when jqx implements the jq 1.8.2 deep equality guard or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2621 (`jq-1.8.2-deep-array-sort-guard`): jq 1.8.2 reports "Comparison too deep" for this deep array sort case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for array sort or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2625 (`jq-1.8.2-deep-array-unique-guard`): jq 1.8.2 reports "Comparison too deep" for this deep array unique case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for array unique or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2629 (`jq-1.8.2-deep-object-sort-guard`): jq 1.8.2 reports "Comparison too deep" for this deep object sort case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for object sort or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2633 (`jq-1.8.2-deep-object-unique-guard`): jq 1.8.2 reports "Comparison too deep" for this deep object unique case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for object unique or jq upstream changes/removes this guard
- [upstream] upstream-optional-test-l9 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names. Remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 879 -> 879
- upstream cases added/removed/changed: 0 / 0 / 1
- upstream differences old/new: 10 -> 9
- upstream differences new/resolved/changed: 0 / 1 / 0

## New Upstream Differences

- none

## Resolved Upstream Differences

- upstream-jq-test-l2014

## Upstream Difference Behavior Changes

- none

## Upstream Case Behavior Changes

- upstream-jq-test-l2014: compat_status, compat_ledger_id, compat_reason, compat_removal_condition

## Added Upstream Cases

- none

## Removed Upstream Cases

- none

