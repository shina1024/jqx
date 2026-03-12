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

  $repoRootWithSlash = $RepoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  $repoUri = [System.Uri]::new($repoRootWithSlash)
  $absoluteUri = [System.Uri]::new($absolute)
  $relative = [System.Uri]::UnescapeDataString($repoUri.MakeRelativeUri($absoluteUri).ToString())
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

function Read-JsonArrayFromText {
  param([AllowNull()][string]$Raw)

  if ($null -eq $Raw -or [string]::IsNullOrWhiteSpace($Raw)) {
    return @()
  }
  $parsed = $Raw | ConvertFrom-Json
  if ($parsed -is [System.Array]) {
    return @($parsed)
  }
  return @($parsed)
}

function Read-JsonArrayFromFile {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }
  return @(Read-JsonArrayFromText -Raw (Get-Content -Raw $Path))
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

  return @(Read-JsonArrayFromText -Raw (Read-HeadFileRaw -RepoRoot $RepoRoot -RepoRelativePath $RepoRelativePath))
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

function Get-CompatStatus {
  param([psobject]$Case)

  if ($Case.PSObject.Properties.Name -contains "compat_status" -and $null -ne $Case.compat_status) {
    return ([string]$Case.compat_status).ToLowerInvariant()
  }
  return "pass"
}

function Get-CompatField {
  param(
    [psobject]$Case,
    [string]$Name
  )

  if ($Case.PSObject.Properties.Name -contains $Name -and $null -ne $Case.$Name) {
    return [string]$Case.$Name
  }
  return ""
}

function Get-CaseSkipReason {
  param([psobject]$Case)

  return Get-CompatField -Case $Case -Name "skip_reason"
}

function Build-CaseComparableRecord {
  param([psobject]$Case)

  return [ordered]@{
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
    skip_reason = Get-CaseSkipReason -Case $Case
    compat_status = Get-CompatStatus -Case $Case
    compat_ledger_id = Get-CompatField -Case $Case -Name "compat_ledger_id"
    compat_reason = Get-CompatField -Case $Case -Name "compat_reason"
    compat_removal_condition = Get-CompatField -Case $Case -Name "compat_removal_condition"
  }
}

function Build-DiffComparableRecord {
  param([psobject]$Record)

  return [ordered]@{
    name = [string]$Record.name
    category = if ($Record.PSObject.Properties.Name -contains "category" -and $null -ne $Record.category) { [string]$Record.category } else { "" }
    compat_status = if ($Record.PSObject.Properties.Name -contains "compat_status" -and $null -ne $Record.compat_status) { [string]$Record.compat_status } else { "" }
    compat_ledger_id = if ($Record.PSObject.Properties.Name -contains "compat_ledger_id" -and $null -ne $Record.compat_ledger_id) { [string]$Record.compat_ledger_id } else { "" }
    compat_reason = if ($Record.PSObject.Properties.Name -contains "compat_reason" -and $null -ne $Record.compat_reason) { [string]$Record.compat_reason } else { "" }
    compat_removal_condition = if ($Record.PSObject.Properties.Name -contains "compat_removal_condition" -and $null -ne $Record.compat_removal_condition) { [string]$Record.compat_removal_condition } else { "" }
    jq_status = if ($Record.PSObject.Properties.Name -contains "jq_status" -and $null -ne $Record.jq_status) { [string]$Record.jq_status } else { "" }
    jqx_status = if ($Record.PSObject.Properties.Name -contains "jqx_status" -and $null -ne $Record.jqx_status) { [string]$Record.jqx_status } else { "" }
    jq_out = if ($Record.PSObject.Properties.Name -contains "jq_out" -and $null -ne $Record.jq_out) { [string]$Record.jq_out } else { "" }
    jqx_out = if ($Record.PSObject.Properties.Name -contains "jqx_out" -and $null -ne $Record.jqx_out) { [string]$Record.jqx_out } else { "" }
  }
}

