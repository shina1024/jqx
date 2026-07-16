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
| upstream | 879 | 872 | 7 | 0 | 0 |

## Temporary Exceptions

- [upstream] upstream-jq-test-l2602 (`jq-1.8.2-deep-contains-guard`): jq 1.8.2 reports "Containment check too deep" for this deep contains case; jqx currently completes the operation instead of enforcing the jq depth guard. Remove when jqx implements the jq 1.8.2 deep contains guard or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2611 (`jq-1.8.2-deep-object-merge-guard`): jq 1.8.2 reports "Object merge too deep" for this deep object multiplication case; jqx currently completes the operation instead of enforcing the jq depth guard. Remove when jqx implements the jq 1.8.2 deep object merge guard or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2616 (`jq-1.8.2-deep-equality-guard`): jq 1.8.2 reports "Equality check too deep" for this deep equality case; jqx currently completes the operation instead of enforcing the jq depth guard. Remove when jqx implements the jq 1.8.2 deep equality guard or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2621 (`jq-1.8.2-deep-array-sort-guard`): jq 1.8.2 reports "Comparison too deep" for this deep array sort case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for array sort or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2625 (`jq-1.8.2-deep-array-unique-guard`): jq 1.8.2 reports "Comparison too deep" for this deep array unique case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for array unique or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2629 (`jq-1.8.2-deep-object-sort-guard`): jq 1.8.2 reports "Comparison too deep" for this deep object sort case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for object sort or jq upstream changes/removes this guard
- [upstream] upstream-jq-test-l2633 (`jq-1.8.2-deep-object-unique-guard`): jq 1.8.2 reports "Comparison too deep" for this deep object unique case; jqx currently completes the operation instead of enforcing the jq comparison depth guard. Remove when jqx implements the jq 1.8.2 deep comparison guard for object unique or jq upstream changes/removes this guard

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 879 -> 879
- upstream cases added/removed/changed: 0 / 0 / 3
- upstream differences old/new: 7 -> 7
- upstream differences new/resolved/changed: 0 / 0 / 0

## New Upstream Differences

- none

## Resolved Upstream Differences

- none

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

