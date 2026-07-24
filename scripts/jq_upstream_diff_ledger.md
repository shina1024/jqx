# jq Compatibility Diff Ledger

- maintained cases: `scripts/jq_compat_cases.json`
- upstream cases: `scripts/jq_compat_cases.upstream.json`
- upstream diff snapshot: `scripts/jq_upstream_failures.snapshot.json`
- upstream commit (HEAD): `579e6f76cffd7643ba4002a2c3618a5ea710589a`
- upstream commit (current): `2d410d6d86be7f685ad28e5cffac0248aa47664c`

## Corpus Status

| Corpus | Total | Passing | Declared Temporary Exceptions | Broken | Stale Exception Metadata |
| --- | ---: | ---: | ---: | ---: | ---: |
| maintained | 252 | 252 | 0 | 0 | 0 |
| upstream | 883 | 877 | 2 | 4 | 0 |

## Temporary Exceptions

- [upstream; win32] upstream-jq-test-l1847 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names; remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output.
- [upstream; win32] upstream-optional-test-l9 (`jq-1.8.2-windows-strftime-encoding`): jq 1.8.2 for Windows emits non-UTF-8 mojibake for localized strftime names in this release artifact; jqx emits UTF-8 English names; remove when jq Windows release artifacts emit stable UTF-8 strftime names or jqx intentionally adopts platform-locale encoded output.

## Broken Cases

- [upstream] upstream-man-test-l646 (`runtime-error-vs-jq-success`)
- [upstream] upstream-onig-test-l15 (`output-mismatch`)
- [upstream] upstream-onig-test-l19 (`output-mismatch`)
- [upstream] upstream-onig-test-l23 (`output-mismatch`)

## Stale Exception Metadata

- none

## Upstream Drift Summary

- upstream cases old/new: 879 -> 883
- upstream cases added/removed/changed: 44 / 40 / 82
- upstream differences old/new: 2 -> 4
- upstream differences new/resolved/changed: 4 / 2 / 0

## New Upstream Differences

- upstream-man-test-l646 (`runtime-error-vs-jq-success`)
- upstream-onig-test-l15 (`output-mismatch`)
- upstream-onig-test-l19 (`output-mismatch`)
- upstream-onig-test-l23 (`output-mismatch`)

## Resolved Upstream Differences

- upstream-jq-test-l1847
- upstream-optional-test-l9

## Upstream Difference Behavior Changes

- none

## Upstream Case Behavior Changes

- upstream-man-test-l646: filter, input
- upstream-man-test-l650: filter, input
- upstream-man-test-l654: filter
- upstream-man-test-l658: filter, input
- upstream-man-test-l662: filter, input, source_expected_count
- upstream-man-test-l686: filter, input
- upstream-man-test-l690: filter
- upstream-man-test-l694: filter, input
- upstream-man-test-l698: filter, input
- upstream-man-test-l702: input
- upstream-man-test-l706: filter
- upstream-man-test-l710: filter, input
- upstream-man-test-l714: filter, input
- upstream-man-test-l718: filter
- upstream-man-test-l722: filter
- upstream-man-test-l726: filter, input
- upstream-man-test-l730: filter, input
- upstream-man-test-l734: filter, input
- upstream-man-test-l738: filter, input
- upstream-man-test-l742: filter, input
- upstream-man-test-l746: filter
- upstream-man-test-l750: filter
- upstream-man-test-l754: filter, input
- upstream-man-test-l758: filter, input
- upstream-man-test-l762: filter, input, source_expected_count
- upstream-man-test-l773: filter
- upstream-man-test-l777: filter, input
- upstream-man-test-l781: filter, source_expected_count
- upstream-man-test-l797: filter
- upstream-man-test-l801: filter, input
- upstream-man-test-l805: input
- upstream-man-test-l809: filter, input
- upstream-man-test-l813: filter, source_expected_count
- upstream-man-test-l823: filter, input
- upstream-man-test-l827: filter, input
- upstream-man-test-l831: filter, input
- upstream-man-test-l835: filter, input
- upstream-man-test-l839: filter, input
- upstream-man-test-l843: filter, input
- upstream-man-test-l847: filter, input
- upstream-man-test-l851: filter, input, source_expected_count
- upstream-man-test-l871: filter, input
- upstream-man-test-l875: filter
- upstream-man-test-l879: filter, input
- upstream-man-test-l883: filter, input
- upstream-man-test-l887: input
- upstream-man-test-l891: filter, input
- upstream-man-test-l895: filter
- upstream-man-test-l899: filter, input
- upstream-man-test-l903: filter, input
- upstream-man-test-l907: filter, input
- upstream-man-test-l911: filter, input
- upstream-man-test-l915: filter, input
- upstream-man-test-l919: filter, input
- upstream-man-test-l923: filter, input, source_expected_count
- upstream-man-test-l956: filter, source_expected_count
- upstream-man-test-l965: filter, input
- upstream-man-test-l969: filter, input
- upstream-man-test-l973: filter, input
- upstream-man-test-l977: filter, input
- upstream-man-test-l981: filter
- upstream-man-test-l985: filter, input, source_expected_count
- upstream-onig-test-l141: filter, input
- upstream-onig-test-l145: filter, input
- upstream-onig-test-l149: filter, input
- upstream-onig-test-l162: filter, input
- upstream-onig-test-l166: filter, input
- upstream-onig-test-l170: filter, input
- upstream-onig-test-l179: filter, input
- upstream-onig-test-l183: filter, input
- upstream-onig-test-l187: filter, input
- upstream-onig-test-l196: filter, input
- upstream-onig-test-l200: filter, input
- upstream-onig-test-l204: filter, input
- upstream-onig-test-l23: filter, input
- upstream-onig-test-l36: filter, input
- upstream-onig-test-l41: filter, input, source_expected_count
- upstream-onig-test-l54: filter
- upstream-onig-test-l60: filter
- upstream-onig-test-l67: filter, input, source_expected_count
- upstream-onig-test-l84: filter, input
- upstream-onig-test-l88: filter, input

