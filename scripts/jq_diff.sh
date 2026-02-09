#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CASES_PATH="${1:-${SCRIPT_DIR}/jq_compat_cases.json}"
JQ_BIN="${JQ_BIN:-jq}"
MOON_BIN="${MOON_BIN:-moon}"

resolve_jq_bin() {
  if command -v "${JQ_BIN}" >/dev/null 2>&1; then
    command -v "${JQ_BIN}"
    return 0
  fi

  if command -v mise >/dev/null 2>&1; then
    local candidate
    candidate="$(mise which jq 2>/dev/null | tr -d '\r')"
    if [[ -n "${candidate}" ]] && [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  if command -v mise.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
    local candidate_win candidate_unix
    candidate_win="$(mise.exe which jq 2>/dev/null | tr -d '\r')"
    if [[ -n "${candidate_win}" ]]; then
      candidate_unix="$(wslpath -u "${candidate_win}" 2>/dev/null || true)"
      if [[ -n "${candidate_unix}" ]] && [[ -x "${candidate_unix}" ]]; then
        printf '%s\n' "${candidate_unix}"
        return 0
      fi
    fi
  fi

  return 1
}

resolve_moon_bin() {
  if command -v "${MOON_BIN}" >/dev/null 2>&1; then
    command -v "${MOON_BIN}"
    return 0
  fi

  if command -v moon.exe >/dev/null 2>&1; then
    command -v moon.exe
    return 0
  fi

  return 1
}

JQ_BIN_RESOLVED="$(resolve_jq_bin)" || {
  echo "jq binary not found: ${JQ_BIN} (also checked mise)" >&2
  exit 2
}

MOON_BIN_RESOLVED="$(resolve_moon_bin)" || {
  echo "moon command not found: ${MOON_BIN}" >&2
  exit 2
}

if [[ ! -f "${CASES_PATH}" ]]; then
  echo "cases file not found: ${CASES_PATH}" >&2
  exit 2
fi

CASES_PATH_FOR_JQ="${CASES_PATH}"
if [[ "${JQ_BIN_RESOLVED}" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
  CASES_PATH_FOR_JQ="$(wslpath -w "${CASES_PATH}")"
fi

if ! "${JQ_BIN_RESOLVED}" -e 'type == "array" and all(.[]; has("name") and has("filter") and has("input"))' "${CASES_PATH_FOR_JQ}" >/dev/null; then
  echo "invalid cases file format: ${CASES_PATH}" >&2
  exit 2
fi

cd "${REPO_ROOT}"
if ! "${MOON_BIN_RESOLVED}" run --target native cmd -- "." "null" >/dev/null 2>&1; then
  echo "failed to warm up jqx command via moon run" >&2
  exit 2
fi

total=0
passed=0
failed=0

while IFS=$'\t' read -r name filter input expect_error; do
  total=$((total + 1))
  name="${name%$'\r'}"
  filter="${filter%$'\r'}"
  input="${input%$'\r'}"
  expect_error="${expect_error%$'\r'}"

  set +e
  jq_out="$(printf '%s' "${input}" | "${JQ_BIN_RESOLVED}" -c "${filter}" 2>&1)"
  jq_status=$?
  jqx_out="$("${MOON_BIN_RESOLVED}" run --target native cmd -- "${filter}" "${input}" 2>&1 </dev/null)"
  jqx_status=$?
  set -e

  ok=false
  if [[ "${expect_error}" == "true" ]]; then
    if [[ ${jq_status} -ne 0 && ${jqx_status} -ne 0 ]]; then
      ok=true
    fi
  else
    if [[ ${jq_status} -eq 0 && ${jqx_status} -eq 0 && "${jq_out}" == "${jqx_out}" ]]; then
      ok=true
    fi
  fi

  if [[ "${ok}" == "true" ]]; then
    passed=$((passed + 1))
    printf '[PASS] %s\n' "${name}"
  else
    failed=$((failed + 1))
    printf '[FAIL] %s\n' "${name}"
    printf '  filter: %s\n' "${filter}"
    printf '  input: %s\n' "${input}"
    printf '  jq status=%s output=%s\n' "${jq_status}" "${jq_out}"
    printf '  jqx status=%s output=%s\n' "${jqx_status}" "${jqx_out}"
  fi
done < <("${JQ_BIN_RESOLVED}" -r '.[] | [.name, .filter, .input, ((.expect_error // false) | tostring)] | @tsv' "${CASES_PATH_FOR_JQ}")

printf '\nSummary: total=%s passed=%s failed=%s\n' "${total}" "${passed}" "${failed}"
if [[ ${failed} -ne 0 ]]; then
  exit 1
fi
