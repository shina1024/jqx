param(
  [Parameter(Mandatory=$true)][string]$Filter,
  [string]$Json
)

if ($PSBoundParameters.ContainsKey('Json')) {
  moon run --target native cmd/jqx -- $Filter $Json
  exit $LASTEXITCODE
}

$inputJson = Get-Content -Raw -ErrorAction SilentlyContinue
if (-not $inputJson) { $inputJson = "" }
moon run --target native cmd/jqx -- $Filter $inputJson
