param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ScriptArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$node = Get-Command node -ErrorAction Stop
& $node.Source (Join-Path $PSScriptRoot "ts_packages.mjs") @ScriptArgs
exit $LASTEXITCODE
