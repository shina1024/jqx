param(
  [string]$CasesPath = (Join-Path $PSScriptRoot "jq_compat_cases.json"),
  [string]$JqExecutable = "jq",
  [string]$SnapshotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-JqExecutable {
  param([string]$Preferred)

  $direct = Get-Command $Preferred -ErrorAction SilentlyContinue
  if ($null -ne $direct) {
    return $direct.Source
  }

  # Fallback for mise-managed jq even when PATH is not initialized.
  $mise = Get-Command mise -ErrorAction SilentlyContinue
  if ($null -ne $mise) {
    $jqPath = & $mise.Source which jq 2>$null
    if ($LASTEXITCODE -eq 0) {
      $jqPath = [string]$jqPath
      $jqPath = $jqPath.Trim()
      if ($jqPath -ne "" -and (Test-Path $jqPath)) {
        return $jqPath
      }
    }
  }

  return $null
}

function Resolve-MoonExecutable {
  $direct = Get-Command moon -ErrorAction SilentlyContinue
  if ($null -ne $direct) {
    return $direct.Source
  }

  $directExe = Get-Command moon.exe -ErrorAction SilentlyContinue
  if ($null -ne $directExe) {
    return $directExe.Source
  }

  $homeMoon = Join-Path $HOME ".moon\bin\moon.exe"
  if (Test-Path $homeMoon) {
    return $homeMoon
  }

  return $null
}

function Normalize-Output {
  param([AllowNull()][object]$Value)

  function Clean-Line([string]$Line) {
    if ($Line -like "Blocking waiting for file lock *") {
      return $null
    }
    return $Line
  }

  if ($null -eq $Value) {
    return ""
  }

  if ($Value -is [System.Array]) {
    $clean = @()
    foreach ($entry in $Value) {
      $line = Clean-Line ($entry.ToString())
      if ($null -ne $line) {
        $clean += $line
      }
    }
    return ($clean -join "`n").TrimEnd("`r", "`n")
  }

  $single = Clean-Line ($Value.ToString())
  if ($null -eq $single) {
    return ""
  }
  return $single.TrimEnd("`r", "`n")
}

function Normalize-ErrorMessage {
  param([AllowNull()][string]$Value)

  if ($null -eq $Value) {
    return ""
  }

  $normalized = $Value.Trim()
  $normalized = $normalized -replace '^jq: error(?: \(at <stdin>:[0-9:]+\))?:\s*', ''
  $normalized = $normalized -replace '^jqx: error(?: \(at <stdin>:[0-9:]+\))?:\s*', ''
  return $normalized
}

function Classify-Failure {
  param(
    [int]$JqStatus,
    [int]$JqxStatus,
    [string]$JqOut,
    [string]$JqxOut
  )

  if ($JqxOut -match "Invalid character ") {
    return "parser-invalid-character"
  }
  if ($JqxOut -match "Invalid number") {
    return "parser-invalid-number"
  }
  if ($JqxOut -match "Unknown function: ") {
    return "unknown-function"
  }
  if ($JqxOut -match "Unknown variable: ") {
    return "unknown-variable"
  }
  if ($JqStatus -eq 0 -and ($JqxOut.StartsWith("jqx: error") -or $JqxStatus -ne 0)) {
    return "runtime-error-vs-jq-success"
  }
  return "output-mismatch"
}

function Invoke-NativeCapture {
  param(
    [string]$Exe,
    [string[]]$CmdArgs = @(),
    [string]$Stdin = "",
    [switch]$UseStdin
  )

  $prevErrorActionPreference = $ErrorActionPreference
  $hasNativeErrorPreference = Test-Path Variable:PSNativeCommandUseErrorActionPreference
  $prevNativeErrorPreference = $false
  if ($hasNativeErrorPreference) {
    $prevNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
  }
  $ErrorActionPreference = "Continue"
  try {
    if ($UseStdin) {
      $raw = $Stdin | & $Exe @CmdArgs 2>&1
    } else {
      $raw = & $Exe @CmdArgs 2>&1
    }
    $status = $LASTEXITCODE
    return [PSCustomObject]@{
      Raw = $raw
      Status = $status
    }
  } finally {
    $ErrorActionPreference = $prevErrorActionPreference
    if ($hasNativeErrorPreference) {
      $PSNativeCommandUseErrorActionPreference = $prevNativeErrorPreference
    }
  }
}

if (-not (Test-Path $CasesPath)) {
  throw "cases file not found: $CasesPath"
}

$resolvedJq = Resolve-JqExecutable -Preferred $JqExecutable
if ($null -eq $resolvedJq) {
  throw "jq binary not found: $JqExecutable (also checked mise)"
}

$resolvedMoon = Resolve-MoonExecutable
if ($null -eq $resolvedMoon) {
  throw "moon command not found (checked moon, moon.exe, and ~/.moon/bin/moon.exe)"
}

$casesRaw = Get-Content -Raw $CasesPath
$cases = $casesRaw | ConvertFrom-Json
if ($cases -isnot [System.Array]) {
  throw "invalid cases file format: expected top-level array"
}

$repoRoot = Join-Path $PSScriptRoot ".."

Push-Location $repoRoot
try {
  $warmup = Invoke-NativeCapture `
    -Exe $resolvedMoon `
    -CmdArgs @("run", "--target", "native", "cmd", "--", ".", "null")
  if ($warmup.Status -ne 0) {
    throw "failed to warm up jqx command via moon run: $(Normalize-Output $warmup.Raw)"
  }

  $total = 0
  $passed = 0
  $failed = 0
  $skipped = 0
  $failureRecords = @()

  foreach ($case in $cases) {
    $total += 1
    $name = [string]$case.name
    $filter = [string]$case.filter
    $input = [string]$case.input
    $expectError = $false
    if ($case.PSObject.Properties.Name -contains "expect_error" -and $null -ne $case.expect_error) {
      $expectError = [bool]$case.expect_error
    }
    $expectErrorMode = "strict"
    if ($case.PSObject.Properties.Name -contains "expect_error_mode" -and $null -ne $case.expect_error_mode) {
      $expectErrorMode = ([string]$case.expect_error_mode).ToLowerInvariant()
    }
    $expectStatus = $null
    if ($case.PSObject.Properties.Name -contains "expect_status" -and $null -ne $case.expect_status) {
      $expectStatus = [int]$case.expect_status
    }
    $skipReason = ""
    if ($case.PSObject.Properties.Name -contains "skip_reason" -and $null -ne $case.skip_reason) {
      $skipReason = [string]$case.skip_reason
    }
    $jqArgs = @()
    if ($case.PSObject.Properties.Name -contains "jq_args" -and $null -ne $case.jq_args) {
      $jqArgs = @($case.jq_args | ForEach-Object { [string]$_ })
    }
    $jqxArgs = @()
    if ($case.PSObject.Properties.Name -contains "jqx_args" -and $null -ne $case.jqx_args) {
      $jqxArgs = @($case.jqx_args | ForEach-Object { [string]$_ })
    }
    $jqxUseStdin = $false
    if ($case.PSObject.Properties.Name -contains "jqx_use_stdin" -and $null -ne $case.jqx_use_stdin) {
      $jqxUseStdin = [bool]$case.jqx_use_stdin
    }

    if ($skipReason -ne "") {
      $skipped += 1
      Write-Host "[SKIP] $name ($skipReason)"
      continue
    }

    $jqCmd = @("-c") + $jqArgs + @($filter)
    $jqRun = Invoke-NativeCapture `
      -Exe $resolvedJq `
      -CmdArgs $jqCmd `
      -Stdin $input `
      -UseStdin
    $jqStatus = $jqRun.Status
    $jqOut = Normalize-Output $jqRun.Raw

    $jqxCmd = @("run", "--target", "native", "cmd", "--") + $jqxArgs + @($filter)
    $jqxRun = if ($jqxUseStdin) {
      Invoke-NativeCapture `
        -Exe $resolvedMoon `
        -CmdArgs $jqxCmd `
        -Stdin $input `
        -UseStdin
    } else {
      Invoke-NativeCapture `
        -Exe $resolvedMoon `
        -CmdArgs ($jqxCmd + @($input))
    }
    $jqxStatus = $jqxRun.Status
    $jqxOut = Normalize-Output $jqxRun.Raw

    $ok = $false
    if ($expectError) {
      $jqMessage = Normalize-ErrorMessage $jqOut
      $jqxMessage = Normalize-ErrorMessage $jqxOut
      $jqHasError = $jqStatus -ne 0 -or $jqOut.StartsWith("jq: error")
      $jqxHasError = $jqxStatus -ne 0 -or $jqxOut.StartsWith("jqx: error")
      if ($expectErrorMode -eq "any" -or $expectErrorMode -eq "ignore_msg") {
        if ($jqHasError -and $jqxHasError) {
          $ok = $true
        }
      } elseif ($jqHasError -and $jqxHasError -and $jqMessage -eq $jqxMessage) {
        $ok = $true
      }
    } elseif ($null -ne $expectStatus) {
      if ($jqStatus -eq $expectStatus -and $jqxStatus -eq $expectStatus -and $jqOut -eq $jqxOut) {
        $ok = $true
      }
    } else {
      if ($jqStatus -eq 0 -and $jqxStatus -eq 0 -and $jqOut -eq $jqxOut) {
        $ok = $true
      }
    }

    if ($ok) {
      $passed += 1
      Write-Host "[PASS] $name"
    } else {
      $failed += 1
      $failureRecords += [PSCustomObject]@{
        name = $name
        category = Classify-Failure -JqStatus $jqStatus -JqxStatus $jqxStatus -JqOut $jqOut -JqxOut $jqxOut
        jq_status = [string]$jqStatus
        jqx_status = [string]$jqxStatus
        jq_out = $jqOut
        jqx_out = $jqxOut
      }
      Write-Host "[FAIL] $name"
      Write-Host "  filter: $filter"
      Write-Host "  input: $input"
      if ($expectError) {
        Write-Host "  expect_error_mode=$expectErrorMode"
      }
      Write-Host "  jq status=$jqStatus output=$jqOut"
      Write-Host "  jqx status=$jqxStatus output=$jqxOut"
    }
  }

  Write-Host ""
  Write-Host "Summary: total=$total passed=$passed failed=$failed skipped=$skipped"
  if ($SnapshotPath -ne "") {
    $snapshotFile = if ([System.IO.Path]::IsPathRooted($SnapshotPath)) {
      $SnapshotPath
    } else {
      Join-Path $repoRoot $SnapshotPath
    }
    $snapshotDir = Split-Path -Parent $snapshotFile
    if ($snapshotDir -ne "" -and -not (Test-Path $snapshotDir)) {
      New-Item -ItemType Directory -Path $snapshotDir | Out-Null
    }
    $failureRecords | ConvertTo-Json -Depth 5 | Set-Content -Path $snapshotFile -Encoding UTF8
    Write-Host "Wrote snapshot: $snapshotFile"
  }
  if ($failed -ne 0) {
    exit 1
  }
} finally {
  Pop-Location
}
