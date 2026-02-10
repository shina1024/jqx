param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot "jq_upstream_import.json"),
  [string]$OutputPath = (Join-Path $PSScriptRoot "jq_compat_cases.upstream.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Is-SkipLine {
  param([string]$Line)
  $trimmed = $Line.Trim()
  return $trimmed -eq "" -or $trimmed.StartsWith("#")
}

function Parse-JqTestFile {
  param(
    [string]$TestFilePath,
    [string]$SourceFileName
  )

  $lines = Get-Content $TestFilePath
  $cases = @()

  $i = 0
  $mustFail = $false
  $ignoreMsg = $false

  while ($i -lt $lines.Count) {
    $line = [string]$lines[$i]
    $lineNo = $i + 1

    if (Is-SkipLine $line) {
      $i += 1
      continue
    }

    if ($line -eq "%%FAIL" -or $line -eq "%%FAIL IGNORE MSG") {
      $mustFail = $true
      $ignoreMsg = ($line -eq "%%FAIL IGNORE MSG")
      $i += 1
      continue
    }

    $program = $line
    $programLine = $lineNo
    $i += 1

    if ($mustFail) {
      $errorLines = @()
      while ($i -lt $lines.Count) {
        $candidate = [string]$lines[$i]
        if (Is-SkipLine $candidate) {
          $i += 1
          break
        }
        $errorLines += $candidate
        $i += 1
      }

      $cases += [pscustomobject]@{
        source_file = $SourceFileName
        source_line = $programLine
        kind = "compile_fail"
        ignore_msg = $ignoreMsg
        filter = $program
        input = $null
        expected = @()
        expected_error_lines = $errorLines
      }

      $mustFail = $false
      $ignoreMsg = $false
      continue
    }

    while ($i -lt $lines.Count -and (Is-SkipLine ([string]$lines[$i]))) {
      $i += 1
    }
    if ($i -ge $lines.Count) {
      break
    }

    $input = [string]$lines[$i]
    $i += 1

    $expected = @()
    while ($i -lt $lines.Count) {
      $candidate = [string]$lines[$i]
      if (Is-SkipLine $candidate) {
        $i += 1
        break
      }
      $expected += $candidate
      $i += 1
    }

    $cases += [pscustomobject]@{
      source_file = $SourceFileName
      source_line = $programLine
      kind = "runtime"
      ignore_msg = $false
      filter = $program
      input = $input
      expected = $expected
      expected_error_lines = @()
    }
  }

  return $cases
}

function Apply-ObjectProperties {
  param(
    [System.Collections.IDictionary]$Target,
    [psobject]$Patch
  )

  if ($Patch -is [System.Collections.IDictionary]) {
    foreach ($key in $Patch.Keys) {
      $Target[[string]$key] = $Patch[$key]
    }
    return
  }

  foreach ($property in $Patch.PSObject.Properties) {
    $Target[$property.Name] = $property.Value
  }
}

if (-not (Test-Path $ConfigPath)) {
  throw "config file not found: $ConfigPath"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$config = Get-Content -Raw $ConfigPath | ConvertFrom-Json

$sourceRootRel = [string]$config.source_root
if ($sourceRootRel -eq "") {
  throw "source_root is required in config: $ConfigPath"
}
$sourceRoot = if ([System.IO.Path]::IsPathRooted($sourceRootRel)) {
  [System.IO.Path]::GetFullPath($sourceRootRel)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $repoRoot $sourceRootRel))
}
if (-not (Test-Path $sourceRoot)) {
  throw "source_root not found: $sourceRoot"
}

$enabledFiles = @($config.enabled_test_files | ForEach-Object { [string]$_ })
if ($enabledFiles.Count -eq 0) {
  throw "enabled_test_files is empty in config: $ConfigPath"
}

$includeCompileFail = $false
if ($config.PSObject.Properties.Name -contains "include_compile_fail" -and $null -ne $config.include_compile_fail) {
  $includeCompileFail = [bool]$config.include_compile_fail
}

