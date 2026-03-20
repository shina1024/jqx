param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot "jq_upstream_import.json"),
  [string]$OutputPath = (Join-Path $PSScriptRoot "jq_compat_cases.upstream.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$node = Get-Command node -ErrorAction Stop
& $node.Source (Join-Path $PSScriptRoot "jq_upstream_import.mjs") --config $ConfigPath --output $OutputPath
exit $LASTEXITCODE