function Get-ChangedFields {
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

function Build-CaseMap {
  param([object[]]$Cases)

  $map = @{}
  foreach ($case in $Cases) {
    $map[[string]$case.name] = $case
  }
  return $map
}

function Build-DiffRecordMap {
  param([object[]]$Records)

  $map = @{}
  foreach ($record in $Records) {
    $map[[string]$record.name] = $record
  }
  return $map
}

function Validate-CaseMetadata {
  param(
    [object[]]$Cases,
    [string]$CorpusName
  )

  $errors = @()
  $seen = @{}

  foreach ($case in $Cases) {
    $name = [string]$case.name
    if ($name -eq "") {
      $errors += "$CorpusName case is missing a name"
      continue
    }
    if ($seen.ContainsKey($name)) {
      $errors += "$CorpusName case name is duplicated: $name"
    } else {
      $seen[$name] = $true
    }

    $compatStatus = Get-CompatStatus -Case $case
    $compatLedgerId = Get-CompatField -Case $case -Name "compat_ledger_id"
    $compatReason = Get-CompatField -Case $case -Name "compat_reason"
    $compatRemovalCondition = Get-CompatField -Case $case -Name "compat_removal_condition"
    $skipReason = Get-CaseSkipReason -Case $case

    if ($compatStatus -ne "pass" -and $compatStatus -ne "temporary_exception") {
      $errors += "$CorpusName case $name has invalid compat_status: $compatStatus"
    }

    if ($compatStatus -eq "temporary_exception") {
      if ([string]::IsNullOrWhiteSpace($compatLedgerId)) {
        $errors += "$CorpusName case $name is missing compat_ledger_id"
      }
      if ([string]::IsNullOrWhiteSpace($compatReason)) {
        $errors += "$CorpusName case $name is missing compat_reason"
      }
      if ([string]::IsNullOrWhiteSpace($compatRemovalCondition)) {
        $errors += "$CorpusName case $name is missing compat_removal_condition"
      }
    } else {
      if (-not [string]::IsNullOrWhiteSpace($compatLedgerId) -or -not [string]::IsNullOrWhiteSpace($compatReason) -or -not [string]::IsNullOrWhiteSpace($compatRemovalCondition)) {
        $errors += "$CorpusName case $name has exception metadata but compat_status=pass"
      }
      if (-not [string]::IsNullOrWhiteSpace($skipReason)) {
        $errors += "$CorpusName case $name uses skip_reason without compat_status=temporary_exception"
      }
    }
  }

  return $errors
}

function Run-DiffSnapshot {
  param(
    [string]$JqDiffScript,
    [string]$CasesPathValue
  )

  $tempSnapshot = Join-Path ([System.IO.Path]::GetTempPath()) ("jq-diff-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    & $JqDiffScript -CasesPath $CasesPathValue -SnapshotPath $tempSnapshot
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0 -and $exitCode -ne 1) {
      throw "jq_diff.ps1 failed with unexpected exit code: $exitCode"
    }
    return [PSCustomObject]@{
      ExitCode = $exitCode
      Records = @(Read-JsonArrayFromFile -Path $tempSnapshot)
    }
  } finally {
    Remove-Item -Path $tempSnapshot -ErrorAction SilentlyContinue
  }
}