## Added Upstream Cases

- upstream-man-test-l666
- upstream-man-test-l673
- upstream-man-test-l680
- upstream-man-test-l766
- upstream-man-test-l785
- upstream-man-test-l790
- upstream-man-test-l817
- upstream-man-test-l855
- upstream-man-test-l861
- upstream-man-test-l866
- upstream-man-test-l927
- upstream-man-test-l935
- upstream-man-test-l943
- upstream-man-test-l949
- upstream-man-test-l960
- upstream-man-test-l989
- upstream-man-test-l995
- upstream-onig-test-l101
- upstream-onig-test-l105
- upstream-onig-test-l109
- upstream-onig-test-l113
- upstream-onig-test-l117
- upstream-onig-test-l121
- upstream-onig-test-l125
- upstream-onig-test-l129
- upstream-onig-test-l133
- upstream-onig-test-l137
- upstream-onig-test-l15
- upstream-onig-test-l154
- upstream-onig-test-l158
- upstream-onig-test-l175
- upstream-onig-test-l19
- upstream-onig-test-l192
- upstream-onig-test-l209
- upstream-onig-test-l213
- upstream-onig-test-l217
- upstream-onig-test-l221
- upstream-onig-test-l27
- upstream-onig-test-l31
- upstream-onig-test-l45
- upstream-onig-test-l49
- upstream-onig-test-l73
- upstream-onig-test-l80
- upstream-onig-test-l97

## Removed Upstream Cases

- upstream-man-test-l669
- upstream-man-test-l676
- upstream-man-test-l682
- upstream-man-test-l769
- upstream-man-test-l786
- upstream-man-test-l793
- upstream-man-test-l819
- upstream-man-test-l857
- upstream-man-test-l862
- upstream-man-test-l867
- upstream-man-test-l931
- upstream-man-test-l939
- upstream-man-test-l945
- upstream-man-test-l952
- upstream-man-test-l961
- upstream-man-test-l991
- upstream-onig-test-l100
- upstream-onig-test-l104
- upstream-onig-test-l108
- upstream-onig-test-l112
- upstream-onig-test-l116
- upstream-onig-test-l120
- upstream-onig-test-l124
- upstream-onig-test-l128
- upstream-onig-test-l132
- upstream-onig-test-l136
- upstream-onig-test-l14
- upstream-onig-test-l153
- upstream-onig-test-l157
- upstream-onig-test-l174
- upstream-onig-test-l18
- upstream-onig-test-l191
- upstream-onig-test-l208
- upstream-onig-test-l28
- upstream-onig-test-l32
- upstream-onig-test-l47
- upstream-onig-test-l71
- upstream-onig-test-l75
- upstream-onig-test-l92
- upstream-onig-test-l96

