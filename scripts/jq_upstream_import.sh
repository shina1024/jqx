#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${1:-${SCRIPT_DIR}/jq_upstream_import.json}"
OUTPUT_PATH="${2:-${SCRIPT_DIR}/jq_compat_cases.upstream.json}"

to_windows_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "${path}"
    return 0
  fi
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "${path}"
    return 0
  fi
  printf '%s\n' "${path}"
}

if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoLogo -NoProfile -File "${SCRIPT_DIR}/jq_upstream_import.ps1" \
    -ConfigPath "${CONFIG_PATH}" \
    -OutputPath "${OUTPUT_PATH}"
fi

if command -v pwsh.exe >/dev/null 2>&1; then
  SCRIPT_PATH_WIN="$(to_windows_path "${SCRIPT_DIR}/jq_upstream_import.ps1")"
  CONFIG_PATH_WIN="$(to_windows_path "${CONFIG_PATH}")"
  OUTPUT_PATH_WIN="$(to_windows_path "${OUTPUT_PATH}")"
  exec pwsh.exe -NoLogo -NoProfile -File "${SCRIPT_PATH_WIN}" \
    -ConfigPath "${CONFIG_PATH_WIN}" \
    -OutputPath "${OUTPUT_PATH_WIN}"
fi

if command -v powershell >/dev/null 2>&1; then
  exec powershell -NoLogo -NoProfile -File "${SCRIPT_DIR}/jq_upstream_import.ps1" \
    -ConfigPath "${CONFIG_PATH}" \
    -OutputPath "${OUTPUT_PATH}"
fi

if command -v powershell.exe >/dev/null 2>&1; then
  SCRIPT_PATH_WIN="$(to_windows_path "${SCRIPT_DIR}/jq_upstream_import.ps1")"
  CONFIG_PATH_WIN="$(to_windows_path "${CONFIG_PATH}")"
  OUTPUT_PATH_WIN="$(to_windows_path "${OUTPUT_PATH}")"
  exec powershell.exe -NoLogo -NoProfile -File "${SCRIPT_PATH_WIN}" \
    -ConfigPath "${CONFIG_PATH_WIN}" \
    -OutputPath "${OUTPUT_PATH_WIN}"
fi

echo "PowerShell is required to run jq_upstream_import.ps1" >&2
exit 2
