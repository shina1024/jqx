param(
  [string]$CasesPath = (Join-Path $PSScriptRoot "jq_compat_cases.json"),
  [string]$SnapshotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "jq_diff.mjs"
$args = @($scriptPath, $CasesPath)
if ($SnapshotPath -ne "") {
  $args += @("--snapshot", $SnapshotPath)
}

& node @args
exit $LASTEXITCODE
