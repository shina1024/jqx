#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${1:-${SCRIPT_DIR}/jq_upstream_import.json}"
OUTPUT_PATH="${2:-${SCRIPT_DIR}/jq_compat_cases.upstream.json}"

if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoLogo -NoProfile -File "${SCRIPT_DIR}/jq_upstream_import.ps1" \
    -ConfigPath "${CONFIG_PATH}" \
    -OutputPath "${OUTPUT_PATH}"
fi

if command -v powershell >/dev/null 2>&1; then
  exec powershell -NoLogo -NoProfile -File "${SCRIPT_DIR}/jq_upstream_import.ps1" \
    -ConfigPath "${CONFIG_PATH}" \
    -OutputPath "${OUTPUT_PATH}"
fi

echo "PowerShell is required to run jq_upstream_import.ps1" >&2
exit 2
