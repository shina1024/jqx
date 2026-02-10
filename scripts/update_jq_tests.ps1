param(
  [string]$UpstreamRepo = "https://github.com/jqlang/jq.git",
  [string]$Ref = "master",
  [string]$Destination = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Run-Git {
  param(
    [string]$RepositoryPath,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
  )

  if ($RepositoryPath -eq "") {
    & git @Args
  } else {
    & git -C $RepositoryPath @Args
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ($Destination -eq "") {
  $Destination = "third_party\jq-tests"
}
$destinationPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Destination))
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("jq-tests-sync-" + [Guid]::NewGuid().ToString("N"))

try {
  Run-Git "" clone --depth 1 --branch $Ref $UpstreamRepo $tempRoot
  $upstreamCommit = (Run-Git $tempRoot rev-parse HEAD | Out-String).Trim()

  $filesToCopy = @(
    "COPYING",
    "tests/base64.test",
    "tests/jq.test",
    "tests/man.test",
    "tests/manonig.test",
    "tests/onig.test",
    "tests/optional.test",
    "tests/uri.test",
    "tests/no-main-program.jq",
    "tests/yes-main-program.jq"
  )

  $dirsToCopy = @(
    "tests/modules"
  )

  if (Test-Path $destinationPath) {
    Remove-Item -Recurse -Force $destinationPath
  }
  New-Item -ItemType Directory -Force -Path $destinationPath | Out-Null

  foreach ($relativeFile in $filesToCopy) {
    $sourcePath = Join-Path $tempRoot $relativeFile
    if (-not (Test-Path $sourcePath)) {
      throw "upstream file not found: $relativeFile"
    }
    $targetPath = Join-Path $destinationPath $relativeFile
    $targetDir = Split-Path -Parent $targetPath
    if (-not (Test-Path $targetDir)) {
      New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    Copy-Item $sourcePath $targetPath -Force
  }

  foreach ($relativeDir in $dirsToCopy) {
    $sourceDir = Join-Path $tempRoot $relativeDir
    if (-not (Test-Path $sourceDir)) {
      throw "upstream directory not found: $relativeDir"
    }
    $targetDir = Join-Path $destinationPath $relativeDir
    if (Test-Path $targetDir) {
      Remove-Item -Recurse -Force $targetDir
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetDir) | Out-Null
    Copy-Item $sourceDir $targetDir -Recurse -Force
  }

  $utcDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
  @"
# jq upstream tests (vendored)

- upstream: $UpstreamRepo
- ref: $Ref
- commit: $upstreamCommit
- synced_at_utc: $utcDate

This directory is copied from `jqlang/jq` using `scripts/update_jq_tests.ps1`
or `scripts/update_jq_tests.sh`.
"@ | Set-Content -Path (Join-Path $destinationPath "README.md") -Encoding UTF8

  "$UpstreamRepo`n" | Set-Content -Path (Join-Path $destinationPath "UPSTREAM_REPO") -Encoding UTF8
  "$Ref`n" | Set-Content -Path (Join-Path $destinationPath "UPSTREAM_REF") -Encoding UTF8
  "$upstreamCommit`n" | Set-Content -Path (Join-Path $destinationPath "UPSTREAM_COMMIT") -Encoding UTF8

  Write-Host "Vendored jq tests to: $destinationPath"
  Write-Host "Upstream commit: $upstreamCommit"
} finally {
  if (Test-Path $tempRoot) {
    Remove-Item -Recurse -Force $tempRoot
  }
}
