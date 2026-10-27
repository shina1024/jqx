# jq Compatibility Diff Ledger

- maintained cases: `scripts/jq_compat_cases.json`
- upstream cases: `scripts/jq_compat_cases.upstream.json`
- upstream diff snapshot: `scripts/jq_upstream_failures.snapshot.json`
- upstream commit (HEAD): `ac35c7dcbb991fa0f3c3196dd00ca479211e9847`
- upstream commit (current): `ac35c7dcbb991fa0f3c3196dd00ca479211e9847`

## Corpus Status

| Corpus | Total | Passing | Declared Temporary Exceptions | Broken | Stale Exception Metadata |
| --- | ---: | ---: | ---: | ---: | ---: |
| maintained | 266 | 266 | 0 | 0 | 0 |
| upstream | 946 | 930 | 16 | 0 | 0 |

## Temporary Exceptions

- [upstream; all platforms] upstream-jq-test-l1496 (`jq-1.8.2-error-fallback-operator`): jq 1.8.2 rejects the ?// token; jqx accepts it and returns the vendored upstream fixture's expected value 1; remove when latest jq release accepts error(0) ?// 1 and returns 1.
- [upstream; all platforms] upstream-jq-test-l1905 (`jq-1.8.2-ascii-case-errors`): jq 1.8.2 reports explode input must be a string; jqx preserves the function-specific errors required by upstream commit 864d769d888e49621849c8ad616d794f099e713f (#3689) and the vendored fixture, covered by execute ascii case conversion tests; remove when latest jq release reports ascii_downcase and ascii_upcase input must be a string for this fixture, incorporating upstream commit 864d769d888e49621849c8ad616d794f099e713f.
- [upstream; win32] upstream-jq-test-l1929 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names; remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output.
- [upstream; all platforms] upstream-jq-test-l1975 (`jq-1.8.2-strftime-result-too-long`): jq 1.8.2 reports unknown system failure for an oversized format; jqx reports the vendored upstream fixture's expected strftime/1: result too long; remove when latest jq release reports strftime/1: result too long for this fixture.
- [upstream; all platforms] upstream-jq-test-l1983 (`jq-1.8.2-strftime-result-too-long`): jq 1.8.2 reports unknown system failure for an oversized local format; jqx reports the vendored upstream fixture's expected strflocaltime/1: result too long; remove when latest jq release reports strflocaltime/1: result too long for this fixture.
- [upstream; all platforms] upstream-jq-test-l1992 (`jq-1.8.2-strptime-default-day`): jq 1.8.2 defaults a missing day to zero and converts to the previous month; jqx defaults to day one as required by upstream commit ac35c7dcbb991fa0f3c3196dd00ca479211e9847 (#3679) and the vendored fixture, covered by builtin_numeric tests; remove when latest jq release defaults a missing day to one and returns June 1 and January 1 for this fixture, incorporating upstream commit ac35c7dcbb991fa0f3c3196dd00ca479211e9847.
- [upstream; all platforms] upstream-jq-test-l1996 (`jq-1.8.2-strptime-default-day`): jq 1.8.2 leaves day zero and invalid weekday/year-day placeholders for a time-only format; jqx returns [1900,0,1,10,15,0,1,0] as required by upstream commit ac35c7dcbb991fa0f3c3196dd00ca479211e9847 (#3679) and the vendored fixture, covered by builtin_numeric tests; remove when latest jq release returns [1900,0,1,10,15,0,1,0] for this fixture, incorporating upstream commit ac35c7dcbb991fa0f3c3196dd00ca479211e9847.
- [upstream; all platforms] upstream-jq-test-l2099 (`jq-1.8.2-fromdateiso8601-surrounding-whitespace`): jq 1.8.2 accepts surrounding whitespace; jqx rejects both forms as required by the vendored upstream fixture; remove when latest jq release rejects both surrounding-whitespace inputs and this fixture returns ["ERR","ERR"].
- [upstream; all platforms] upstream-jq-test-l2474 (`jq-1.8.2-negate-zero-sign`): jq 1.8.2 loses the sign when negating a decnum literal; jqx preserves the sign as required by upstream commit afa23a53cde43cbd7d6e5d91ae759e342d518de6 (#3662) and the vendored fixture, covered by execute unary negation keeps the sign of zero; remove when latest jq release returns ["-0","0","-0","0"] for this fixture, incorporating upstream commit afa23a53cde43cbd7d6e5d91ae759e342d518de6.
- [upstream; all platforms] upstream-jq-test-l2780 (`jq-1.8.2-reduce-init-backtracking`): jq 1.8.2 loses reduce input when backtracking over multiple initializer outputs; jqx preserves input as required by the vendored fixture and upstream fix df24981307658868759faaea76b817cc62dd6be0 (#3633); remove when latest jq release preserves reduce input across initializer backtracking and matches this fixture, incorporating upstream fix df24981307658868759faaea76b817cc62dd6be0.
- [upstream; all platforms] upstream-onig-test-l15 (`jq-onig-zero-width-multibyte-boundary`): jq's current release matches empty regex at byte boundaries inside multibyte characters; jqx implements the upstream fixture's intended char-boundary semantics (upstream comment: 'global zero-width matches must not land inside a multibyte character'); remove when jq release adopts char-boundary zero-width match semantics matching upstream fixture expectations.
- [upstream; all platforms] upstream-onig-test-l19 (`jq-onig-zero-width-multibyte-boundary`): jq's current release matches empty regex at byte boundaries inside multibyte characters; jqx implements the upstream fixture's intended char-boundary semantics (upstream comment: 'global zero-width matches must not land inside a multibyte character'); remove when jq release adopts char-boundary zero-width match semantics matching upstream fixture expectations.
- [upstream; all platforms] upstream-onig-test-l23 (`jq-onig-zero-width-multibyte-boundary`): jq's current release matches empty regex at byte boundaries inside multibyte characters; jqx implements the upstream fixture's intended char-boundary semantics (upstream comment: 'global zero-width matches must not land inside a multibyte character'); remove when jq release adopts char-boundary zero-width match semantics matching upstream fixture expectations.
- [upstream; all platforms] upstream-optional-test-l13 (`jq-1.8.2-negative-gmtime`): jq 1.8.2 negative fractional gmtime results are not monotonic; jqx matches the sorted-date fixture added by upstream fix 6aeafff056a988c20672ac1359b2beea13fb9315 (#3634), with pre-epoch timestamps also unsupported by the Windows release artifact; remove when latest jq release artifact on the target platform produces monotonic gmtime results for the fixture; remove or re-scope the exception when the fractional fix lands but Windows remains unsupported.
- [upstream; win32] upstream-optional-test-l4 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names; remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output.
- [upstream; all platforms] upstream-optional-test-l9 (`jq-1.8.2-negative-gmtime`): jq 1.8.2 truncates rather than floors negative fractional timestamps; jqx matches upstream fix 6aeafff056a988c20672ac1359b2beea13fb9315 (#3634). Windows release artifacts additionally misreport pre-epoch weekdays, which the upstream fixture marks unsupported on mingw/WIN32; remove when latest jq release artifact on the target platform matches the fixture, including floored seconds and correct pre-epoch weekday; remove or re-scope the exception when the fractional fix lands but Windows remains unsupported.

## Broken Cases

- none

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 946 -> 946
- upstream cases added/removed/changed: 0 / 0 / 4
- upstream differences old/new: 15 -> 16
- upstream differences new/resolved/changed: 2 / 1 / 6

## New Upstream Differences

- upstream-jq-test-l1929 (`temporary-exception`)
- upstream-optional-test-l4 (`temporary-exception`)

## Resolved Upstream Differences

- upstream-jq-test-l88

## Upstream Difference Behavior Changes

- upstream-jq-test-l1905 (`output-mismatch` -> `temporary-exception`)
- upstream-jq-test-l1992 (`runtime-error-vs-jq-success` -> `temporary-exception`)
- upstream-jq-test-l1996 (`runtime-error-vs-jq-success` -> `temporary-exception`)
- upstream-jq-test-l2099 (`temporary-exception` -> `temporary-exception`)
- upstream-jq-test-l2474 (`output-mismatch` -> `temporary-exception`)
- upstream-optional-test-l9 (`temporary-exception` -> `temporary-exception`)

## Upstream Case Behavior Changes

- upstream-jq-test-l1905: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l1992: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l1996: compat_status, compat_ledger_id, compat_reason, compat_removal_condition
- upstream-jq-test-l2474: compat_status, compat_ledger_id, compat_reason, compat_removal_condition

## Added Upstream Cases

- none

## Removed Upstream Cases

- none

