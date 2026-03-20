param(
  [string]$CasesPath = (Join-Path $PSScriptRoot "jq_compat_cases.upstream.json"),
  [string]$MaintainedCasesPath = (Join-Path $PSScriptRoot "jq_compat_cases.json"),
  [string]$FailureSnapshotPath = (Join-Path $PSScriptRoot "jq_upstream_failures.snapshot.json"),
  [string]$LedgerPath = (Join-Path $PSScriptRoot "jq_upstream_diff_ledger.md"),
  [switch]$SkipDifferential,
  [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$node = Get-Command node -ErrorAction Stop
$args = @(
  (Join-Path $PSScriptRoot "jq_upstream_ledger.mjs"),
  "--cases", $CasesPath,
  "--maintained-cases", $MaintainedCasesPath,
  "--failure-snapshot", $FailureSnapshotPath,
  "--ledger", $LedgerPath
)
if ($SkipDifferential) {
  $args += "--skip-differential"
}
if ($Verify) {
  $args += "--verify"
}

& $node.Source @args
exit $LASTEXITCODE
