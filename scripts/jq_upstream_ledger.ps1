param(
  [string]$CasesPath = (Join-Path $PSScriptRoot "jq_compat_cases.upstream.json"),
  [string]$FailureSnapshotPath = (Join-Path $PSScriptRoot "jq_upstream_failures.snapshot.json"),
  [string]$LedgerPath = (Join-Path $PSScriptRoot "jq_upstream_diff_ledger.md"),
  [switch]$SkipDifferential
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoRelativePath {
  param(
    [string]$RepoRoot,
    [string]$PathValue
  )

  $absolute = if ([System.IO.Path]::IsPathRooted($PathValue)) {
    [System.IO.Path]::GetFullPath($PathValue)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $PathValue))
  }

  $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $absolute)
  $relative = $relative -replace '\\', '/'
  return [PSCustomObject]@{
    Absolute = $absolute
    Relative = $relative
  }
}

function ConvertTo-CanonicalJson {
  param([object]$Value)
  return (ConvertTo-Json -InputObject $Value -Depth 40 -Compress)
}

function ConvertTo-PrettyJson {
  param([object]$Value)
  return (ConvertTo-Json -InputObject $Value -Depth 40)
}

function Read-JsonArrayFromFile {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }
  $raw = Get-Content -Raw $Path
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }
  $parsed = $raw | ConvertFrom-Json
  if ($parsed -is [System.Array]) {
    return @($parsed)
  }
  return @($parsed)
}

function Read-HeadFileRaw {
  param(
    [string]$RepoRoot,
    [string]$RepoRelativePath
  )

  $output = & git -C $RepoRoot show ("HEAD:{0}" -f $RepoRelativePath) 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $null
  }
  return [string]($output -join "`n")
}

