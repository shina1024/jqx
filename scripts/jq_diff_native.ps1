param(
  [string]$CasesPath = (Join-Path $PSScriptRoot "jq_exit_cases.json"),
  [string]$JqExecutable = "jq",
  [string]$JqxExecutable = ""
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

function Resolve-JqxExecutable {
  param(
    [string]$Preferred,
    [string]$RepoRoot
  )

  if ($Preferred -ne "") {
    if (Test-Path $Preferred) {
      return (Resolve-Path $Preferred).Path
    }
    throw "jqx executable not found: $Preferred"
  }

  $candidates = @(
    (Join-Path $RepoRoot "_build/native/release/build/cmd/cmd.exe"),
    (Join-Path $RepoRoot "_build/native/release/build/cmd/cmd"),
    (Join-Path $RepoRoot "_build/native/debug/build/cmd/cmd.exe"),
    (Join-Path $RepoRoot "_build/native/debug/build/cmd/cmd")
  )
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return (Resolve-Path $candidate).Path
    }
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
  & $resolvedMoon build --target native cmd *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "failed to build native jqx executable"
  }

  $resolvedJqx = Resolve-JqxExecutable -Preferred $JqxExecutable -RepoRoot $repoRoot
  if ($null -eq $resolvedJqx) {
    throw "jqx native executable not found under _build/native/{release,debug}/build/cmd"
  }

  $total = 0
  $passed = 0
  $failed = 0

  foreach ($case in $cases) {
    $total += 1
    $name = [string]$case.name
    $filter = [string]$case.filter
    $input = [string]$case.input
    $expectError = $false
    if ($case.PSObject.Properties.Name -contains "expect_error" -and $null -ne $case.expect_error) {
      $expectError = [bool]$case.expect_error
    }
    $expectStatus = $null
    if ($case.PSObject.Properties.Name -contains "expect_status" -and $null -ne $case.expect_status) {
      $expectStatus = [int]$case.expect_status
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

    $jqCmd = @("-c") + $jqArgs + @($filter)
    $jqRaw = $input | & $resolvedJq @jqCmd 2>&1
    $jqStatus = $LASTEXITCODE
    $jqOut = Normalize-Output $jqRaw

    $jqxRaw = if ($jqxUseStdin) {
      $input | & $resolvedJqx @jqxArgs $filter 2>&1
    } else {
      & $resolvedJqx @jqxArgs $filter $input 2>&1
    }
    $jqxStatus = $LASTEXITCODE
    $jqxOut = Normalize-Output $jqxRaw

    $ok = $false
    if ($expectError) {
      if ($jqStatus -ne 0 -and $jqxStatus -ne 0) {
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
      Write-Host "[FAIL] $name"
      Write-Host "  filter: $filter"
      Write-Host "  input: $input"
      Write-Host "  jq status=$jqStatus output=$jqOut"
      Write-Host "  jqx status=$jqxStatus output=$jqxOut"
    }
  }

  Write-Host ""
  Write-Host "Summary: total=$total passed=$passed failed=$failed"
  if ($failed -ne 0) {
    exit 1
  }
} finally {
  Pop-Location
}
