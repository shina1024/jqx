param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot "jq_upstream_import.json"),
  [string]$OutputPath = (Join-Path $PSScriptRoot "jq_compat_cases.upstream.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PathOrRelative {
  param(
    [string]$BaseDir,
    [string]$PathValue
  )

  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $PathValue))
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Value
  )

  $dir = Split-Path -Parent $Path
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $json = $Value | ConvertTo-Json -Depth 30
  $normalized = ($json -replace "`r?`n", "`r`n")
  if (-not $normalized.EndsWith("`r`n")) {
    $normalized += "`r`n"
  }
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

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
$sourceRoot = Resolve-PathOrRelative -BaseDir $repoRoot -PathValue $sourceRootRel
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

$compileFailExpectErrorMode = "any"
if ($config.PSObject.Properties.Name -contains "compile_fail_expect_error_mode" -and $null -ne $config.compile_fail_expect_error_mode) {
  $candidate = ([string]$config.compile_fail_expect_error_mode).ToLowerInvariant()
  if ($candidate -ne "strict" -and $candidate -ne "any" -and $candidate -ne "ignore_msg") {
    throw "compile_fail_expect_error_mode must be one of: strict, any, ignore_msg"
  }
  $compileFailExpectErrorMode = $candidate
}

$defaultFields = $null
if ($config.PSObject.Properties.Name -contains "default_case_fields" -and $null -ne $config.default_case_fields) {
  $defaultFields = $config.default_case_fields
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

foreach ($item in $allParsed) {
  $statsTotal += 1

  if ($item.kind -eq "compile_fail" -and -not $includeCompileFail) {
    $statsCompileFailSkipped += 1
    continue
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
    $case["expect_error_mode"] = if ($item.ignore_msg) { "any" } else { $compileFailExpectErrorMode }
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

  if ($null -ne $defaultFields) {
    Apply-ObjectProperties -Target $case -Patch $defaultFields
  }

  $outputCases += [pscustomobject]$case
  $statsEmitted += 1
}

$outputPathAbs = Resolve-PathOrRelative -BaseDir $repoRoot -PathValue $OutputPath
Write-JsonFile -Path $outputPathAbs -Value $outputCases

Write-Host "Generated upstream cases: $outputPathAbs"
Write-Host "summary total=$statsTotal emitted=$statsEmitted compile_fail_skipped=$statsCompileFailSkipped"