function New-SnapshotContent {
  param([object[]]$Records)

  $json = ConvertTo-PrettyJson -Value @($Records)
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  return $json
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

function Get-CorpusStatus {
  param(
    [string]$CorpusName,
    [object[]]$Cases,
    [object[]]$DiffRecords
  )

  $caseMap = Build-CaseMap -Cases $Cases
  $recordMap = Build-DiffRecordMap -Records $DiffRecords

  $activeTemporary = @()
  $staleTemporary = @()
  $broken = @()

  foreach ($case in $Cases) {
    if ((Get-CompatStatus -Case $case) -ne "temporary_exception") {
      continue
    }

    $name = [string]$case.name
    $record = $null
    if ($recordMap.ContainsKey($name)) {
      $record = $recordMap[$name]
    }
    $skipReason = Get-CaseSkipReason -Case $case
    if ($null -eq $record) {
      if (-not [string]::IsNullOrWhiteSpace($skipReason)) {
        $activeTemporary += [PSCustomObject]@{
          Case = $case
          Record = $null
          Corpus = $CorpusName
        }
      } else {
        $staleTemporary += [PSCustomObject]@{
          Case = $case
          Record = $null
          Corpus = $CorpusName
        }
      }
      continue
    }

    $category = [string]$record.category
    if ($category -eq "temporary-exception") {
      $activeTemporary += [PSCustomObject]@{
        Case = $case
        Record = $record
        Corpus = $CorpusName
      }
    } else {
      $staleTemporary += [PSCustomObject]@{
        Case = $case
        Record = $record
        Corpus = $CorpusName
      }
    }
  }

  foreach ($record in $DiffRecords) {
    $category = [string]$record.category
    if ($category -eq "temporary-exception" -or $category -eq "stale-temporary-exception") {
      continue
    }
    $case = $null
    if ($caseMap.ContainsKey([string]$record.name)) {
      $case = $caseMap[[string]$record.name]
    }
    $broken += [PSCustomObject]@{
      Case = $case
      Record = $record
      Corpus = $CorpusName
    }
  }

  $passingCount = $Cases.Count - $activeTemporary.Count - $staleTemporary.Count - $broken.Count
  return [PSCustomObject]@{
    Corpus = $CorpusName
    Total = $Cases.Count
    PassingCount = $passingCount
    ActiveTemporary = $activeTemporary
    StaleTemporary = $staleTemporary
    Broken = $broken
  }
}

function Add-ListSection {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$Title,
    [string[]]$Entries
  )

  $Lines.Add("## $Title")
  $Lines.Add("")
  if ($Entries.Count -eq 0) {
    $Lines.Add("- none")
  } else {
    foreach ($entry in $Entries) {
      $Lines.Add("- $entry")
    }
  }
  $Lines.Add("")
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$maintainedCasesRef = Resolve-RepoRelativePath -RepoRoot $repoRoot -PathValue $MaintainedCasesPath
$upstreamCasesRef = Resolve-RepoRelativePath -RepoRoot $repoRoot -PathValue $CasesPath
$failureSnapshotPathRef = Resolve-RepoRelativePath -RepoRoot $repoRoot -PathValue $FailureSnapshotPath
$ledgerPathRef = Resolve-RepoRelativePath -RepoRoot $repoRoot -PathValue $LedgerPath

if (-not (Test-Path $maintainedCasesRef.Absolute)) {
  throw "maintained cases file not found: $($maintainedCasesRef.Absolute)"
}
if (-not (Test-Path $upstreamCasesRef.Absolute)) {
  throw "upstream cases file not found: $($upstreamCasesRef.Absolute)"
}

$maintainedCases = @(Read-JsonArrayFromFile -Path $maintainedCasesRef.Absolute)
$upstreamCases = @(Read-JsonArrayFromFile -Path $upstreamCasesRef.Absolute)

$metadataErrors = @()
$metadataErrors += @(Validate-CaseMetadata -Cases $maintainedCases -CorpusName "maintained")
$metadataErrors += @(Validate-CaseMetadata -Cases $upstreamCases -CorpusName "upstream")
if ($metadataErrors.Count -gt 0) {
  throw ("compatibility metadata validation failed:`n- " + ($metadataErrors -join "`n- "))
}

$jqDiffScript = Join-Path $PSScriptRoot "jq_diff.ps1"
$upstreamDiffResult = if ($SkipDifferential) {
  [PSCustomObject]@{
    ExitCode = 0
    Records = @(Read-JsonArrayFromFile -Path $failureSnapshotPathRef.Absolute)
  }
} else {
  Run-DiffSnapshot -JqDiffScript $jqDiffScript -CasesPathValue $upstreamCasesRef.Absolute
}
$maintainedDiffResult = if ($SkipDifferential) {
  [PSCustomObject]@{
    ExitCode = 0
    Records = @()
  }
} else {
  Run-DiffSnapshot -JqDiffScript $jqDiffScript -CasesPathValue $maintainedCasesRef.Absolute
}

$upstreamRecords = @($upstreamDiffResult.Records | Sort-Object -Property name, category)
$maintainedRecords = @($maintainedDiffResult.Records | Sort-Object -Property name, category)
$snapshotContent = New-SnapshotContent -Records $upstreamRecords

$maintainedStatus = Get-CorpusStatus -CorpusName "maintained" -Cases $maintainedCases -DiffRecords $maintainedRecords
$upstreamStatus = Get-CorpusStatus -CorpusName "upstream" -Cases $upstreamCases -DiffRecords $upstreamRecords

$oldUpstreamCases = @(Read-JsonArrayFromHead -RepoRoot $repoRoot -RepoRelativePath $upstreamCasesRef.Relative)
$oldUpstreamCaseMap = Build-CaseMap -Cases $oldUpstreamCases
$newUpstreamCaseMap = Build-CaseMap -Cases $upstreamCases
$addedCaseNames = @($newUpstreamCaseMap.Keys | Where-Object { -not $oldUpstreamCaseMap.ContainsKey($_) } | Sort-Object)
$removedCaseNames = @($oldUpstreamCaseMap.Keys | Where-Object { -not $newUpstreamCaseMap.ContainsKey($_) } | Sort-Object)
$changedCases = @()
foreach ($name in ($newUpstreamCaseMap.Keys | Where-Object { $oldUpstreamCaseMap.ContainsKey($_) } | Sort-Object)) {
  $oldRecord = Build-CaseComparableRecord -Case $oldUpstreamCaseMap[$name]
  $newRecord = Build-CaseComparableRecord -Case $newUpstreamCaseMap[$name]
  $changedFields = @(Get-ChangedFields -OldRecord $oldRecord -NewRecord $newRecord)
  if ($changedFields.Count -gt 0) {
    $changedCases += [PSCustomObject]@{
      name = $name
      changed_fields = @($changedFields)
    }
  }
}

$oldUpstreamRecords = @(Read-JsonArrayFromHead -RepoRoot $repoRoot -RepoRelativePath $failureSnapshotPathRef.Relative)
$oldUpstreamRecordMap = Build-DiffRecordMap -Records $oldUpstreamRecords
$newUpstreamRecordMap = Build-DiffRecordMap -Records $upstreamRecords
$newDifferenceNames = @($newUpstreamRecordMap.Keys | Where-Object { -not $oldUpstreamRecordMap.ContainsKey($_) } | Sort-Object)
$resolvedDifferenceNames = @($oldUpstreamRecordMap.Keys | Where-Object { -not $newUpstreamRecordMap.ContainsKey($_) } | Sort-Object)
$changedDifferenceNames = @()
foreach ($name in ($newUpstreamRecordMap.Keys | Where-Object { $oldUpstreamRecordMap.ContainsKey($_) } | Sort-Object)) {
  $oldRecord = Build-DiffComparableRecord -Record $oldUpstreamRecordMap[$name]
  $newRecord = Build-DiffComparableRecord -Record $newUpstreamRecordMap[$name]
  if ((ConvertTo-CanonicalJson $oldRecord) -ne (ConvertTo-CanonicalJson $newRecord)) {
    $changedDifferenceNames += $name
  }
}

$headUpstreamCommit = Read-HeadTextLine -RepoRoot $repoRoot -RepoRelativePath "third_party/jq-tests/UPSTREAM_COMMIT"
$currentUpstreamCommit = ""
$currentCommitPath = Join-Path $repoRoot "third_party/jq-tests/UPSTREAM_COMMIT"
if (Test-Path $currentCommitPath) {
  $currentUpstreamCommit = (Get-Content -Raw $currentCommitPath).Trim()
}

$ledgerLines = [System.Collections.Generic.List[string]]::new()
$ledgerLines.Add("# jq Compatibility Diff Ledger")
$ledgerLines.Add("")
$ledgerLines.Add("- maintained cases: ``$($maintainedCasesRef.Relative)``")
$ledgerLines.Add("- upstream cases: ``$($upstreamCasesRef.Relative)``")
$ledgerLines.Add("- upstream diff snapshot: ``$($failureSnapshotPathRef.Relative)``")
$ledgerLines.Add("- upstream commit (HEAD): ``$headUpstreamCommit``")
$ledgerLines.Add("- upstream commit (current): ``$currentUpstreamCommit``")
$ledgerLines.Add("")
$ledgerLines.Add("## Corpus Status")
$ledgerLines.Add("")
$ledgerLines.Add("| Corpus | Total | Passing | Temporary Exceptions | Broken | Stale Exception Metadata |")
$ledgerLines.Add("| --- | ---: | ---: | ---: | ---: | ---: |")
$ledgerLines.Add("| maintained | $($maintainedStatus.Total) | $($maintainedStatus.PassingCount) | $($maintainedStatus.ActiveTemporary.Count) | $($maintainedStatus.Broken.Count) | $($maintainedStatus.StaleTemporary.Count) |")
$ledgerLines.Add("| upstream | $($upstreamStatus.Total) | $($upstreamStatus.PassingCount) | $($upstreamStatus.ActiveTemporary.Count) | $($upstreamStatus.Broken.Count) | $($upstreamStatus.StaleTemporary.Count) |")
$ledgerLines.Add("")

$temporaryEntries = @()
foreach ($item in @($maintainedStatus.ActiveTemporary + $upstreamStatus.ActiveTemporary) | Sort-Object { $_.Corpus }, { [string]$_.Case.name }) {
  $case = $item.Case
  $temporaryEntries += "[{0}] {1} (`{2}`): {3}. Remove when {4}" -f $item.Corpus, [string]$case.name, (Get-CompatField -Case $case -Name "compat_ledger_id"), (Get-CompatField -Case $case -Name "compat_reason"), (Get-CompatField -Case $case -Name "compat_removal_condition")
}
Add-ListSection -Lines $ledgerLines -Title "Temporary Exceptions" -Entries $temporaryEntries

$brokenEntries = @()
foreach ($item in @($maintainedStatus.Broken + $upstreamStatus.Broken) | Sort-Object { $_.Corpus }, { [string]$_.Record.name }) {
  $brokenEntries += "[{0}] {1} (`{2}`)" -f $item.Corpus, [string]$item.Record.name, [string]$item.Record.category
}
Add-ListSection -Lines $ledgerLines -Title "Broken Cases" -Entries $brokenEntries

$staleEntries = @()
foreach ($item in @($maintainedStatus.StaleTemporary + $upstreamStatus.StaleTemporary) | Sort-Object { $_.Corpus }, { [string]$_.Case.name }) {
  $case = $item.Case
  $staleEntries += "[{0}] {1} (`{2}`)" -f $item.Corpus, [string]$case.name, (Get-CompatField -Case $case -Name "compat_ledger_id")
}
Add-ListSection -Lines $ledgerLines -Title "Stale Exception Metadata" -Entries $staleEntries

$summaryEntries = @(
  "upstream cases old/new: $($oldUpstreamCases.Count) -> $($upstreamCases.Count)",
  "upstream cases added/removed/changed: $($addedCaseNames.Count) / $($removedCaseNames.Count) / $($changedCases.Count)",
  "upstream differences old/new: $($oldUpstreamRecords.Count) -> $($upstreamRecords.Count)",
  "upstream differences new/resolved/changed: $($newDifferenceNames.Count) / $($resolvedDifferenceNames.Count) / $($changedDifferenceNames.Count)"
)
Add-ListSection -Lines $ledgerLines -Title "Upstream Drift Summary" -Entries $summaryEntries

$newDifferenceEntries = @()
foreach ($name in $newDifferenceNames) {
  $record = $newUpstreamRecordMap[$name]
  $newDifferenceEntries += "{0} (`{1}`)" -f $name, [string]$record.category
}
Add-ListSection -Lines $ledgerLines -Title "New Upstream Differences" -Entries $newDifferenceEntries

$resolvedDifferenceEntries = @($resolvedDifferenceNames | ForEach-Object { [string]$_ })
Add-ListSection -Lines $ledgerLines -Title "Resolved Upstream Differences" -Entries $resolvedDifferenceEntries

$changedDifferenceEntries = @()
foreach ($name in $changedDifferenceNames) {
  $oldCategory = [string]$oldUpstreamRecordMap[$name].category
  $newCategory = [string]$newUpstreamRecordMap[$name].category
  $changedDifferenceEntries += "{0} (`{1}` -> `{2}`)" -f $name, $oldCategory, $newCategory
}
Add-ListSection -Lines $ledgerLines -Title "Upstream Difference Behavior Changes" -Entries $changedDifferenceEntries

$changedCaseEntries = @()
foreach ($item in ($changedCases | Sort-Object -Property name)) {
  $changedCaseEntries += "{0}: {1}" -f $item.name, ($item.changed_fields -join ", ")
}
Add-ListSection -Lines $ledgerLines -Title "Upstream Case Behavior Changes" -Entries $changedCaseEntries

$addedCaseEntries = @($addedCaseNames | ForEach-Object { [string]$_ })
Add-ListSection -Lines $ledgerLines -Title "Added Upstream Cases" -Entries $addedCaseEntries

$removedCaseEntries = @($removedCaseNames | ForEach-Object { [string]$_ })
Add-ListSection -Lines $ledgerLines -Title "Removed Upstream Cases" -Entries $removedCaseEntries

$ledgerContent = ($ledgerLines -join "`n") + "`n"

if ($Verify) {
  $existingSnapshotContent = if (Test-Path $failureSnapshotPathRef.Absolute) { Get-Content -Raw $failureSnapshotPathRef.Absolute } else { "" }
  if ($existingSnapshotContent -ne $snapshotContent) {
    throw "upstream diff snapshot is out of date: $($failureSnapshotPathRef.Relative)"
  }

  $existingLedgerContent = if (Test-Path $ledgerPathRef.Absolute) { Get-Content -Raw $ledgerPathRef.Absolute } else { "" }
  if ($existingLedgerContent -ne $ledgerContent) {
    throw "compatibility ledger is out of date: $($ledgerPathRef.Relative)"
  }

  Write-Host "Verified upstream diff snapshot: $($failureSnapshotPathRef.Absolute)"
  Write-Host "Verified compatibility ledger: $($ledgerPathRef.Absolute)"
} else {
  [void](Write-TextFileIfChanged -Path $failureSnapshotPathRef.Absolute -Content $snapshotContent)
  [void](Write-TextFileIfChanged -Path $ledgerPathRef.Absolute -Content $ledgerContent)
  Write-Host "Wrote upstream diff snapshot: $($failureSnapshotPathRef.Absolute)"
  Write-Host "Wrote compatibility ledger: $($ledgerPathRef.Absolute)"
}

Write-Host ("summary maintained_temp={0} maintained_broken={1} upstream_temp={2} upstream_broken={3}" -f $maintainedStatus.ActiveTemporary.Count, $maintainedStatus.Broken.Count, $upstreamStatus.ActiveTemporary.Count, $upstreamStatus.Broken.Count)
