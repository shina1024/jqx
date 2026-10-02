# jq upstream tests (vendored)

- upstream: https://github.com/jqlang/jq.git
- ref: master
- commit: 9a75bb0d4318bb6f6509635d89319ff40ee9ecac
- synced_at_utc: 2026-09-28

This directory is copied from `jqlang/jq` using `scripts/update_jq_tests.ps1`
or `scripts/update_jq_tests.sh`.

## Release-oracle differences

CI compares against the latest jq GitHub Release, currently jq 1.8.2, rather
than the master commit above. jqx keeps the intended upstream behavior for
two fixes that have not shipped in that release:

- [reduce initializer backtracking, #3633](https://github.com/jqlang/jq/commit/df24981307658868759faaea76b817cc62dd6be0): the empty-input, multi-initializer fixture at `jq.test:2583`.
- [negative fractional gmtime, #3634](https://github.com/jqlang/jq/commit/6aeafff056a988c20672ac1359b2beea13fb9315): the two fixtures at `optional.test:14` and `optional.test:18`. The upstream file also marks pre-epoch timestamps unsupported on mingw/WIN32.

Only those three cases have explicit temporary release-bug exceptions in
`scripts/jq_upstream_import.json`. Both jq and jqx still execute; comparisons
are not relaxed. `compat_stale_policy: "fail"` requires removing or narrowing
an exception when the release oracle matches. MoonBit regression tests assert
the intended jqx outputs independently, including multi-initializer reduce
with nonempty input. Existing Windows strftime and regex exceptions retain
their original scope.

The generated ledger records differences from Git HEAD at generation time; it
is a historical update report, not a post-commit reproducibility check. Imported
cases remain deterministic and are regenerated and compared in CI.