function Read-JsonArrayFromHead {
  param(
    [string]$RepoRoot,
    [string]$RepoRelativePath
  )

  $raw = Read-HeadFileRaw -RepoRoot $RepoRoot -RepoRelativePath $RepoRelativePath
  if ($null -eq $raw -or [string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }
  $parsed = $raw | ConvertFrom-Json
  if ($parsed -is [System.Array]) {
    return @($parsed)
  }
  return @($parsed)
}

function Read-HeadTextLine {
  param(
    [string]$RepoRoot,
    [string]$RepoRelativePath
  )

  $raw = Read-HeadFileRaw -RepoRoot $RepoRoot -RepoRelativePath $RepoRelativePath
  if ($null -eq $raw) {
    return ""
  }
  return $raw.Trim()
}

function Build-CaseComparableRecord {
  param([psobject]$Case)

  $record = [ordered]@{
    name = [string]$Case.name
    filter = [string]$Case.filter
    input = [string]$Case.input
    source_file = if ($Case.PSObject.Properties.Name -contains "source_file" -and $null -ne $Case.source_file) { [string]$Case.source_file } else { "" }
    source_line = if ($Case.PSObject.Properties.Name -contains "source_line" -and $null -ne $Case.source_line) { [int]$Case.source_line } else { 0 }
    source_kind = if ($Case.PSObject.Properties.Name -contains "source_kind" -and $null -ne $Case.source_kind) { [string]$Case.source_kind } else { "" }
    expect_error = if ($Case.PSObject.Properties.Name -contains "expect_error" -and $null -ne $Case.expect_error) { [bool]$Case.expect_error } else { $false }
    expect_error_mode = if ($Case.PSObject.Properties.Name -contains "expect_error_mode" -and $null -ne $Case.expect_error_mode) { [string]$Case.expect_error_mode } else { "" }
    expect_status = if ($Case.PSObject.Properties.Name -contains "expect_status" -and $null -ne $Case.expect_status) { [int]$Case.expect_status } else { $null }
    source_expected_count = if ($Case.PSObject.Properties.Name -contains "source_expected_count" -and $null -ne $Case.source_expected_count) { [int]$Case.source_expected_count } else { $null }
    source_error_lines = if ($Case.PSObject.Properties.Name -contains "source_error_lines" -and $null -ne $Case.source_error_lines) { @($Case.source_error_lines) } else { @() }
    jq_args = if ($Case.PSObject.Properties.Name -contains "jq_args" -and $null -ne $Case.jq_args) { @($Case.jq_args) } else { @() }
    jqx_args = if ($Case.PSObject.Properties.Name -contains "jqx_args" -and $null -ne $Case.jqx_args) { @($Case.jqx_args) } else { @() }
    jqx_use_stdin = if ($Case.PSObject.Properties.Name -contains "jqx_use_stdin" -and $null -ne $Case.jqx_use_stdin) { [bool]$Case.jqx_use_stdin } else { $true }
    skip_reason = if ($Case.PSObject.Properties.Name -contains "skip_reason" -and $null -ne $Case.skip_reason) { [string]$Case.skip_reason } else { "" }
  }
  return $record
}

function Get-ChangedCaseFields {
  param(
    [System.Collections.IDictionary]$OldRecord,
    [System.Collections.IDictionary]$NewRecord
  )

  $fields = @()
  foreach ($key in $OldRecord.Keys) {
    $oldText = ConvertTo-CanonicalJson $OldRecord[$key]
    $newText = ConvertTo-CanonicalJson $NewRecord[$key]
    if ($oldText -ne $newText) {
      $fields += [string]$key
    }
  }
  return $fields
}

function Build-FailureComparableRecord {
  param([psobject]$Failure)

  return [ordered]@{
    name = [string]$Failure.name
    category = if ($Failure.PSObject.Properties.Name -contains "category" -and $null -ne $Failure.category) { [string]$Failure.category } else { "" }
    jq_status = if ($Failure.PSObject.Properties.Name -contains "jq_status" -and $null -ne $Failure.jq_status) { [string]$Failure.jq_status } else { "" }
    jqx_status = if ($Failure.PSObject.Properties.Name -contains "jqx_status" -and $null -ne $Failure.jqx_status) { [string]$Failure.jqx_status } else { "" }
    jq_out = if ($Failure.PSObject.Properties.Name -contains "jq_out" -and $null -ne $Failure.jq_out) { [string]$Failure.jq_out } else { "" }
    jqx_out = if ($Failure.PSObject.Properties.Name -contains "jqx_out" -and $null -ne $Failure.jqx_out) { [string]$Failure.jqx_out } else { "" }
  }
}

function Build-CaseMap {
  param([object[]]$Cases)

  $map = @{}
  foreach ($case in $Cases) {
    $map[[string]$case.name] = $case
  }
  return $map
}

function Build-FailureMap {
  param([object[]]$Failures)

  $map = @{}
  foreach ($failure in $Failures) {
    $map[[string]$failure.name] = $failure
  }
  return $map
}

function Write-TextFileIfChanged {
  param(
    [string]$Path,
    [string]$Content
  )

  $existing = ""
  if (Test-Path $Path) {
    $existing = Get-Content -Raw $Path
  }
  if ($existing -eq $Content) {
    return $false
  }

  $dir = Split-Path -Parent $Path
  if ($dir -ne "" -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  return $true
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$casesPathRef = Resolve-RepoRelativePath -RepoRoot $repoRoot -PathValue $CasesPath
$failureSnapshotPathRef = Resolve-RepoRelativePath -RepoRoot $repoRoot -PathValue $FailureSnapshotPath
$ledgerPathRef = Resolve-RepoRelativePath -RepoRoot $repoRoot -PathValue $LedgerPath

if (-not (Test-Path $casesPathRef.Absolute)) {
  throw "cases file not found: $($casesPathRef.Absolute)"
}

$oldCases = @(Read-JsonArrayFromHead -RepoRoot $repoRoot -RepoRelativePath $casesPathRef.Relative)
$newCases = @(Read-JsonArrayFromFile -Path $casesPathRef.Absolute)
$oldCaseMap = Build-CaseMap -Cases $oldCases
$newCaseMap = Build-CaseMap -Cases $newCases

$addedCaseNames = @($newCaseMap.Keys | Where-Object { -not $oldCaseMap.ContainsKey($_) } | Sort-Object)
$removedCaseNames = @($oldCaseMap.Keys | Where-Object { -not $newCaseMap.ContainsKey($_) } | Sort-Object)
$commonCaseNames = @($newCaseMap.Keys | Where-Object { $oldCaseMap.ContainsKey($_) } | Sort-Object)

$changedCases = @()
foreach ($name in $commonCaseNames) {
  $oldRecord = Build-CaseComparableRecord -Case $oldCaseMap[$name]
  $newRecord = Build-CaseComparableRecord -Case $newCaseMap[$name]
  $changedFields = @(Get-ChangedCaseFields -OldRecord $oldRecord -NewRecord $newRecord)
  if ($changedFields.Count -gt 0) {
    $changedCases += [PSCustomObject]@{
      name = $name
      changed_fields = @($changedFields)
    }
  }
}

$oldFailures = @(Read-JsonArrayFromHead -RepoRoot $repoRoot -RepoRelativePath $failureSnapshotPathRef.Relative)
$newFailures = @()

if ($SkipDifferential) {
  $newFailures = @(Read-JsonArrayFromFile -Path $failureSnapshotPathRef.Absolute)
} else {
  $tempSnapshot = Join-Path ([System.IO.Path]::GetTempPath()) ("jq-upstream-failures-" + [Guid]::NewGuid().ToString("N") + ".json")
  $jqDiffScript = Join-Path $PSScriptRoot "jq_diff.ps1"
  try {
    & $jqDiffScript -CasesPath $casesPathRef.Absolute -SnapshotPath $tempSnapshot
    $diffExit = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($diffExit -ne 0 -and $diffExit -ne 1) {
      throw "jq_diff.ps1 failed with unexpected exit code: $diffExit"
    }
    $newFailures = @(Read-JsonArrayFromFile -Path $tempSnapshot)
  } finally {
    Remove-Item -Path $tempSnapshot -ErrorAction SilentlyContinue
  }
}

$orderedNewFailures = @($newFailures | Sort-Object -Property name, category)
$newFailuresJson = ConvertTo-PrettyJson -Value @($orderedNewFailures)
if (-not $newFailuresJson.EndsWith("`n")) {
  $newFailuresJson += "`n"
}
[void](Write-TextFileIfChanged -Path $failureSnapshotPathRef.Absolute -Content $newFailuresJson)

$oldFailureMap = Build-FailureMap -Failures $oldFailures
$newFailureMap = Build-FailureMap -Failures $orderedNewFailures

$newFailureNames = @($newFailureMap.Keys | Where-Object { -not $oldFailureMap.ContainsKey($_) } | Sort-Object)
$resolvedFailureNames = @($oldFailureMap.Keys | Where-Object { -not $newFailureMap.ContainsKey($_) } | Sort-Object)
$commonFailureNames = @($newFailureMap.Keys | Where-Object { $oldFailureMap.ContainsKey($_) } | Sort-Object)

$changedFailureNames = @()
foreach ($name in $commonFailureNames) {
  $oldComparable = Build-FailureComparableRecord -Failure $oldFailureMap[$name]
  $newComparable = Build-FailureComparableRecord -Failure $newFailureMap[$name]
  if ((ConvertTo-CanonicalJson $oldComparable) -ne (ConvertTo-CanonicalJson $newComparable)) {
    $changedFailureNames += $name
  }
}
$changedFailureNames = @($changedFailureNames | Sort-Object)

$headUpstreamCommit = Read-HeadTextLine -RepoRoot $repoRoot -RepoRelativePath "third_party/jq-tests/UPSTREAM_COMMIT"
$currentUpstreamCommit = ""
$currentCommitPath = Join-Path $repoRoot "third_party/jq-tests/UPSTREAM_COMMIT"
if (Test-Path $currentCommitPath) {
  $currentUpstreamCommit = (Get-Content -Raw $currentCommitPath).Trim()
}

$maxListed = 80
$ledgerLines = @()
$ledgerLines += "# jq Upstream Diff Ledger"
$ledgerLines += ""
$ledgerLines += "- cases: ``$($casesPathRef.Relative)``"
$ledgerLines += "- failures snapshot: ``$($failureSnapshotPathRef.Relative)``"
$ledgerLines += "- upstream commit (HEAD): ``$headUpstreamCommit``"
$ledgerLines += "- upstream commit (current): ``$currentUpstreamCommit``"
$ledgerLines += ""
$ledgerLines += "## Summary"
$ledgerLines += ""
$ledgerLines += "- cases old/new: $($oldCases.Count) -> $($newCases.Count)"
$ledgerLines += "- cases added/removed/changed: $($addedCaseNames.Count) / $($removedCaseNames.Count) / $($changedCases.Count)"
$ledgerLines += "- failures old/new: $($oldFailures.Count) -> $($orderedNewFailures.Count)"
$ledgerLines += "- failures new/resolved/changed: $($newFailureNames.Count) / $($resolvedFailureNames.Count) / $($changedFailureNames.Count)"
$ledgerLines += ""
$ledgerLines += "## New Failures"
$ledgerLines += ""
if ($newFailureNames.Count -eq 0) {
  $ledgerLines += "- none"
} else {
  foreach ($name in ($newFailureNames | Select-Object -First $maxListed)) {
    $category = [string]$newFailureMap[$name].category
    $ledgerLines += "- $name (`$category`)"
  }
  if ($newFailureNames.Count -gt $maxListed) {
    $ledgerLines += "- ... ($($newFailureNames.Count - $maxListed) more)"
  }
}
$ledgerLines += ""
$ledgerLines += "## Resolved Failures"
$ledgerLines += ""
if ($resolvedFailureNames.Count -eq 0) {
  $ledgerLines += "- none"
} else {
  foreach ($name in ($resolvedFailureNames | Select-Object -First $maxListed)) {
    $ledgerLines += "- $name"
  }
  if ($resolvedFailureNames.Count -gt $maxListed) {
    $ledgerLines += "- ... ($($resolvedFailureNames.Count - $maxListed) more)"
  }
}
$ledgerLines += ""
$ledgerLines += "## Failure Behavior Changes"
$ledgerLines += ""
if ($changedFailureNames.Count -eq 0) {
  $ledgerLines += "- none"
} else {
  foreach ($name in ($changedFailureNames | Select-Object -First $maxListed)) {
    $oldCategory = [string]$oldFailureMap[$name].category
    $newCategory = [string]$newFailureMap[$name].category
    $ledgerLines += "- $name (`$oldCategory` -> `$newCategory`)"
  }
  if ($changedFailureNames.Count -gt $maxListed) {
    $ledgerLines += "- ... ($($changedFailureNames.Count - $maxListed) more)"
  }
}
$ledgerLines += ""
$ledgerLines += "## Case Behavior Changes"
$ledgerLines += ""
if ($changedCases.Count -eq 0) {
  $ledgerLines += "- none"
} else {
  foreach ($item in ($changedCases | Sort-Object -Property name | Select-Object -First $maxListed)) {
    $fields = ($item.changed_fields -join ", ")
    $ledgerLines += "- $($item.name): $fields"
  }
  if ($changedCases.Count -gt $maxListed) {
    $ledgerLines += "- ... ($($changedCases.Count - $maxListed) more)"
  }
}
$ledgerLines += ""
$ledgerLines += "## Added Cases"
$ledgerLines += ""
if ($addedCaseNames.Count -eq 0) {
  $ledgerLines += "- none"
} else {
  foreach ($name in ($addedCaseNames | Select-Object -First $maxListed)) {
    $ledgerLines += "- $name"
  }
  if ($addedCaseNames.Count -gt $maxListed) {
    $ledgerLines += "- ... ($($addedCaseNames.Count - $maxListed) more)"
  }
}
$ledgerLines += ""
$ledgerLines += "## Removed Cases"
$ledgerLines += ""
if ($removedCaseNames.Count -eq 0) {
  $ledgerLines += "- none"
} else {
  foreach ($name in ($removedCaseNames | Select-Object -First $maxListed)) {
    $ledgerLines += "- $name"
  }
  if ($removedCaseNames.Count -gt $maxListed) {
    $ledgerLines += "- ... ($($removedCaseNames.Count - $maxListed) more)"
  }
}

$ledgerContent = ($ledgerLines -join "`n") + "`n"
$ledgerChanged = Write-TextFileIfChanged -Path $ledgerPathRef.Absolute -Content $ledgerContent

Write-Host "Wrote failure snapshot: $($failureSnapshotPathRef.Absolute)"
if ($ledgerChanged) {
  Write-Host "Wrote ledger: $($ledgerPathRef.Absolute)"
} else {
  Write-Host "Ledger unchanged: $($ledgerPathRef.Absolute)"
}
Write-Host "summary cases_added=$($addedCaseNames.Count) cases_removed=$($removedCaseNames.Count) cases_changed=$($changedCases.Count) failures_new=$($newFailureNames.Count) failures_resolved=$($resolvedFailureNames.Count) failures_changed=$($changedFailureNames.Count)"
