#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES_PATH="${1:-${SCRIPT_DIR}/jq_compat_cases.upstream.json}"
FAILURE_SNAPSHOT_PATH="${2:-${SCRIPT_DIR}/jq_upstream_failures.snapshot.json}"
LEDGER_PATH="${3:-${SCRIPT_DIR}/jq_upstream_diff_ledger.md}"

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
  exec pwsh -NoLogo -NoProfile -File "${SCRIPT_DIR}/jq_upstream_ledger.ps1" \
    -CasesPath "${CASES_PATH}" \
    -FailureSnapshotPath "${FAILURE_SNAPSHOT_PATH}" \
    -LedgerPath "${LEDGER_PATH}"
fi

if command -v pwsh.exe >/dev/null 2>&1; then
  SCRIPT_PATH_WIN="$(to_windows_path "${SCRIPT_DIR}/jq_upstream_ledger.ps1")"
  CASES_PATH_WIN="$(to_windows_path "${CASES_PATH}")"
  FAILURE_PATH_WIN="$(to_windows_path "${FAILURE_SNAPSHOT_PATH}")"
  LEDGER_PATH_WIN="$(to_windows_path "${LEDGER_PATH}")"
  exec pwsh.exe -NoLogo -NoProfile -File "${SCRIPT_PATH_WIN}" \
    -CasesPath "${CASES_PATH_WIN}" \
    -FailureSnapshotPath "${FAILURE_PATH_WIN}" \
    -LedgerPath "${LEDGER_PATH_WIN}"
fi

if command -v powershell >/dev/null 2>&1; then
  exec powershell -NoLogo -NoProfile -File "${SCRIPT_DIR}/jq_upstream_ledger.ps1" \
    -CasesPath "${CASES_PATH}" \
    -FailureSnapshotPath "${FAILURE_SNAPSHOT_PATH}" \
    -LedgerPath "${LEDGER_PATH}"
fi

if command -v powershell.exe >/dev/null 2>&1; then
  SCRIPT_PATH_WIN="$(to_windows_path "${SCRIPT_DIR}/jq_upstream_ledger.ps1")"
  CASES_PATH_WIN="$(to_windows_path "${CASES_PATH}")"
  FAILURE_PATH_WIN="$(to_windows_path "${FAILURE_SNAPSHOT_PATH}")"
  LEDGER_PATH_WIN="$(to_windows_path "${LEDGER_PATH}")"
  exec powershell.exe -NoLogo -NoProfile -File "${SCRIPT_PATH_WIN}" \
    -CasesPath "${CASES_PATH_WIN}" \
    -FailureSnapshotPath "${FAILURE_PATH_WIN}" \
    -LedgerPath "${LEDGER_PATH_WIN}"
fi

echo "PowerShell is required to run jq_upstream_ledger.ps1" >&2
exit 2
