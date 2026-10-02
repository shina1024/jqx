# jq Compatibility Diff Ledger

- maintained cases: `scripts/jq_compat_cases.json`
- upstream cases: `scripts/jq_compat_cases.upstream.json`
- upstream diff snapshot: `scripts/jq_upstream_failures.snapshot.json`
- upstream commit (HEAD): `9a75bb0d4318bb6f6509635d89319ff40ee9ecac`
- upstream commit (current): `9a75bb0d4318bb6f6509635d89319ff40ee9ecac`

## Corpus Status

| Corpus | Total | Passing | Declared Temporary Exceptions | Broken | Stale Exception Metadata |
| --- | ---: | ---: | ---: | ---: | ---: |
| maintained | 252 | 252 | 0 | 0 | 0 |
| upstream | 896 | 888 | 8 | 0 | 0 |

## Temporary Exceptions

- [upstream; win32] upstream-jq-test-l1867 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names; remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output.
- [upstream; all platforms] upstream-jq-test-l2583 (`jq-1.8.2-reduce-init-backtracking`): jq 1.8.2 loses reduce input when backtracking over multiple initializer outputs; jqx preserves input as required by the vendored fixture and upstream fix df24981307658868759faaea76b817cc62dd6be0 (#3633); remove when latest jq release preserves reduce input across initializer backtracking and matches this fixture, incorporating upstream fix df24981307658868759faaea76b817cc62dd6be0.
- [upstream; all platforms] upstream-onig-test-l15 (`jq-onig-zero-width-multibyte-boundary`): jq's current release matches empty regex at byte boundaries inside multibyte characters; jqx implements the upstream fixture's intended char-boundary semantics (upstream comment: 'global zero-width matches must not land inside a multibyte character'); remove when jq release adopts char-boundary zero-width match semantics matching upstream fixture expectations.
- [upstream; all platforms] upstream-onig-test-l19 (`jq-onig-zero-width-multibyte-boundary`): jq's current release matches empty regex at byte boundaries inside multibyte characters; jqx implements the upstream fixture's intended char-boundary semantics (upstream comment: 'global zero-width matches must not land inside a multibyte character'); remove when jq release adopts char-boundary zero-width match semantics matching upstream fixture expectations.
- [upstream; all platforms] upstream-onig-test-l23 (`jq-onig-zero-width-multibyte-boundary`): jq's current release matches empty regex at byte boundaries inside multibyte characters; jqx implements the upstream fixture's intended char-boundary semantics (upstream comment: 'global zero-width matches must not land inside a multibyte character'); remove when jq release adopts char-boundary zero-width match semantics matching upstream fixture expectations.
- [upstream; all platforms] upstream-optional-test-l14 (`jq-1.8.2-negative-gmtime`): jq 1.8.2 truncates rather than floors negative fractional timestamps; jqx matches upstream fix 6aeafff056a988c20672ac1359b2beea13fb9315 (#3634). Windows release artifacts additionally misreport pre-epoch weekdays, which the upstream fixture marks unsupported on mingw/WIN32; remove when latest jq release artifact on the target platform matches the fixture, including floored seconds and correct pre-epoch weekday; remove or re-scope the exception when the fractional fix lands but Windows remains unsupported.
- [upstream; all platforms] upstream-optional-test-l18 (`jq-1.8.2-negative-gmtime`): jq 1.8.2 negative fractional gmtime results are not monotonic; jqx matches the sorted-date fixture added by upstream fix 6aeafff056a988c20672ac1359b2beea13fb9315 (#3634), with pre-epoch timestamps also unsupported by the Windows release artifact; remove when latest jq release artifact on the target platform produces monotonic gmtime results for the fixture; remove or re-scope the exception when the fractional fix lands but Windows remains unsupported.
- [upstream; win32] upstream-optional-test-l9 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names; remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output.

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 896 -> 896
- upstream cases added/removed/changed: 0 / 0 / 5
- upstream differences old/new: 10 -> 8
- upstream differences new/resolved/changed: 2 / 4 / 3

## New Upstream Differences

- upstream-jq-test-l1867 (`temporary-exception`)
- upstream-optional-test-l9 (`temporary-exception`)

## Resolved Upstream Differences

- upstream-jq-test-l311
- upstream-jq-test-l319
- upstream-jq-test-l323
- upstream-jq-test-l327

## Upstream Difference Behavior Changes

- upstream-jq-test-l2583 (`output-mismatch` -> `temporary-exception`)
- upstream-optional-test-l14 (`output-mismatch` -> `temporary-exception`)
- upstream-optional-test-l18 (`output-mismatch` -> `temporary-exception`)

## Upstream Case Behavior Changes

- upstream-jq-test-l1847: compat_status, compat_platforms, compat_ledger_id, compat_reason, compat_removal_condition, compat_stale_policy
- upstream-jq-test-l1867: compat_status, compat_platforms, compat_ledger_id, compat_reason, compat_removal_condition, compat_stale_policy
- upstream-jq-test-l2583: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-optional-test-l14: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-optional-test-l18: compat_status, compat_ledger_id, compat_reason, compat_removal_condition

## Added Upstream Cases

- none

## Removed Upstream Cases

- none

