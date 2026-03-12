#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY=0
SKIP_DIFFERENTIAL=0
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify)
      VERIFY=1
      shift
      ;;
    --skip-differential)
      SKIP_DIFFERENTIAL=1
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

CASES_PATH="${POSITIONAL[0]:-${SCRIPT_DIR}/jq_compat_cases.upstream.json}"
FAILURE_SNAPSHOT_PATH="${POSITIONAL[1]:-${SCRIPT_DIR}/jq_upstream_failures.snapshot.json}"
LEDGER_PATH="${POSITIONAL[2]:-${SCRIPT_DIR}/jq_upstream_diff_ledger.md}"
MAINTAINED_CASES_PATH="${POSITIONAL[3]:-${SCRIPT_DIR}/jq_compat_cases.json}"

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
  cmd=(pwsh -NoLogo -NoProfile -File "${SCRIPT_DIR}/jq_upstream_ledger.ps1" \
    -CasesPath "${CASES_PATH}" \
    -FailureSnapshotPath "${FAILURE_SNAPSHOT_PATH}" \
    -LedgerPath "${LEDGER_PATH}" \
    -MaintainedCasesPath "${MAINTAINED_CASES_PATH}")
  if [[ ${VERIFY} -eq 1 ]]; then
    cmd+=(-Verify)
  fi
  if [[ ${SKIP_DIFFERENTIAL} -eq 1 ]]; then
    cmd+=(-SkipDifferential)
  fi
  exec "${cmd[@]}"
fi

if command -v pwsh.exe >/dev/null 2>&1; then
  SCRIPT_PATH_WIN="$(to_windows_path "${SCRIPT_DIR}/jq_upstream_ledger.ps1")"
  CASES_PATH_WIN="$(to_windows_path "${CASES_PATH}")"
  FAILURE_PATH_WIN="$(to_windows_path "${FAILURE_SNAPSHOT_PATH}")"
  LEDGER_PATH_WIN="$(to_windows_path "${LEDGER_PATH}")"
  MAINTAINED_CASES_PATH_WIN="$(to_windows_path "${MAINTAINED_CASES_PATH}")"
  cmd=(pwsh.exe -NoLogo -NoProfile -File "${SCRIPT_PATH_WIN}" \
    -CasesPath "${CASES_PATH_WIN}" \
    -FailureSnapshotPath "${FAILURE_PATH_WIN}" \
    -LedgerPath "${LEDGER_PATH_WIN}" \
    -MaintainedCasesPath "${MAINTAINED_CASES_PATH_WIN}")
  if [[ ${VERIFY} -eq 1 ]]; then
    cmd+=(-Verify)
  fi
  if [[ ${SKIP_DIFFERENTIAL} -eq 1 ]]; then
    cmd+=(-SkipDifferential)
  fi
  exec "${cmd[@]}"
fi

if command -v powershell >/dev/null 2>&1; then
  cmd=(powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/jq_upstream_ledger.ps1" \
    -CasesPath "${CASES_PATH}" \
    -FailureSnapshotPath "${FAILURE_SNAPSHOT_PATH}" \
    -LedgerPath "${LEDGER_PATH}" \
    -MaintainedCasesPath "${MAINTAINED_CASES_PATH}")
  if [[ ${VERIFY} -eq 1 ]]; then
    cmd+=(-Verify)
  fi
  if [[ ${SKIP_DIFFERENTIAL} -eq 1 ]]; then
    cmd+=(-SkipDifferential)
  fi
  exec "${cmd[@]}"
fi

if command -v powershell.exe >/dev/null 2>&1; then
  SCRIPT_PATH_WIN="$(to_windows_path "${SCRIPT_DIR}/jq_upstream_ledger.ps1")"
  CASES_PATH_WIN="$(to_windows_path "${CASES_PATH}")"
  FAILURE_PATH_WIN="$(to_windows_path "${FAILURE_SNAPSHOT_PATH}")"
  LEDGER_PATH_WIN="$(to_windows_path "${LEDGER_PATH}")"
  MAINTAINED_CASES_PATH_WIN="$(to_windows_path "${MAINTAINED_CASES_PATH}")"
  cmd=(powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_PATH_WIN}" \
    -CasesPath "${CASES_PATH_WIN}" \
    -FailureSnapshotPath "${FAILURE_PATH_WIN}" \
    -LedgerPath "${LEDGER_PATH_WIN}" \
    -MaintainedCasesPath "${MAINTAINED_CASES_PATH_WIN}")
  if [[ ${VERIFY} -eq 1 ]]; then
    cmd+=(-Verify)
  fi
  if [[ ${SKIP_DIFFERENTIAL} -eq 1 ]]; then
    cmd+=(-SkipDifferential)
  fi
  exec "${cmd[@]}"
fi

echo "PowerShell is required to run jq_upstream_ledger.ps1" >&2
exit 2