$skipPatterns = @()
if ($config.PSObject.Properties.Name -contains "skip_program_patterns" -and $null -ne $config.skip_program_patterns) {
  $skipPatterns = @($config.skip_program_patterns)
}

$defaultFields = $null
if ($config.PSObject.Properties.Name -contains "default_case_fields" -and $null -ne $config.default_case_fields) {
  $defaultFields = $config.default_case_fields
}

$overrideMap = @{}
if ($config.PSObject.Properties.Name -contains "overrides" -and $null -ne $config.overrides) {
  if ($config.overrides -is [System.Collections.IDictionary]) {
    foreach ($key in $config.overrides.Keys) {
      $overrideMap[[string]$key] = $config.overrides[$key]
    }
  } else {
    foreach ($property in $config.overrides.PSObject.Properties) {
      $overrideMap[$property.Name] = $property.Value
    }
  }
}

$allParsed = @()
foreach ($fileName in $enabledFiles) {
  $testPath = Join-Path $sourceRoot $fileName
  if (-not (Test-Path $testPath)) {
    throw "enabled test file not found: $testPath"
  }
  $allParsed += Parse-JqTestFile -TestFilePath $testPath -SourceFileName $fileName
}

$outputCases = @()
$statsTotal = 0
$statsEmitted = 0
$statsCompileFailSkipped = 0
$statsPatternSkipped = 0

foreach ($item in $allParsed) {
  $statsTotal += 1

  $key = "$($item.source_file):$($item.source_line)"

  if ($item.kind -eq "compile_fail" -and -not $includeCompileFail) {
    $statsCompileFailSkipped += 1
    continue
  }

  $skipReason = ""
  foreach ($patternRule in $skipPatterns) {
    $pattern = [string]$patternRule.pattern
    if ($pattern -eq "") {
      continue
    }
    if ([string]$item.filter -match $pattern) {
      $skipReason = [string]$patternRule.reason
      if ($skipReason -eq "") {
        $skipReason = "matched-skip-pattern"
      }
      $statsPatternSkipped += 1
      break
    }
  }

  $namePrefix = ($item.source_file -replace "[^A-Za-z0-9]+", "-").ToLowerInvariant().Trim("-")
  $case = [ordered]@{
    name = "upstream-$namePrefix-l$($item.source_line)"
    filter = [string]$item.filter
    input = if ($item.input -eq $null) { "null" } else { [string]$item.input }
    source_file = [string]$item.source_file
    source_line = [int]$item.source_line
    source_kind = [string]$item.kind
  }

  if ($item.kind -eq "compile_fail") {
    $case["expect_error"] = $true
    $case["expect_error_mode"] = if ($item.ignore_msg) { "any" } else { "strict" }
    if ($item.expected_error_lines.Count -gt 0) {
      $case["source_error_lines"] = @($item.expected_error_lines)
    }
  }

  if ($item.expected.Count -gt 0) {
    $case["source_expected_count"] = $item.expected.Count
  }

  if ([string]$item.filter -like "-*") {
    # jqx CLI treats leading '-' as option unless '--' terminates option parsing.
    $case["jqx_args"] = @("--")
  }

  if ($skipReason -ne "") {
    $case["skip_reason"] = $skipReason
  }

  if ($null -ne $defaultFields) {
    Apply-ObjectProperties -Target $case -Patch $defaultFields
  }

  if ($overrideMap.ContainsKey($key)) {
    Apply-ObjectProperties -Target $case -Patch $overrideMap[$key]
  }

  $outputCases += [pscustomobject]$case
  $statsEmitted += 1
}

$outputJson = $outputCases | ConvertTo-Json -Depth 30
$outputPathAbs = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
  [System.IO.Path]::GetFullPath($OutputPath)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
}
$outputDir = Split-Path -Parent $outputPathAbs
if (-not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}
Set-Content -Path $outputPathAbs -Value $outputJson -Encoding UTF8

Write-Host "Generated upstream cases: $outputPathAbs"
Write-Host "summary total=$statsTotal emitted=$statsEmitted compile_fail_skipped=$statsCompileFailSkipped pattern_skipped=$statsPatternSkipped"
